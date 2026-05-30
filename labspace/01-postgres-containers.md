# Lab 1 · Running Postgres Containers

In this first lab you'll get comfortable with the inner-loop basics: starting containers, inspecting what's inside them, and tearing them down. We'll use **Postgres** because it's a real service you'll use throughout the rest of this Labspace.

## 🎓 Quick refresher: what is a container?

Think of containers like smartphone apps. When you install an app, you don't think about its dependencies, configuration, or setup — you just tap **Install** and it works. And the red app you just installed runs in its own isolated, sandboxed environment, so it can't interfere with the green app next to it.

Containers bring that same idea to backend applications and services. Each one ships with everything it needs and runs isolated from the others.

## Running multiple Postgres containers

Let's prove that isolation by running **three different Postgres versions side by side**, each on its own host port. Run each command below:

```bash
docker run -d --name postgres1 -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres:latest
```

```bash
docker run -d --name postgres2 -e POSTGRES_PASSWORD=dev -p 5433:5432 postgres:13
```

```bash
docker run -d --name postgres3 -e POSTGRES_PASSWORD=dev -p 5434:5432 postgres:12
```

Three independent database engines — `latest`, `13`, and `12` — all running at once without conflict. Confirm they're up:

```bash
docker ps
```

## Connecting with psql

Exec into the first container and open a `psql` session:

```bash
docker exec -it postgres1 psql -d postgres -U postgres -W
```

When prompted, enter the password `dev`. You'll land in the interactive prompt:

```text no-run-button
psql (17.2 (Debian 17.2-1.pgdg120+1))
Type "help" for help.

postgres=#
```

The connection flags mean:

- `-d` — the name of the database to connect to
- `-U` — the user to connect as
- `-W` — force `psql` to prompt for the password before connecting

## Listing all the databases — `\l`

At the `postgres=#` prompt, list every database:

```bash
\l
```

You'll see the three default databases that ship with a fresh Postgres install:

```text no-run-button no-copy-button
                                 List of databases
   Name    |  Owner   | Encoding | Locale Provider |  Collate   |   Ctype
-----------+----------+----------+-----------------+------------+------------
 postgres  | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8
 template0 | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8
 template1 | postgres | UTF8     | libc            | en_US.utf8 | en_US.utf8
(3 rows)
```

## Listing all schemas — `\dn`

The `\dn` command lists the database schemas:

```bash
\dn
```

```text no-run-button no-copy-button
      List of schemas
  Name  |       Owner
--------+-------------------
 public | pg_database_owner
(1 row)
```

## Inspecting database activity

Postgres exposes a live view of what every connection is doing through the `pg_stat_activity` system view. Run the query (**don't forget the trailing `;`**):

```bash
SELECT * FROM pg_stat_activity;
```

The result shows one row per backend process — the PID, the user, the client, the current `state` (`idle` / `active`), the wait event, and the actual `query` text. This is your first line of insight when a database "feels slow": you can see exactly which queries are running and which are blocked.

```text no-run-button no-copy-button
 datid | datname  | pid | usename  | application_name | state  |              query
-------+----------+-----+----------+------------------+--------+---------------------------------
     5 | postgres |  85 | postgres | psql             | idle   | SELECT pg_sleep(30);
     5 | postgres |  92 | postgres | psql             | active | SELECT * FROM pg_stat_activity;
       |          |  64 |          |                  |        |  (autovacuum launcher)
```

Exit the `psql` session when you're done:

```bash
postgres=# \q
```

## Cleaning up

When you remove containers, only the container layer is discarded — your host stays clean, with no leftover Postgres install, config files, or stray processes. That clean teardown is one of the core inner-loop benefits of containers.

Stop and remove all three Postgres containers in one step:

```bash
docker rm -f postgres1 postgres2 postgres3
```

> 💡 In Docker Desktop you can do the same visually: open the **Containers** view, select all the running Postgres containers, and delete them together.

## ✅ Recap

You ran three isolated Postgres versions simultaneously, connected with `psql`, explored databases, schemas, and live activity, and tore everything down cleanly. Next, we'll meet the application you'll spend the rest of this Labspace building and improving.
