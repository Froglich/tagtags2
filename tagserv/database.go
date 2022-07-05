package main

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"path"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

func getDBConnection() *sql.DB {
	db, err := sql.Open("sqlite3", "tagserv.db")
	if err != nil {
		log.Panicln(err)
	}

	_, err = db.Exec("PRAGMA foreign_keys = ON")
	if err != nil {
		log.Panicln(err)
	}

	return db
}

func runSQLFile(db *sql.DB, filename string) error {
	log.Printf("running %s on the database", filename)

	rawCmds, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Printf("error reading file: %s\n", filename)
		return err
	}

	cmds := strings.Split(string(rawCmds), ";")
	for x := range cmds {
		cmd := strings.TrimSpace(cmds[x])

		if cmd == "" {
			continue
		}

		_, err = db.Exec(cmd)

		if err != nil {
			log.Printf("could not execute SQL: %s\n", cmd)
			return err
		}
	}

	return nil
}

func validateAndInitializeDB(db *sql.DB) {
	row := db.QueryRow("SELECT schema_version FROM tagtags")
	var dbVersion int
	err := row.Scan(&dbVersion)
	if err != nil {
		log.Println("initializing the database...")
		err = runSQLFile(db, path.Join("sql", "initialize.sql"))
		if err != nil {
			log.Fatalln(err)
		}
	} else if dbVersion > majorVersion {
		log.Fatalln("the database is for a more recent version of the server!")
	} else if dbVersion < majorVersion {
		log.Println("upgrading the database...")
		for dbVersion < majorVersion {
			err = runSQLFile(db, path.Join("sql", fmt.Sprintf("schema%dto%d.sql", dbVersion, dbVersion+1)))
			if err != nil {
				log.Fatalln(err)
			}
			dbVersion++
		}
	}
}
