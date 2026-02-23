package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path"
	"strings"

	"github.com/jackc/pgx/v5"
	_ "github.com/mattn/go-sqlite3"
)

func getDBConnection() *pgx.Conn {
	db, err := pgx.Connect(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Panic(err)
	}

	return db
}

func runSQLFile(db *pgx.Conn, filename string) error {
	log.Printf("running %s on the database", filename)

	rawCmds, err := os.ReadFile(filename)
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

		_, err = db.Exec(context.Background(), cmd)

		if err != nil {
			log.Printf("could not execute SQL: %s\n", cmd)
			return err
		}
	}

	return nil
}

func validateAndInitializeDB(db *pgx.Conn) {
	row := db.QueryRow(context.Background(), "SELECT schema_version FROM tagtags")
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
