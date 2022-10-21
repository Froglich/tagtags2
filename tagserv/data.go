package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

func readAllThenClose(rc io.ReadCloser) ([]byte, error) {
	defer rc.Close()
	return ioutil.ReadAll(rc)
}

type dataPoint struct {
	Project      string  `json:"project"`
	Identifier   string  `json:"identifier"`
	Parameter    string  `json:"parameter"`
	TypeID       int     `json:"type_id"`
	Value        string  `json:"value"`
	Modified     float64 `json:"modified"`
	Alternatives int     `json:"alternatives,omitempty"`
}

func (dp *dataPoint) UTCTime() string {
	i := int64(dp.Modified)

	t := time.Unix(i, 0)
	return t.Format("2006-01-02 15:04:05")
}

func (dp *dataPoint) toJSON() []byte {
	o, _ := json.Marshal(dp)
	return o
}

func (dp *dataPoint) insert(db *sql.DB) bool {
	_, err := db.Exec("INSERT INTO data(project, identifier, parameter, type_id, value, modified) VALUES(?,?,?,?,?,?)", dp.Project, dp.Identifier, dp.Parameter, dp.TypeID, dp.Value, dp.Modified)
	if err != nil {
		log.Printf("Could not save datapoint: '%v'\n", err)
		return false
	}

	return true
}

func postDatapoint(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	project := mux.Vars(r)["project"]
	ident := mux.Vars(r)["identifier"]
	param := mux.Vars(r)["parameter"]
	defer db.Close()

	rawData, err := readAllThenClose(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Println(err)
		return
	}

	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, project) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var dp dataPoint
	err = json.Unmarshal(rawData, &dp)
	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	if dp.Project != project || dp.Identifier != ident || dp.Parameter != param {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	if !dp.insert(db) {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	row := db.QueryRow("SELECT value, modified FROM latest_data WHERE project = ? AND identifier = ? AND parameter = ? AND type_id = ?", dp.Project, dp.Identifier, dp.Parameter, dp.TypeID)
	var val string
	var mod float64
	if err := row.Scan(&val, &mod); err != nil {
		fmt.Fprint(w, "NA")
		log.Printf("Could not fetch most recent data for datapoint: '%v'", err)
		return
	}

	dp.Value = val
	dp.Modified = mod
	w.Write(dp.toJSON())
}

func postData(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	project := mux.Vars(r)["project"]
	defer db.Close()

	rawData, err := readAllThenClose(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, project) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	data := make([]dataPoint, 0)
	err = json.Unmarshal(rawData, &data)
	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	for x := range data {
		dp := data[x]

		if dp.Project != project {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		if !dp.insert(db) {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	}
}

func postBinaryData(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	project := mux.Vars(r)["project"]
	defer db.Close()

	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, project) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	reader, err := r.MultipartReader()
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "The server expected multipart-data.")
		log.Println(err)
		return
	}

	frm, err := reader.ReadForm(20971520)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Could not process the uploaded file.")
		log.Println(err)
		return
	}

	var data dataPoint
	rawData, ok := frm.Value["data"]
	if ok && len(rawData) > 0 {
		err := json.Unmarshal([]byte(rawData[0]), &data)
		if err != nil {
			log.Println(err)
			w.WriteHeader(http.StatusNotAcceptable)
			return
		}
	} else {
		w.WriteHeader(http.StatusBadRequest)
		log.Println("Could not read datapoint json.")
		return
	}

	_f := frm.File["file"][0]

	file, err := _f.Open()
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
	}
	defer file.Close()

	if _f.Filename != data.Value || data.Project != project {
		w.WriteHeader(http.StatusNotAcceptable)
		log.Println("Data missmatch.")
		return
	}

	if strings.ContainsAny(_f.Filename, `\/`) || _f.Filename == "." || _f.Filename == ".." {
		w.WriteHeader(http.StatusNotAcceptable)
		log.Println("possible path exploit detected")
		return
	}

	nfile := path.Join("files", _f.Filename)

	if _, err = os.Stat(nfile); err == nil {
		w.WriteHeader(http.StatusConflict)
		log.Println("A file with that name already exists.")
		return
	} else if !os.IsNotExist(err) {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Unexpected I/O error: '%v'", err)
		return
	}

	var buf []byte
	readBuffer := bytes.NewBuffer(buf)

	_, err = readBuffer.ReadFrom(file)
	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	fcontent := readBuffer.Bytes()

	err = ioutil.WriteFile(nfile, fcontent, 0644)

	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	if !data.insert(db) {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func getData(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	p := mux.Vars(r)["project"]
	mts := r.Header.Values("x-tagtags-mostrecentsync")
	defer db.Close()

	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, p) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var rows *sql.Rows
	var err error
	var fts float64

	if len(mts) > 0 {
		fts, err = strconv.ParseFloat(mts[0], 64)
	}

	if err == nil {
		rows, err = db.Query("SELECT project, identifier, parameter, type_id, value, modified FROM latest_data WHERE project = ? AND synctime > ?", p, fts)
	} else {
		rows, err = db.Query("SELECT project, identifier, parameter, type_id, value, modified FROM latest_data WHERE project = ?", p)
	}

	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	var project string
	var identifier string
	var parameter string
	var typeID int
	var value string
	var modified float64
	data := make([]dataPoint, 0)
	for rows.Next() {
		if err := rows.Scan(&project, &identifier, &parameter, &typeID, &value, &modified); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}

		data = append(data, dataPoint{
			Project:    project,
			Identifier: identifier,
			Parameter:  parameter,
			TypeID:     typeID,
			Value:      value,
			Modified:   modified,
		})
	}

	out, err := json.Marshal(data)
	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	w.Write(out)
}

func getBinaryData(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	p := mux.Vars(r)["project"]
	fname := mux.Vars(r)["filename"]
	defer db.Close()

	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, p) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	if strings.ContainsAny(fname, `\/`) || fname == "." || fname == ".." {
		w.WriteHeader(http.StatusBadRequest)
		log.Println("detected possible path exploit attempt")
		return
	}

	row := db.QueryRow("SELECT COALESCE(COUNT(*), 0) FROM data WHERE project = ? AND value = ? AND type_id = 8", p, fname)
	var count int
	if err := row.Scan(&count); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Unexpected error while listing files in the database: '%v'\n", err)
		return
	}

	if count == 0 {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	if err := passFileToClient(w, path.Join("files", fname), fname); err != nil {
		w.WriteHeader(http.StatusNotFound)
		log.Printf("An error occurred while sending a file: '%v'\n", err)
	}
}

func passFileToClient(w http.ResponseWriter, filename string, title string) error {
	f, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer f.Close()

	w.Header().Set("Content-disposition", fmt.Sprintf("filename=\"%s\"", title))
	_, err = io.Copy(w, f)

	if err != nil {
		return err
	}

	return nil
}

type tempFile struct {
	FileName string
}

func (tf *tempFile) remove() {
	os.Remove(tf.FileName)
}

func writeTempFile(content string) (*tempFile, error) {
	fn := path.Join(os.TempDir(), uuid.New().String())
	err := os.WriteFile(fn, []byte(content), 0644)
	if err != nil {
		return nil, err
	}

	return &tempFile{FileName: fn}, nil
}

func queryInStringFromArray(arr []string) string {
	idStrA := make([]string, len(arr))

	for x := range arr {
		idStrA[x] = "?"
	}

	return fmt.Sprintf("(%s)", strings.Join(idStrA, ","))
}

func stringSliceToInterfaceSlice(stringSlice []string) []interface{} {
	is := make([]interface{}, len(stringSlice))

	for x := range stringSlice {
		is[x] = interface{}(stringSlice[x])
	}

	return is
}

func sheetProjectDataToTSV(db *sql.DB, project string, sheet int, identifiers []string) (string, error) {
	ttSheet, err := getSheetFromDB(db, sheet)
	if err != nil {
		return "", err
	}

	params := ttSheet.getAllFields()

	return projectDataToTSV(db, project, identifiers, params, queryInStringFromArray(identifiers))
}

func allProjectDataToTSV(db *sql.DB, project string, identifiers []string) (string, error) {
	params := make([]string, 0)
	queryInString := queryInStringFromArray(identifiers)
	queryParams := make([]string, 0)
	queryParams = append(queryParams, identifiers...)
	queryParams = append(queryParams, project)

	rows, err := db.Query(fmt.Sprintf("SELECT DISTINCT parameter FROM latest_data WHERE identifier IN %s AND project = ? ORDER BY parameter", queryInString), stringSliceToInterfaceSlice(queryParams)...)
	if err != nil {
		return "", err
	}

	var param string
	for rows.Next() {
		if err := rows.Scan(&param); err != nil {
			return "", err
		}

		params = append(params, param)
	}

	return projectDataToTSV(db, project, identifiers, params, queryInString)
}

func projectDataToTSV(db *sql.DB, project string, identifiers []string, params []string, queryInString string) (string, error) {
	tsv := []string{fmt.Sprintf("Project\tIdentifier\t%s", strings.Join(params, "\t"))}

	subqueries := make([]string, 0)
	queryParams := make([]string, 0)
	for x := range params {
		subqueries = append(subqueries, "COALESCE((SELECT value FROM latest_data WHERE project = a.project AND identifier = a.identifier AND parameter = ?),'')")
		queryParams = append(queryParams, params[x])
	}

	query := fmt.Sprintf("SELECT project,identifier,%s FROM (SELECT DISTINCT project,identifier FROM latest_data WHERE identifier IN %s AND project = ?) a ORDER BY identifier", strings.Join(subqueries, ","), queryInString)
	queryParams = append(queryParams, identifiers...)
	queryParams = append(queryParams, project)

	rows, err := db.Query(query, stringSliceToInterfaceSlice(queryParams)...)
	if err != nil {
		log.Printf("Could not query for project data: '%v'\n", err)
		return "", err
	}

	outRow := make([]interface{}, len(params)+2)
	for x := range outRow {
		var val string
		outRow[x] = &val
	}
	for rows.Next() {
		err = rows.Scan(outRow...)
		if err != nil {
			log.Printf("Could not read output from DB: '%v'\n", err)
			return "", err
		}

		line := make([]string, 0)
		for x := range outRow {
			line = append(line, *outRow[x].(*string))
		}

		tsv = append(tsv, strings.Join(line, "\t"))
	}

	return strings.Join(tsv, "\n"), nil
}

func downloadAllTSVData(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	p := mux.Vars(r)["project"]
	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, p) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var idents []string
	var rawIdents = r.FormValue("identifiers")
	err := json.Unmarshal([]byte(rawIdents), &idents)
	if err != nil {
		w.WriteHeader(http.StatusNotAcceptable)
		log.Printf("An error occurred while unmarshaling identifiers JSON: '%v'\n", err)
		return
	}

	tsv, err := allProjectDataToTSV(db, p, idents)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not export data to TSV: '%v'\n", err)
		return
	}

	tf, err := writeTempFile(tsv)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not write temporary file: '%v'\n", err)
		return
	}
	defer tf.remove()

	w.Header().Set("Content-disposition", fmt.Sprintf("filename=\"%s TagTags-export %d identifiers.tsv\"", p, len(idents)))
	fmt.Fprint(w, tsv)
}

func downloadSheetTSVData(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	project := mux.Vars(r)["project"]
	sheet, _ := strconv.Atoi(mux.Vars(r)["sheet"])

	u := validateUser(db, r)
	if u == nil || !u.canAccessProject(db, project) || !sheetBelongsToProject(db, project, sheet) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var idents []string
	var rawIdents = r.FormValue("identifiers")
	err := json.Unmarshal([]byte(rawIdents), &idents)
	if err != nil {
		w.WriteHeader(http.StatusNotAcceptable)
		log.Printf("An error occurred while unmarshaling identifiers JSON: '%v'\n", err)
		return
	}

	tsv, err := sheetProjectDataToTSV(db, project, sheet, idents)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not export data to TSV: '%v'\n", err)
		return
	}

	tf, err := writeTempFile(tsv)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not write temporary file: '%v'\n", err)
		return
	}
	defer tf.remove()

	w.Header().Set("Content-disposition", fmt.Sprintf("filename=\"%s (%d) TagTags-export %d identifiers.tsv\"", project, sheet, len(idents)))
	fmt.Fprint(w, tsv)
}
