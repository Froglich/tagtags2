package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"path"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

type navigationItem struct {
	Title  string
	Path   string
	Active bool
}

type header struct {
	Title           string
	User            *user
	NavigationItems []navigationItem
}

type webProject struct {
	Project      string
	Sheets       uint
	Identifiers  uint
	Datapoints   uint
	LastModified string
	Editable     bool
}

type webIdentifier struct {
	Identifier   string
	Parameters   uint
	Datapoints   uint
	LastModified string
}

const (
	IndexPage    uint = 1
	UsersPage    uint = 2
	GroupsPage   uint = 3
	ProjectsPage uint = 4
)

func loadViews() *template.Template {
	views := make([]string, 0)
	files, err := ioutil.ReadDir("templates")

	if err != nil {
		log.Panicln(err)
	}

	for x := range files {
		f := files[x]
		if !f.IsDir() && strings.HasSuffix(f.Name(), "gohtml") {
			views = append(views, path.Join("templates", f.Name()))
		}
	}

	t, err := template.ParseFiles(views...)

	if err != nil {
		log.Panicln(err)
	}

	return t
}

func buildHeader(title string, u *user, pageType uint) header {
	db := getDBConnection()
	defer db.Close()

	navigationItems := []navigationItem{
		{Title: "Index", Path: "/", Active: pageType == IndexPage},
		{Title: "Projects", Path: "/projects", Active: pageType == ProjectsPage},
	}

	if u.FullAccess {
		navigationItems = append(navigationItems, navigationItem{Title: "Users", Path: "/users", Active: pageType == UsersPage})
	}

	if u.FullAccess || u.isGroupMod(db) {
		navigationItems = append(navigationItems, navigationItem{Title: "Groups", Path: "/groups", Active: pageType == GroupsPage})
	}

	return header{
		Title:           title,
		User:            u,
		NavigationItems: navigationItems,
	}
}

func renderHTML(w http.ResponseWriter, view string, data interface{}) {
	t := loadViews()

	err := t.ExecuteTemplate(w, view, data)

	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Panicln(err)
	}
}

func sendDefaultPage(w http.ResponseWriter, view string, title string, pageType uint, u *user, data interface{}) {
	renderHTML(w, "_header.gohtml", buildHeader(title, u, pageType))
	renderHTML(w, view, data)
	renderHTML(w, "_footer.gohtml", nil)
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	renderHTML(w, "login.gohtml", nil)
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	}

	sendDefaultPage(w, "index.gohtml", "Index", IndexPage, u, nil)
}

func helpExpressionsHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	}

	sendDefaultPage(w, "help_expressions.gohtml", "Expressions", ProjectsPage, u, nil)
}

func createProject(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	projectID := r.FormValue("id")
	if projectID == "" {
		w.WriteHeader(http.StatusNotAcceptable)
		fmt.Fprint(w, "The project ID may not be blank.")
		return
	}

	if _, err := db.Exec("INSERT INTO projects(project) VALUES(?)", projectID); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "Error while inserting project: '%v'", err)
		log.Println(err)
	}
}

func usersHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	rows, err := db.Query("SELECT user_id, username, full_access FROM users")
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	users := make([]user, 0)
	var userID int
	var username string
	var fullAccess uint
	for rows.Next() {
		if err := rows.Scan(&userID, &username, &fullAccess); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}

		users = append(users, user{ID: userID, Username: username, FullAccess: fullAccess == 1})
	}

	sendDefaultPage(w, "users.gohtml", "Users", UsersPage, u, users)
}

func groupsHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.isGroupMod(db) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var rows *sql.Rows
	var err error
	if u.FullAccess {
		rows, err = db.Query("SELECT group_id, name FROM groups")
	} else if u.isGroupMod(db) {
		rows, err = db.Query("SELECT g.group_id, g.name FROM user_groups ug LEFT JOIN groups g ON g.group_id = ug.group_id WHERE ug.user_id = ? AND ug.modify = 1", u.ID)
	} else {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	var groupID int
	var groupName string
	groups := make([]group, 0)
	for rows.Next() {
		if err := rows.Scan(&groupID, &groupName); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}

		ur, err := db.Query("SELECT ug.user_id, u.username, ug.modify FROM user_groups ug LEFT JOIN users u ON u.user_id = ug.user_id WHERE ug.group_id = ?", groupID)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}

		var userID int
		var userName string
		var canModify int
		users := make([]user, 0)
		for ur.Next() {
			if err := ur.Scan(&userID, &userName, &canModify); err != nil {
				w.WriteHeader(http.StatusInternalServerError)
				log.Println(err)
				return
			}

			usr := user{ID: userID, Username: userName}
			if canModify == 1 {
				usr.GroupMod = true
			}
			users = append(users, usr)
		}

		groups = append(groups, group{ID: groupID, Name: groupName, Members: users})
	}

	var pd struct {
		User   *user
		Users  []user
		Groups []group
	}

	pd.User = u
	pd.Groups = groups
	pd.Users, err = getAllUsers(db)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	sendDefaultPage(w, "groups.gohtml", "Groups", GroupsPage, u, pd)
}

func userHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	uid := mux.Vars(r)["uid"]
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	row := db.QueryRow("SELECT username, full_access FROM users WHERE user_id = ?", uid)
	var username string
	var fullAccess uint
	if err := row.Scan(&username, &fullAccess); err != nil {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	var pu user
	pu.Username = username
	pu.FullAccess = fullAccess == 1

	w.Write(pu.toJSON())
}

func projectsHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	}

	projects := make([]webProject, 0)
	rows, err := db.Query("SELECT vpa.project, vp.number_of_sheets, vp.number_of_identifiers, vp.number_of_datapoints, vp.last_modified, vpa.editable FROM view_project_access vpa LEFT JOIN view_projects vp ON vpa.project = vp.project WHERE vpa.user_id = ? AND vpa.viewable = 1", u.ID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not fetch project list: '%v'\n", err)
		return
	}

	var project string
	var sheets uint
	var identifiers uint
	var datapoints uint
	var lastmodified string
	var editable uint
	for rows.Next() {
		if err := rows.Scan(&project, &sheets, &identifiers, &datapoints, &lastmodified, &editable); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Printf("Could not scan project list: '%v'\n", err)
			return
		}

		projects = append(projects, webProject{Project: project, Sheets: sheets, Identifiers: identifiers, Datapoints: datapoints, LastModified: lastmodified, Editable: editable == 1})
	}

	var pd struct {
		User     *user
		Projects []webProject
	}

	pd.User = u
	pd.Projects = projects

	sendDefaultPage(w, "projects.gohtml", "Projects", ProjectsPage, u, pd)
}

func projectHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	}

	if !u.canAccessProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var pd struct {
		Project   string
		CanModify bool
	}

	pd.Project = proj
	pd.CanModify = u.canModifyProject(db, proj)

	sendDefaultPage(w, "project.gohtml", "Project", ProjectsPage, u, pd)
}

func projectSheetsHandler(w http.ResponseWriter, r *http.Request) {
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

	var pd struct {
		Project string
		Sheets  []sheetDetails
	}

	pd.Project = proj
	pd.Sheets = make([]sheetDetails, 0)

	rows, err := db.Query("SELECT id, version, name FROM sheets WHERE project = ?", proj)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	var sheetID int
	var sheetVersion int
	var sheetName string
	for rows.Next() {
		if err := rows.Scan(&sheetID, &sheetVersion, &sheetName); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}
		pd.Sheets = append(pd.Sheets, sheetDetails{ID: sheetID, Version: sheetVersion, Name: sheetName})
	}

	sendDefaultPage(w, "project_sheets.gohtml", "Project sheets", ProjectsPage, u, pd)
}

type sheetPage struct {
	Project   string
	SheetData json.RawMessage
	SheetName *string
}

func createSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	proj := mux.Vars(r)["project"]

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	sendDefaultPage(w, "sheet_edit.gohtml", "Create a sheet", ProjectsPage, u, sheetPage{Project: proj, SheetData: nil, SheetName: nil})
}

func editSheet(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	proj := mux.Vars(r)["project"]
	sheet, _ := strconv.Atoi(mux.Vars(r)["sheet"])

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	row := db.QueryRow("SELECT sheet, name FROM sheets WHERE project = ? AND id = ?", proj, sheet)
	var sheetData []byte
	var name string

	if err := row.Scan(&sheetData, &name); err != nil {
		w.WriteHeader(http.StatusNotFound)
		log.Printf("while getting sheet for editing: '%v'\n", err)
		return
	}

	sendDefaultPage(w, "sheet_edit.gohtml", "Edit sheet", ProjectsPage, u, sheetPage{Project: proj, SheetData: sheetData, SheetName: &name})
}

func projectGroupsHandler(w http.ResponseWriter, r *http.Request) {
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

	var pd struct {
		Project       string
		ProjectGroups []group
		AllGroups     []group
	}

	pd.Project = proj
	pd.ProjectGroups = make([]group, 0)
	pd.AllGroups = make([]group, 0)

	rows, err := db.Query("SELECT g.group_id, g.name, pg.can_modify FROM project_groups pg LEFT JOIN groups g ON g.group_id = pg.group_id WHERE pg.project = ?", proj)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	var groupID int
	var groupName string
	var modify int
	for rows.Next() {
		if err := rows.Scan(&groupID, &groupName, &modify); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}

		pd.ProjectGroups = append(pd.ProjectGroups, group{ID: groupID, Name: groupName, ProjMod: modify == 1})
	}

	rows, err = db.Query("SELECT group_id, name FROM groups")
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}

	for rows.Next() {
		if err := rows.Scan(&groupID, &groupName); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}

		pd.AllGroups = append(pd.AllGroups, group{ID: groupID, Name: groupName})
	}

	sendDefaultPage(w, "project_groups.gohtml", "Project groups", ProjectsPage, u, pd)
}

func projectDataHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	}

	if !u.canAccessProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var pd struct {
		Project       string
		Identifiers   []webIdentifier
		CanModify     bool
		ProjectGroups []group
		AllGroups     []group
	}

	pd.Project = proj
	pd.Identifiers = make([]webIdentifier, 0)
	pd.ProjectGroups = make([]group, 0)
	pd.AllGroups = make([]group, 0)
	pd.CanModify = u.canModifyProject(db, proj)

	rows, err := db.Query("SELECT identifier, number_of_parameters, number_of_datapoints, last_modified FROM view_project_identifiers WHERE project = ? ORDER BY last_modified DESC", proj)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not get identifiers for project: '%v'\n", err)
		return
	}

	var identifier string
	var parameters uint
	var datapoints uint
	var lastmodified string
	for rows.Next() {
		if err := rows.Scan(&identifier, &parameters, &datapoints, &lastmodified); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Printf("Could not scan data: '%v'\n", err)
			return
		}

		pd.Identifiers = append(pd.Identifiers, webIdentifier{Identifier: identifier, Parameters: parameters, Datapoints: datapoints, LastModified: lastmodified})
	}

	rows, err = db.Query("SELECT pg.group_id, g.name, pg.can_modify FROM project_groups pg LEFT JOIN groups g ON g.group_id = pg.group_id WHERE pg.project = ?", proj)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not get groups for project: '%v'\n", err)
		return
	}

	var groupID int
	var groupName string
	var canModify int
	for rows.Next() {
		if err := rows.Scan(&groupID, &groupName, &canModify); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Printf("Could not read group info for project: '%v'\n", err)
			return
		}

		pd.ProjectGroups = append(pd.ProjectGroups, group{ID: groupID, Name: groupName, ProjMod: canModify == 1})
	}

	pd.AllGroups, err = getAllGroups(db)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not list groups: '%v'", err)
		return
	}

	sendDefaultPage(w, "project_data.gohtml", "Project data", ProjectsPage, u, pd)
}

func dataIdentifierHandler(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	proj := mux.Vars(r)["project"]
	ident := mux.Vars(r)["identifier"]
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	}

	if !u.canAccessProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	rows, err := db.Query("SELECT parameter, type_id, value, modified, (SELECT COUNT(*) FROM data d WHERE d.project = a.project AND d.identifier = a.identifier AND d.parameter = a.parameter) alternatives FROM (SELECT project, identifier, parameter, type_id, value, modified FROM latest_data WHERE project = ? AND identifier = ?) a ORDER BY modified", proj, ident)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not query database for data: '%v'\n", err)
		return
	}

	var parameter string
	var typeID int
	var value string
	var modified float64
	var alts int
	var pd struct {
		Project    string
		Identifier string
		DataPoints []dataPoint
	}

	pd.Project = proj
	pd.Identifier = ident

	pd.DataPoints = make([]dataPoint, 0)
	for rows.Next() {
		if err := rows.Scan(&parameter, &typeID, &value, &modified, &alts); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Printf("Could not read data from database: '%v'\n", err)
			return
		}

		if value != "" {
			pd.DataPoints = append(pd.DataPoints, dataPoint{Project: proj, Identifier: ident, Parameter: parameter, TypeID: typeID, Value: value, Modified: modified, Alternatives: alts})
		}
	}

	sendDefaultPage(w, "identity_data.gohtml", "Identifier data", ProjectsPage, u, pd)
}
