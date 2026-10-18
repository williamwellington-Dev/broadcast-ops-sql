# Project brief: Broadcast operations analysis in SQL Server

You've joined the operations team at **Northshore Broadcast Group**. Management wants to know how reliable the stations have been this quarter, where the problems come from, and whether the team is meeting its SLAs. All the data is in the `BroadcastOps` database. Your job is to answer with T-SQL.

## How to work

- Write each answer in `my_sql/task_XX.sql`. **One task per file. Commit after each task.**
- Read `docs/data_dictionary.md` before you start.
- Each task has a **Check** so you can confirm your result without seeing anyone's answer. If your number differs, the bug is usually in a join, a filter, or how NULLs are handled.
- Stuck? Ask Claude for a **hint**, not the answer. Paste your query and the error or the wrong result.
- Treat "now" as **2026-10-01 08:00**.

Levels 1 to 2 are fundamentals, 3 to 4 are what analyst interviews test, and 5 is what SQL Server / ops roles want to see.

---

## Level 1: Getting around the data
*SELECT, WHERE, ORDER BY, LIKE, date filters*

**Task 01.** List every service with its tier and owner team, ordered by tier and then by name.
> Check: 10 rows. The first rows are tier 1.

**Task 02.** List the hosts located at transmitter sites (any location starting with `TX-`), with their hostname, location and OS family.
> Check: 6 rows.

**Task 03.** List all SEV1 incidents: number, title, detection time and status, oldest first.
> Check: 2 rows. One of them is `INC0010136`.

**Task 04.** How many changes planned in **September 2026** ended `RolledBack` or `Failed`?
> Check: 10. Watch your date range: does your filter include September 30 at 23:30?

---

## Level 2: Joins and aggregation
*JOIN, LEFT JOIN, GROUP BY, COUNT, AVG, DATEDIFF, TOP*

**Task 05.** Count incidents by severity. Show the label (`SEV1`..`SEV4`) from `sla_targets`, not the number.
> Check: SEV1 = 2, SEV2 = 23, SEV3 = 77, SEV4 = 58.

**Task 06.** Count incidents per service, highest first. Every service must appear, even one with zero incidents. Which join guarantees that?
> Check: 10 rows. The top service is `stream-encoders` with 28.

**Task 07.** For each severity, what is the average number of minutes from detection to acknowledgement? Ignore incidents that were never acknowledged.
> Check: SEV1 2.5, SEV2 7.9, SEV3 29.7, SEV4 87.3 (to 1 decimal).
> If you got 2, 7, 29, 87, find out what SQL Server does when you `AVG()` an integer.

**Task 08.** Which 5 hosts raised the most alerts? Show hostname, service name and alert count.
> Check: number 1 is `WIN-TRF-APP02` with 736 alerts. That number is suspicious. Keep it in mind for Task 20.

**Task 09.** Which engineers commanded the most incidents? Show name and count, top 3.
> Check: `Elena Novak`, 25.

---

## Level 3: Business logic
*CASE, conditional aggregation, CTEs, percentages*

**Task 10.** **Acknowledge SLA.** For each severity, show how many acknowledged incidents there were, how many breached the acknowledge target (minutes to ack greater than `ack_target_minutes`), and the breach percentage.
> Check: SEV2 13.0%, SEV3 6.6%.

**Task 11.** **Change failure rate.** For each change type: implemented changes (everything except `Cancelled`), failed changes (`RolledBack` or `Failed`), and the failure rate %.
> Check: Emergency 21.6%, Normal 4.1%, Standard 2.7%.

**Task 12.** **Stakeholder notice.** SEV1 and SEV2 incidents must have a `ClientComms` event within `client_comms_minutes` of detection. For each SEV1/SEV2 incident, find the first `ClientComms` event and label it `On time`, `Late` or `Missing`.
> Check: 5 Missing, 4 Late.

---

## Level 4: Window functions and time logic
*LAG, ROW_NUMBER, date ranges between tables*

**Task 13.** **Weekly trend.** Count incidents per week and show the change from the previous week using `LAG`.
> Check: with weeks starting on **Monday**, the busiest week starts 2026-09-07 with 15 incidents. SQL Server's default week starts on Sunday, so decide how you'll handle it.

**Task 14.** **Current fleet health.** For every host and check type, find the **latest** health check (hint: `ROW_NUMBER`). Show only the ones that are not `OK`.
> Check: 7 rows, 2 of them `FAIL`.

**Task 15.** **Hidden change failures.** Find incidents with no `caused_by_change_id` where a `RolledBack` or `Failed` change on the **same service** ended in the 120 minutes before the incident was detected. These are incidents probably caused by a change that nobody linked.
> Check: 4 incidents.

**Task 16.** **Recurring problems.** Find service and title combinations that happened 4 or more times. Show how many times, and the average number of days between occurrences (`LAG` again).
> Check: 8 rows. The top one happened 14 times, about every 7 days.

---

## Level 5: Build it
*Views, stored procedures, data quality: what SQL Server roles actually ask for*

**Task 17.** Create a view `ops.vw_incident_metrics` with one row per incident. Include the service name, severity label, minutes to acknowledge, mitigate and resolve, and 0/1 flags for acknowledge and resolve SLA breaches. Then rewrite Task 10 using your view.

**Task 18.** Create a stored procedure `ops.usp_GetShiftHandoff @AsOf DATETIME2` that returns two result sets:
1. Incidents that are not `Resolved`, with how long they've been open.
2. Your Task 14 result: hosts whose latest check is not OK.

Call it with `EXEC ops.usp_GetShiftHandoff @AsOf = '2026-10-01T08:00:00';`.
> Check: result set 1 has 3 incidents.

**Task 19.** **Data quality.** Write at least 4 checks for bad data. Start with these:
- incidents resolved **before** they were detected
- incidents with status `Resolved` but no `resolved_at`
- duplicate alerts (same host, rule and `fired_at`)
- one check you think of yourself

> Check: 3 resolved-before-detected, 3 missing `resolved_at`, 6 duplicate alert groups.
> Then go back to Task 07. Did the bad rows affect your averages?

**Task 20.** **Write it up.** In your README, add a **"What I found"** section with 5 findings in plain English, each pointing to the task that proves it. Write it for a manager, not an engineer. For example: *"Emergency changes fail 8x more often than routine ones (Task 11)."*

---

## When you're done

You'll have 20 SQL files that you wrote, a view, a stored procedure, data-quality checks, and written findings, with a commit history that shows the progression. That's a project you can explain line by line in an interview.
