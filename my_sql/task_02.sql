/* Task 02
   List the hosts located at transmitter sites (any location starting with
   `TX-`), with their hostname, location and OS family.
*/
USE BroadcastOps;
GO

SELECT hostname, location, os_family

FROM ops.hosts

WHERE location LIKE 'TX-%'; 
