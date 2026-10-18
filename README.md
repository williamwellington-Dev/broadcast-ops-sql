# broadcast-ops-sql
- The database schema, synthetic data and task brief were generated with Claude (AI) ** I CANNOT/WILL NOT USE REAL COMPANY DATA. 
- All SQL in my_sql/ was written by me.

T-SQL analysis of a quarter of operations data from a radio broadcast group: incidents, changes, alarms, SLAs and health checks across studios, transmitter sites, AoIP, STL links, playout, traffic and streaming. Built in **SQL Server**.

> The broadcast group, stations, hosts and people are fictional. The data is synthetic and contains no employer data.

**Status:** in progress. See [`TASKS.md`](TASKS.md) for the brief and [`my_sql/`](my_sql) for my queries.

---

## Setup (about 30 minutes, once)

1. **Install SQL Server 2022 Developer Edition** (free): download it from Microsoft's SQL Server downloads page and choose **Basic** install.
2. **Install SSMS** (SQL Server Management Studio, free) and connect to `localhost` with Windows Authentication. If the connection fails, tick **Trust server certificate**.
3. In SSMS, open `setup/01_create_database.sql` and click **Execute**. This creates the `BroadcastOps` database and its tables.
4. Open `setup/02_load_data.sql` and click **Execute**. This loads the data. It's a big file, so give it up to a minute.
5. Test that it worked:
   ```sql
   USE BroadcastOps;
   SELECT COUNT(*) FROM ops.incidents;   -- should return 160
   ```

The same data is also in `data/` as CSV files, if you want to open it in Excel or Power BI.

## Repository layout

```
setup/01_create_database.sql   creates the database and empty tables
setup/02_load_data.sql         loads 92 days of data
docs/data_dictionary.md        what every table and column means
TASKS.md                       the project brief: 20 tasks, easy to hard
my_sql/task_01.sql ... 20      my answers
data/                          the same data as CSV
```

## What I found

*To be written when the tasks are done (Task 20).*
