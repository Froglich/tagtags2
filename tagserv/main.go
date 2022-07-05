package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
)

const majorVersion int = 2 //increment by ONLY 1 when the database schema changes
const minorVersion int = 0

func main() {
	fmt.Printf("Welcome to TagTags server version 2.%d.%d!\n\n", majorVersion, minorVersion)
	fmt.Println("Copyright (C) 2022 Kim Lindgren")
	fmt.Println("This program comes with ABSOLUTELY NO WARRANTY. This is free software,")
	fmt.Println("and you are welcome to redistribute it under certain conditions; visit")
	fmt.Println("https://www.gnu.org/licenses/gpl-3.0.en.html for details.)")
	fmt.Println("")

	f, err := os.OpenFile("log.txt", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0655)
	if err != nil {
		log.Panicln(err)
	}
	defer f.Close()
	mw := io.MultiWriter(os.Stdout, f)
	log.SetOutput(mw)

	db := getDBConnection()
	validateAndInitializeDB(db)
	db.Close()

	log.Println("Setting up handlers...")

	r := mux.NewRouter()
	r.HandleFunc("/users", createUser).Methods("POST")
	r.HandleFunc("/users", usersHandler).Methods("GET")
	r.HandleFunc("/users/session", createSession).Methods("POST")
	r.HandleFunc("/users/session", destroySession).Methods("DELETE")
	r.HandleFunc("/users/{uid:[0-9]+}", userHandler).Methods("GET")
	r.HandleFunc("/users/{uid:[0-9]+}/password", setUserPassword).Methods("PUT")
	r.HandleFunc("/users/{uid:[0-9]+}/details", setUserDetails).Methods("PUT")
	r.HandleFunc("/groups", groupsHandler).Methods("GET")
	r.HandleFunc("/groups", createGroup).Methods("POST")
	r.HandleFunc("/groups/{group:[0-9]+}", deleteGroup).Methods("DELETE")
	r.HandleFunc("/groups/{group:[0-9]+}/members", addGroupMember).Methods("POST")
	r.HandleFunc("/groups/{group:[0-9]+}/members/{user:[0-9]+}", updateGroupMember).Methods("PUT")
	r.HandleFunc("/groups/{group:[0-9]+}/members/{user:[0-9]+}", removeGroupMember).Methods("DELETE")
	r.HandleFunc("/app/sheets", getSheets).Methods("GET")
	r.HandleFunc("/app/sheets/{id:[0-9]+}", getSheet).Methods("GET")
	r.HandleFunc("/app/sheets/{id:[0-9]+}/details", getSheetDetails).Methods("GET")
	r.HandleFunc("/app/projects/{project}/data", getData).Methods("GET")
	r.HandleFunc("/app/projects/{project}/data", postData).Methods("POST")
	r.HandleFunc("/app/projects/{project}/data/files", postBinaryData).Methods("POST")
	r.HandleFunc("/app/projects/{project}/data/files/{filename}", getBinaryData).Methods("GET")
	r.HandleFunc("/app/projects/{project}/{identifier}/{parameter}", postDatapoint).Methods("POST")
	r.HandleFunc("/login", loginHandler).Methods("GET")
	r.HandleFunc("/projects", projectsHandler).Methods("GET")
	r.HandleFunc("/projects", createProject).Methods("POST")
	r.HandleFunc("/projects/{project}", projectHandler).Methods("GET")
	r.HandleFunc("/projects/{project}/download", downloadTSVData).Methods("POST")
	r.HandleFunc("/projects/{project}/sheets", projectSheetsHandler).Methods("GET")
	r.HandleFunc("/projects/{project}/sheets", uploadSheet).Methods("POST")
	r.HandleFunc("/projects/{project}/sheets/create", createSheet).Methods("GET")
	r.HandleFunc("/projects/{project}/sheets/create", saveSheet).Methods("POST")
	r.HandleFunc("/projects/{project}/sheets/{sheet:[0-9]+}", updateSheet).Methods("PUT")
	r.HandleFunc("/projects/{project}/sheets/{sheet:[0-9]+}", deleteSheet).Methods("DELETE")
	r.HandleFunc("/projects/{project}/sheets/{sheet:[0-9]+}/edit", editSheet).Methods("GET")
	r.HandleFunc("/projects/{project}/sheets/{sheet:[0-9]+}/edit", saveSheet).Methods("POST")
	r.HandleFunc("/projects/{project}/groups", projectGroupsHandler).Methods("GET")
	r.HandleFunc("/projects/{project}/groups", addProjectGroup).Methods("POST")
	r.HandleFunc("/projects/{project}/groups/{group:[0-9]+}", changeProjectGroup).Methods("PUT")
	r.HandleFunc("/projects/{project}/groups/{group:[0-9]+}", deleteProjectGroup).Methods("DELETE")
	r.HandleFunc("/projects/{project}/data", projectDataHandler).Methods("GET")
	r.HandleFunc("/projects/{project}/data/{identifier}", dataIdentifierHandler).Methods("GET")
	r.HandleFunc("/help/expressions", helpExpressionsHandler).Methods("GET")
	r.HandleFunc("/", indexHandler).Methods("GET")

	r.PathPrefix("/static").Handler(http.StripPrefix("/static", http.FileServer(http.Dir("static/"))))

	log.Println("Listening for connections on '127.0.0.1:42506'")

	if err := http.ListenAndServe("127.0.0.1:42506", r); err != nil {
		panic(err)
	}
}
