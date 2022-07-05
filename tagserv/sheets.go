package main

import (
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

type sheetDetails struct {
	ID      int    `json:"id"`
	Project string `json:"project"`
	Version int    `json:"version"`
	Name    string `json:"name"`
}

func getSheets(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := validateUser(db, r)
	if u == nil {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	sheets := u.getAccessibleSheets(db)
	out, _ := json.Marshal(sheets)
	w.Write(out)
}

func getSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	id, _ := strconv.Atoi(mux.Vars(r)["id"])
	defer db.Close()

	u := validateUser(db, r)
	if u == nil || !u.canAccessSheet(db, id) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	row := db.QueryRow("SELECT project, name, version, sheet FROM sheets WHERE id = ?", id)
	var project string
	var name string
	var version int
	var sheet []byte
	if err := row.Scan(&project, &name, &version, &sheet); err != nil {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	w.Header().Set("x-tagtags-sheet-name-base64", base64.StdEncoding.EncodeToString([]byte(name)))
	w.Header().Set("x-tagtags-sheet-project", project)
	w.Header().Set("x-tagtags-sheet-version", fmt.Sprintf("%d", version))
	w.Header().Set("Content-disposition", fmt.Sprintf("attachment; filename=\"%s-%s-v%d.json\"", project, name, version))

	w.Write(sheet)
}

func getSheetDetails(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	id, _ := strconv.Atoi(mux.Vars(r)["id"])
	defer db.Close()

	u := validateUser(db, r)
	if u == nil || !u.canAccessSheet(db, id) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	row := db.QueryRow("SELECT name, project, version FROM sheets WHERE id = ?", id)
	var name string
	var project string
	var version int
	if err := row.Scan(&name, &project, &version); err != nil {
		w.WriteHeader(http.StatusNotFound)
		log.Printf("could not get version of sheet %d: '%v'\n", id, err)
	}

	w.Header().Set("x-tagtags-sheet-name-base64", base64.StdEncoding.EncodeToString([]byte(name)))
	w.Header().Set("x-tagtags-sheet-project", project)
	w.Header().Set("x-tagtags-sheet-version", fmt.Sprintf("%d", version))
	fmt.Fprintf(w, "%d", version)
}

func getSheetFromForm(r *http.Request) (string, string, error) {
	reader, err := r.MultipartReader()
	if err != nil {
		log.Printf("Could not read multipart/form-data: '%v'\n", err)
		return "", "", err
	}

	frm, err := reader.ReadForm(20971520)
	if err != nil {
		log.Printf("Could not read multipart/form-data: '%v'\n", err)
		return "", "", err
	}

	name := frm.Value["name"][0]
	var sheet string
	for f := range frm.File {
		_f := frm.File[f][0]

		if ct := _f.Header.Get("Content-Type"); ct != "text/json" {
			log.Println("recieved wrong content-type")
			return "", "", fmt.Errorf("expected text/json, got another content-type")
		}

		file, err := _f.Open()
		if err != nil {
			log.Printf("could not process form file %v: '%v'\n", f, err)
			return "", "", err
		}

		rawSheet, err := readAllThenClose(file)
		if err != nil {
			log.Printf("could not read content of %s: '%v'\n", f, err)
			return "", "", err
		}

		if len(rawSheet) == 0 {
			return "", "", errors.New("the sheet was empty")
		}

		sheet = string(rawSheet)
		break
	}

	return name, sheet, nil
}

func insertSheetInDB(db *sql.DB, project string, sheet string, name string) (int, error) {
	_, err := db.Exec("INSERT INTO sheets(project, version, name, sheet) VALUES(?, 1, ?, ?)", project, name, sheet)
	if err != nil {
		log.Printf("while inserting sheet in db: '%v'\n", err)
		return 0, err
	}

	row := db.QueryRow("SELECT id FROM sheets WHERE project = ? AND name = ?", project, name)
	var id int
	if err := row.Scan(&id); err != nil {
		log.Printf("while getting sheet id from db: '%v'\n", err)
		return 0, err
	}

	return id, nil
}

func updateSheetInDB(db *sql.DB, id int, project string, sheet string) (int, error) {
	row := db.QueryRow("SELECT version FROM sheets WHERE id = ? AND project = ?", id, project)
	var version int
	if err := row.Scan(&version); err != nil {
		log.Println(err)
		return 0, err
	}
	version++

	_, err := db.Exec("UPDATE sheets SET version = ?, sheet = ? WHERE id = ?", version, sheet, id)
	if err != nil {
		log.Println(err)
		return 0, err
	}

	return version, nil
}

func uploadSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	name, sheet, err := getSheetFromForm(r)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	id, err := insertSheetInDB(db, proj, sheet, name)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, `{"id": %d}`, id)
}

func saveSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	id, _ := mux.Vars(r)["sheet"]

	sheet := r.FormValue("sheet")
	name := r.FormValue("name")

	if id == "" {
		newID, err := insertSheetInDB(db, proj, sheet, name)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		fmt.Fprintf(w, `{"id": %d}`, newID)
		return
	} else {
		currID, _ := strconv.Atoi(id)

		_, err := updateSheetInDB(db, currID, proj, sheet)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		fmt.Fprintf(w, `{"id": %d}`, currID)
	}
}

func updateSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	id, _ := strconv.Atoi(mux.Vars(r)["sheet"])
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	_, sheet, err := getSheetFromForm(r)
	if err != nil {
		w.WriteHeader(http.StatusNotAcceptable)
		log.Println(err)
		return
	}

	v, err := updateSheetInDB(db, id, proj, sheet)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, `{"version": %d}`, v)
}

func deleteSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	id, _ := strconv.Atoi(mux.Vars(r)["sheet"])
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	_, err := db.Exec("DELETE FROM sheets WHERE project = ? AND id = ?", proj, id)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}
