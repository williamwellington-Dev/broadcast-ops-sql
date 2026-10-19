/* Task 01
   List every service with its tier and owner team, ordered by tier and then by
   name.
*/
USE BroadcastOps;
GO

SELECT Service_name,
tier,
owner_team 

FROM ops.services

ORDER BY tier, service_name; 
