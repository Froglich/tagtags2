#!/usr/bin/env python3

import sqlite3
import psycopg2
import getpass
import sys

db_host = input('DB Host: ')
db_port = input('DB Port: ')
db_name = input('DB Name: ')
db_user = input('DB Username: ')
db_pass = getpass.getpass('DB Password: ')

legacy_con = sqlite3.connect('../tagserv.db')
legacy_cur = legacy_con.cursor()

pg_con = psycopg2.connect('host={} dbname={} port={} user={} password={}'.format(
    db_host,
    db_name,
    db_port,
    db_user,
    db_pass
))
pg_cur = pg_con.cursor()

with open('schema.sql', 'r') as reader:
    cmds = reader.read().strip().split(';')

    for cmd in cmds:
        if cmd != '':
            pg_cur.execute(cmd)

pg_con.commit()

legacy_cur.execute('SELECT user_id, username, pwhash, create_projects, full_access FROM users')
rows = legacy_cur.fetchall()
_max = 0
for row in rows:
    pg_cur.execute('INSERT INTO users(user_id, username, pwhash, create_projects, full_access) VALUES(%s, %s, %s, %s, %s)', (
        row[0], row[1], row[2], row[3] == 1, row[4] == 1
    ))
    if row[0] > _max:
        _max = row[0]
pg_cur.execute("SELECT setval(pg_get_serial_sequence('users', 'user_id'), {})".format(_max))

legacy_cur.execute("SELECT group_id, name FROM groups")
rows = legacy_cur.fetchall()
_max = 0
for row in rows:
    pg_cur.execute("INSERT INTO groups(group_id, name) VALUES(%s, %s)", (row[0], row[1]))
    if row[0] > _max:
        _max = row[0]
pg_cur.execute("SELECT setval(pg_get_serial_sequence('groups', 'group_id'), {})".format(_max))

legacy_cur.execute("SELECT user_id, group_id, modify FROM user_groups")
rows = legacy_cur.fetchall()
for row in rows:
    pg_cur.execute("INSERT INTO user_groups(user_id, group_id, modify) VALUES(%s, %s, %s)", (row[0], row[1], row[2] == 1))

legacy_cur.execute("SELECT project, created_by FROM projects")
rows = legacy_cur.fetchall()
for row in rows:
    pg_cur.execute("INSERT INTO projects(project, created_by) VALUES(%s, %s)", (row[0], row[1]))

legacy_cur.execute("SELECT project, group_id, can_modify FROM project_groups")
rows = legacy_cur.fetchall()
for row in rows:
    pg_cur.execute("INSERT INTO project_groups(project, group_id, can_modify) VALUES(%s, %s, %s)", (row[0], row[1], row[2] == 1))

legacy_cur.execute("SELECT user_id, identifier, expires FROM sessions")
rows = legacy_cur.fetchall()
for row in rows:
    pg_cur.execute("INSERT INTO sessions(user_id, identifier, expires) VALUES(%s, %s, %s)", (row[0], row[1], row[2]))

legacy_cur.execute("SELECT id, project, version, name, sheet FROM sheets")
rows = legacy_cur.fetchall()
_max = 0
for row in rows:
    pg_cur.execute("INSERT INTO sheets(id, project, version, name, sheet) VALUES(%s, %s, %s, %s, %s)", (
        row[0], row[1], row[2], row[3], row[4]
    ))
    if row[0] > _max:
        _max = row[0]
pg_cur.execute("SELECT setval(pg_get_serial_sequence('sheets', 'id'), {})".format(_max))

legacy_cur.execute("SELECT project, identifier, parameter, type_id, value, modified, synctime FROM data")
rows = legacy_cur.fetchall()
for row in rows:
    pg_cur.execute("INSERT INTO data(project, identifier, parameter, type_id, value, modified, synctime) VALUES(%s, %s, %s, %s, %s, %s, %s)", (
        row[0], row[1], row[2], row[3], row[4], row[5], row[6]
    ))

pg_con.commit()
pg_con.close()
legacy_con.close()