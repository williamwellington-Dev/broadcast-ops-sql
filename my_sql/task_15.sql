/* Task 15
   Hidden change failures. Find incidents with no `caused_by_change_id` where a
   `RolledBack` or `Failed` change on the same service ended in the 120 minutes
   before the incident was detected. These are incidents probably caused by a
   change that nobody linked.
*/
USE BroadcastOps;
GO

-- your query here

