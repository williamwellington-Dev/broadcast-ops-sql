/* Task 03
   List all SEV1 incidents: number, title, detection time and status, oldest
   first.
*/
USE BroadcastOps;
GO

SELECT severity,incident_number,title,detected_at, status

FROM Ops.incidents
WHERE severity = 1
ORDER BY detected_at;
