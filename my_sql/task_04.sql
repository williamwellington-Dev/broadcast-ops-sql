/* Task 04
   How many changes planned in September 2026 ended `RolledBack` or `Failed`?
*/
USE BroadcastOps;
GO

SELECT COUNT (outcome)

FROM ops.changes

WHERE planned_start >= '2026-09-01' AND planned_start <= '2026-10- 01' AND outcome IN ( 'RolledBack', 'Failed');
