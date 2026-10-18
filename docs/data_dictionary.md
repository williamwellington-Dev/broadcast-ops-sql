# Data dictionary: BroadcastOps

Every table lives in the `ops` schema, so you query `ops.incidents`, not `incidents`.

The data covers **2026-07-01 to 2026-09-30**. For anything that asks about "now" (open incidents, latest health checks), use **2026-10-01 08:00** as the current time.

**Northshore Broadcast Group** (fictional) runs three radio stations, FM1, FM2 and FM3. It operates from a main studio (`STUDIO-MAIN`), a backup studio (`STUDIO-BKP`), and three transmitter sites (`TX-NORTH`, `TX-EAST`, `TX-SOUTH`), and streams online through AWS.

---

## Reference tables

### `ops.sla_targets` (4 rows): the targets each incident is measured against

| Column | Type | Meaning |
|---|---|---|
| `severity` | TINYINT, PK | 1 to 4. 1 is the worst |
| `severity_label` | VARCHAR | `SEV1` .. `SEV4` |
| `ack_target_minutes` | INT | Someone must acknowledge the page within this many minutes of detection |
| `resolve_target_minutes` | INT | The incident must be resolved within this many minutes of detection |
| `client_comms_minutes` | INT, nullable | Station management and sales/traffic must be notified within this many minutes. NULL means no notice is required (SEV3/SEV4) |

### `ops.services` (10 rows): the systems the team supports

| Column | Type | Meaning |
|---|---|---|
| `service_id` | INT, PK | |
| `service_name` | VARCHAR | e.g. `playout-automation`, `aoip-network`, `transmitter-sites`, `stl-links`, `traffic-scheduling`, `eas-endec` |
| `tier` | TINYINT | 1 = on-air / revenue critical, 2 = important, 3 = supporting |
| `platform` | VARCHAR | Grouping such as `On-Air`, `RF / Transmission`, `Digital` |
| `owner_team` | VARCHAR | Team that owns the service |

### `ops.hosts` (30 rows): servers and network devices

| Column | Type | Meaning |
|---|---|---|
| `host_id` | INT, PK | |
| `hostname` | VARCHAR | e.g. `WIN-PLY-SRV01` (playout server), `TX-EAST-RC01` (transmitter remote control), `STL-NORTH-01` (STL codec) |
| `service_id` | INT, FK → services | Which service this host belongs to |
| `os_family` | VARCHAR | `Windows`, `Linux` or `Appliance` (switches, codecs, remote controls) |
| `location` | VARCHAR | `STUDIO-MAIN`, `STUDIO-BKP`, `TX-NORTH`, `TX-EAST`, `TX-SOUTH`, `aws-us-east-1` |
| `ip_address` | VARCHAR | |
| `is_active` | BIT | 1 = in service |

### `ops.engineers` (12 rows)

| Column | Type | Meaning |
|---|---|---|
| `engineer_id` | INT, PK | |
| `full_name` | VARCHAR | |
| `team` | VARCHAR | `Broadcast Operations` (the on-call team) or another engineering team |

### `ops.oncall_shifts` (372 rows): who was on call and when

| Column | Type | Meaning |
|---|---|---|
| `shift_id` | INT, PK | |
| `engineer_id` | INT, FK → engineers | |
| `shift_role` | VARCHAR | `Primary` (gets paged first) or `Secondary` (backup) |
| `shift_start`, `shift_end` | DATETIME2 | 12-hour shifts, 08:00 to 20:00 and 20:00 to 08:00 |

---

## Change management

### `ops.changes` (327 rows): planned and emergency work on production

| Column | Type | Meaning |
|---|---|---|
| `change_id` | INT, PK | |
| `change_number` | VARCHAR | e.g. `CHG0005282` |
| `service_id` | INT, FK → services | What was changed |
| `change_type` | VARCHAR | `Standard` (routine, pre-approved), `Normal` (reviewed, scheduled), `Emergency` (urgent, less review) |
| `risk` | VARCHAR | `Low`, `Medium`, `High` |
| `summary` | VARCHAR | What the change was |
| `implementer_id` | INT, FK → engineers | Who did the work |
| `planned_start` | DATETIME2 | When it was scheduled |
| `actual_start`, `actual_end` | DATETIME2, nullable | When it really happened. NULL if cancelled |
| `outcome` | VARCHAR | `Successful`, `RolledBack`, `Failed`, `Cancelled` |

---

## Incident management

### `ops.incidents` (160 rows)

| Column | Type | Meaning |
|---|---|---|
| `incident_id` | INT, PK | |
| `incident_number` | VARCHAR | e.g. `INC0010136` |
| `service_id` | INT, FK → services | Affected service |
| `severity` | TINYINT, FK → sla_targets | 1 to 4 |
| `title` | VARCHAR | Short description |
| `detected_at` | DATETIME2 | When monitoring detected it. **The clock starts here** |
| `acknowledged_at` | DATETIME2, nullable | When on-call acknowledged the page |
| `mitigated_at` | DATETIME2, nullable | When on-air or listener impact stopped (for example, switched to backup) |
| `resolved_at` | DATETIME2, nullable | When it was fully fixed and closed |
| `status` | VARCHAR | `Open`, `Mitigated`, `Resolved` |
| `commander_id` | INT, FK → engineers, nullable | Engineer who ran the incident |
| `caused_by_change_id` | INT, FK → changes, nullable | Set when a change caused the incident |
| `root_cause_category` | VARCHAR, nullable | `Change`, `Capacity`, `Network`, `Power`, `Third-Party`, `Software Defect`, `Hardware`, `Unknown` |
| `rca_completed` | BIT | 1 = root-cause analysis written |

### `ops.incident_events` (679 rows): the timeline of each incident

| Column | Type | Meaning |
|---|---|---|
| `event_id` | INT, PK | |
| `incident_id` | INT, FK → incidents | |
| `event_type` | VARCHAR | `Created`, `Acknowledged`, `Escalated`, `ClientComms` (stakeholder notice sent), `Mitigated`, `Resolved` |
| `event_at` | DATETIME2 | |
| `engineer_id` | INT, nullable | |
| `detail` | VARCHAR | Free text |

---

## Monitoring

### `ops.alerts` (2,545 rows): alarms from monitoring systems

| Column | Type | Meaning |
|---|---|---|
| `alert_id` | INT, PK | |
| `host_id` | INT, FK → hosts | Where it fired |
| `source_system` | VARCHAR | `AirMonitor` (silence and stream sensors), `SNMP`, `Splunk` |
| `alert_rule` | VARCHAR | e.g. `Silence detected on air chain`, `CPU > 90% (5m)`, `Multicast group loss` |
| `severity` | VARCHAR | `Critical`, `Warning`, `Info` |
| `fired_at` | DATETIME2 | |
| `cleared_at` | DATETIME2, nullable | NULL means it never cleared |
| `incident_id` | INT, FK → incidents, nullable | Set if the alert was attached to an incident. NULL means nobody acted on it |

### `ops.health_checks` (2,886 rows): results from scripted checks, last 72 hours

| Column | Type | Meaning |
|---|---|---|
| `check_id` | BIGINT, IDENTITY, PK | |
| `host_id` | INT, FK → hosts | |
| `check_type` | VARCHAR | `Ping`, `Port80`, `Port443`, `Port1433`, `DiskC`, `DiskData` |
| `checked_at` | DATETIME2 | Every 2 hours |
| `status` | VARCHAR | `OK`, `WARN`, `FAIL` |
| `latency_ms` | INT, nullable | |
| `detail` | VARCHAR, nullable | e.g. `97% used` |

---

## Heads-up

Like any real ticketing export, **this data is not perfectly clean.** Some rows have timestamps that don't make sense or missing values. Finding those is part of the project (Task 19). Until then, think about how bad rows could distort an average.
