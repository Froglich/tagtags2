# Database migration

This is only ment for users that are currently using the SQLite backend. In version 2.4 the default server switched from using SQLite to PostgreSQL as the database backend. If you never configured a database for the server, you are on an SQLite version.

To migrate from SQLite to PostgreSQL (this is a non-destructive process):

Set up a PostgreSQL database. I suggest using docker or podman to spin one up quickly, e.g.:

```bash
docker run -d --name pg_tagtags -p 127.0.0.1:5432:5432 -e POSTGRES_PASSWORD=mystrongpassword123 --restart unless-stopped postgres:latest
```

Dont do anything else (except perhaps change the password) before running *migrate-sqlite-to-postgres.py*.

## Migrating

The script, *migrate-sqlite-to-postgres.py* requires python3, psycopg2 and sqlite3. sqlite3 is probably already installed for you if you have python 3 (it might be part of the python standard library, I am unsure).

To install on debian or ubuntu:

```bash
sudo apt install python3 python3-psycopg2
```

Then run the script from the db_migration directory:

```bash
cd db_migration
chmod +x migrate-sqlite-to-postgres.py
./migrate-sqlite-to-postgres.py
```

This script will ask for the database hostname, port, database name, database user and database password, then initialize the database and copy all of the data from the SQLite database in the tagserv root folder. If it closes without any error message, it completed the process.