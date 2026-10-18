/* =============================================================================
   broadcast-ops-sql  |  setup/01_create_database.sql
   Run this FIRST in SSMS (just open it and press Execute).

   Creates the BroadcastOps database and the empty tables in the "ops" schema.
   Re-runnable: it drops and recreates the tables each time.

   Fictional radio broadcast group "Northshore Broadcast Group":
   main studio, backup studio, three transmitter sites, streaming.

     services ─┬─ hosts ─── alerts ───┐
               │          └ health_checks
               ├─ changes ─────────────┤ (incidents.caused_by_change_id)
               └─ incidents ◄──────────┘ (alerts.incident_id)
                    └─ incident_events  (timeline: ack, escalation, comms, ...)
     engineers ── oncall_shifts
     sla_targets  (targets per severity)

   See docs/data_dictionary.md for what every column means.
============================================================================= */
IF DB_ID(N'BroadcastOps') IS NULL
    CREATE DATABASE BroadcastOps;
GO
USE BroadcastOps;
GO
SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'ops') IS NULL
    EXEC (N'CREATE SCHEMA ops AUTHORIZATION dbo;');
GO

/* ---- drop in dependency order ------------------------------------------- */
DROP TABLE IF EXISTS ops.health_checks;
DROP TABLE IF EXISTS ops.incident_events;
DROP TABLE IF EXISTS ops.alerts;
DROP TABLE IF EXISTS ops.incidents;
DROP TABLE IF EXISTS ops.changes;
DROP TABLE IF EXISTS ops.oncall_shifts;
DROP TABLE IF EXISTS ops.engineers;
DROP TABLE IF EXISTS ops.hosts;
DROP TABLE IF EXISTS ops.services;
DROP TABLE IF EXISTS ops.sla_targets;
GO

/* ---- reference ------------------------------------------------------------ */
CREATE TABLE ops.sla_targets (
    severity                TINYINT       NOT NULL CONSTRAINT pk_sla_targets PRIMARY KEY,
    severity_label          VARCHAR(10)   NOT NULL,          -- SEV1..SEV4
    ack_target_minutes      INT           NOT NULL,
    resolve_target_minutes  INT           NOT NULL,
    client_comms_minutes    INT           NULL,              -- station mgmt + sales/traffic notice due (SEV1/2)
    CONSTRAINT ck_sla_severity CHECK (severity BETWEEN 1 AND 4)
);

CREATE TABLE ops.services (
    service_id      INT           NOT NULL CONSTRAINT pk_services PRIMARY KEY,
    service_name    VARCHAR(60)   NOT NULL CONSTRAINT uq_services_name UNIQUE,
    tier            TINYINT       NOT NULL,                  -- 1 = on-air / revenue critical
    platform        VARCHAR(40)   NOT NULL,                  -- e.g. On-Air, RF / Transmission, Traffic & Billing
    owner_team      VARCHAR(60)   NOT NULL,
    CONSTRAINT ck_services_tier CHECK (tier BETWEEN 1 AND 3)
);

CREATE TABLE ops.hosts (
    host_id         INT           NOT NULL CONSTRAINT pk_hosts PRIMARY KEY,
    hostname        VARCHAR(40)   NOT NULL CONSTRAINT uq_hosts_hostname UNIQUE,
    service_id      INT           NOT NULL CONSTRAINT fk_hosts_service REFERENCES ops.services (service_id),
    os_family       VARCHAR(10)   NOT NULL,                  -- Windows | Linux | Appliance (switches, codecs, remote controls)
    location        VARCHAR(20)   NOT NULL,                  -- STUDIO-MAIN, STUDIO-BKP (DR), TX-NORTH/EAST/SOUTH, aws
    ip_address      VARCHAR(15)   NOT NULL,
    is_active       BIT           NOT NULL CONSTRAINT df_hosts_active DEFAULT (1),
    CONSTRAINT ck_hosts_os CHECK (os_family IN ('Windows','Linux','Appliance'))
);

CREATE TABLE ops.engineers (
    engineer_id     INT           NOT NULL CONSTRAINT pk_engineers PRIMARY KEY,
    full_name       VARCHAR(60)   NOT NULL,
    team            VARCHAR(40)   NOT NULL
);

CREATE TABLE ops.oncall_shifts (
    shift_id        INT           NOT NULL CONSTRAINT pk_oncall_shifts PRIMARY KEY,
    engineer_id     INT           NOT NULL CONSTRAINT fk_oncall_engineer REFERENCES ops.engineers (engineer_id),
    shift_role      VARCHAR(10)   NOT NULL,                  -- Primary | Secondary
    shift_start     DATETIME2(0)  NOT NULL,
    shift_end       DATETIME2(0)  NOT NULL,
    CONSTRAINT ck_oncall_window CHECK (shift_end > shift_start),
    CONSTRAINT ck_oncall_role   CHECK (shift_role IN ('Primary','Secondary'))
);

/* ---- change management --------------------------------------------------- */
CREATE TABLE ops.changes (
    change_id        INT           NOT NULL CONSTRAINT pk_changes PRIMARY KEY,
    change_number    VARCHAR(15)   NOT NULL CONSTRAINT uq_changes_number UNIQUE,   -- CHG0001234
    service_id       INT           NOT NULL CONSTRAINT fk_changes_service REFERENCES ops.services (service_id),
    change_type      VARCHAR(10)   NOT NULL,                 -- Standard | Normal | Emergency
    risk             VARCHAR(10)   NOT NULL,                 -- Low | Medium | High
    summary          VARCHAR(200)  NOT NULL,
    implementer_id   INT           NOT NULL CONSTRAINT fk_changes_engineer REFERENCES ops.engineers (engineer_id),
    planned_start    DATETIME2(0)  NOT NULL,
    actual_start     DATETIME2(0)  NULL,
    actual_end       DATETIME2(0)  NULL,
    outcome          VARCHAR(12)   NOT NULL,                 -- Successful | RolledBack | Failed | Cancelled
    CONSTRAINT ck_changes_type    CHECK (change_type IN ('Standard','Normal','Emergency')),
    CONSTRAINT ck_changes_risk    CHECK (risk IN ('Low','Medium','High')),
    CONSTRAINT ck_changes_outcome CHECK (outcome IN ('Successful','RolledBack','Failed','Cancelled'))
);

/* ---- incident management ------------------------------------------------- */
CREATE TABLE ops.incidents (
    incident_id          INT           NOT NULL CONSTRAINT pk_incidents PRIMARY KEY,
    incident_number      VARCHAR(15)   NOT NULL CONSTRAINT uq_incidents_number UNIQUE, -- INC0012345
    service_id           INT           NOT NULL CONSTRAINT fk_incidents_service REFERENCES ops.services (service_id),
    severity             TINYINT       NOT NULL CONSTRAINT fk_incidents_sla REFERENCES ops.sla_targets (severity),
    title                VARCHAR(200)  NOT NULL,
    detected_at          DATETIME2(0)  NOT NULL,
    acknowledged_at      DATETIME2(0)  NULL,
    mitigated_at         DATETIME2(0)  NULL,             -- on-air / listener impact stopped
    resolved_at          DATETIME2(0)  NULL,             -- fully fixed / closed
    status               VARCHAR(12)   NOT NULL,         -- Open | Mitigated | Resolved
    commander_id         INT           NULL CONSTRAINT fk_incidents_commander REFERENCES ops.engineers (engineer_id),
    caused_by_change_id  INT           NULL CONSTRAINT fk_incidents_change REFERENCES ops.changes (change_id),
    root_cause_category  VARCHAR(30)   NULL,             -- Change | Capacity | Network | Power | Third-Party | ...
    rca_completed        BIT           NOT NULL CONSTRAINT df_incidents_rca DEFAULT (0),
    CONSTRAINT ck_incidents_status CHECK (status IN ('Open','Mitigated','Resolved'))
);

CREATE TABLE ops.incident_events (
    event_id        INT           NOT NULL CONSTRAINT pk_incident_events PRIMARY KEY,
    incident_id     INT           NOT NULL CONSTRAINT fk_events_incident REFERENCES ops.incidents (incident_id),
    event_type      VARCHAR(20)   NOT NULL,   -- Created | Acknowledged | Escalated | ClientComms | Mitigated | Resolved | Note
    event_at        DATETIME2(0)  NOT NULL,
    engineer_id     INT           NULL CONSTRAINT fk_events_engineer REFERENCES ops.engineers (engineer_id),
    detail          VARCHAR(300)  NULL
);

/* ---- monitoring ---------------------------------------------------------- */
CREATE TABLE ops.alerts (
    alert_id        INT           NOT NULL CONSTRAINT pk_alerts PRIMARY KEY,
    host_id         INT           NOT NULL CONSTRAINT fk_alerts_host REFERENCES ops.hosts (host_id),
    source_system   VARCHAR(20)   NOT NULL,   -- Splunk | AirMonitor (silence/stream sensors) | SNMP
    alert_rule      VARCHAR(80)   NOT NULL,
    severity        VARCHAR(10)   NOT NULL,   -- Critical | Warning | Info
    fired_at        DATETIME2(0)  NOT NULL,
    cleared_at      DATETIME2(0)  NULL,
    incident_id     INT           NULL CONSTRAINT fk_alerts_incident REFERENCES ops.incidents (incident_id)
);

CREATE TABLE ops.health_checks (
    check_id        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT pk_health_checks PRIMARY KEY,
    host_id         INT           NOT NULL CONSTRAINT fk_health_host REFERENCES ops.hosts (host_id),
    check_type      VARCHAR(20)   NOT NULL,   -- Ping | Port80 | Port443 | Port1433 | DiskC | DiskData
    checked_at      DATETIME2(0)  NOT NULL,
    status          VARCHAR(8)    NOT NULL,   -- OK | WARN | FAIL
    latency_ms      INT           NULL,
    detail          VARCHAR(200)  NULL,
    CONSTRAINT ck_health_status CHECK (status IN ('OK','WARN','FAIL'))
);
GO

/* ---- indexes for the access paths the procs and reports use -------------- */
CREATE INDEX ix_incidents_service_detected ON ops.incidents (service_id, detected_at) INCLUDE (severity, resolved_at);
CREATE INDEX ix_incidents_detected         ON ops.incidents (detected_at) INCLUDE (severity, status);
CREATE INDEX ix_changes_service_start      ON ops.changes (service_id, actual_start) INCLUDE (actual_end, outcome, change_type);
CREATE INDEX ix_alerts_host_fired          ON ops.alerts (host_id, fired_at) INCLUDE (alert_rule, incident_id);
CREATE INDEX ix_alerts_incident            ON ops.alerts (incident_id) WHERE incident_id IS NOT NULL;
CREATE INDEX ix_events_incident            ON ops.incident_events (incident_id, event_type, event_at);
CREATE INDEX ix_health_host_type_time      ON ops.health_checks (host_id, check_type, checked_at DESC) INCLUDE (status);
CREATE INDEX ix_oncall_window              ON ops.oncall_shifts (shift_role, shift_start, shift_end) INCLUDE (engineer_id);
GO

PRINT 'Tables created. Next: run setup/02_load_data.sql';
GO
