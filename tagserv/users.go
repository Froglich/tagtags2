package main

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"golang.org/x/crypto/bcrypt"
)

type user struct {
	ID         int    `json:"id"`
	Username   string `json:"username"`
	FullAccess bool   `json:"full_access,omitempty"`
	GroupMod   bool   `json:"group_mod,omitempty"`
}

type group struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	Members []user `json:"members,omitempty"`
	ProjMod bool   `json:"project_mod,omitempty"`
}

func (u *user) toJSON() []byte {
	out, _ := json.Marshal(u)
	return out
}

func (u *user) isGroupMod(db *sql.DB) bool {
	row := db.QueryRow("SELECT COUNT(*) >= 1 FROM user_groups WHERE user_id = ? AND modify = 1", u.ID)
	var isMod uint
	if err := row.Scan(&isMod); err != nil {
		return false
	}

	return isMod == 1
}

func (u *user) isModOfGroup(db *sql.DB, groupID int) bool {
	row := db.QueryRow("SELECT modify FROM user_groups WHERE user_id = ? and group_id = ?", u.ID, groupID)
	var modify int
	if err := row.Scan(&modify); err != nil {
		return false
	}

	return modify == 1
}

func (u *user) canAccessProject(db *sql.DB, proj string) bool {
	if u.FullAccess {
		return true
	}

	row := db.QueryRow("SELECT COALESCE(COUNT(*), 0) \"count\" FROM user_groups ug LEFT JOIN project_groups pg on ug.group_id = pg.group_id WHERE ug.user_id = ? AND pg.project = ?", u.ID, proj)
	var count int
	if err := row.Scan(&count); err != nil {
		return false
	}

	return count > 0
}

func (u *user) canModifyProject(db *sql.DB, proj string) bool {
	if u.FullAccess {
		return true
	}

	row := db.QueryRow("SELECT COALESCE(COUNT(*), 0) \"count\" FROM user_groups ug LEFT JOIN project_groups pg on ug.group_id = pg.group_id WHERE ug.user_id = ? AND pg.project = ? AND pg.can_modify = 1", u.ID, proj)
	var count int
	if err := row.Scan(&count); err != nil {
		return false
	}

	return count > 0
}

func (u *user) canAccessSheet(db *sql.DB, sheet int) bool {
	if u.FullAccess {
		return true
	}

	row := db.QueryRow("SELECT COALESCE(COUNT(*), 0) \"count\" FROM user_groups ug LEFT JOIN project_groups pg on ug.group_id = pg.group_id LEFT JOIN sheets s on pg.project = s.project WHERE ug.user_id = ? AND s.id = ?", u.ID, sheet)
	var count int
	if err := row.Scan(&count); err != nil {
		return false
	}

	return count > 0
}

func (u *user) getAccessibleSheets(db *sql.DB) []sheetDetails {
	params := make([]interface{}, 0)
	sheets := make([]sheetDetails, 0)
	var sql string

	if u.FullAccess {
		sql = "SELECT id, project, version, name FROM sheets"
	} else {
		sql = "SELECT DISTINCT s.id, s.project, s.version, s.name FROM sheets s LEFT JOIN project_groups pg on s.project = pg.project LEFT JOIN user_groups ug on pg.group_id = ug.group_id	WHERE user_id = ?"
		params = append(params, u.ID)
	}

	rows, err := db.Query(sql, params...)
	if err != nil {
		log.Println(err)
		return sheets
	}

	var id int
	var project string
	var version int
	var name string
	for rows.Next() {
		if err := rows.Scan(&id, &project, &version, &name); err == nil {
			sheets = append(sheets, sheetDetails{
				ID:      id,
				Project: project,
				Version: version,
				Name:    name,
			})
		}
	}

	return sheets
}

func getAllUsers(db *sql.DB) ([]user, error) {
	users := make([]user, 0)

	rows, err := db.Query("SELECT user_id, username FROM users")
	if err != nil {
		return nil, err
	}

	var userID int
	var username string
	for rows.Next() {
		if err := rows.Scan(&userID, &username); err != nil {
			return nil, err
		}
		users = append(users, user{ID: userID, Username: username})
	}

	return users, nil
}

func getAllGroups(db *sql.DB) ([]group, error) {
	groups := make([]group, 0)

	rows, err := db.Query("SELECT group_id, name FROM groups")
	if err != nil {
		return nil, err
	}

	var groupID int
	var name string
	for rows.Next() {
		if err := rows.Scan(&groupID, &name); err != nil {
			return nil, err
		}
		groups = append(groups, group{ID: groupID, Name: name})
	}

	return groups, nil
}

func getSessionIdentifier(r *http.Request) string {
	cookies := r.Cookies()

	for c := range cookies {
		if cookies[c].Name == "TAGTAGS" {
			return cookies[c].Value
		}
	}

	return ""
}

func checkCredentials(db *sql.DB, username string, password string) *user {
	row := db.QueryRow("SELECT user_id, pwhash, full_access FROM users WHERE username = ?", username)

	var userID int
	var hash string
	var fullAccess bool
	var u user

	if err := row.Scan(&userID, &hash, &fullAccess); err == nil {
		comparison := []byte(password)
		dbhash := []byte(hash)

		if err := bcrypt.CompareHashAndPassword(dbhash, comparison); err == nil {
			u.ID = userID
			u.Username = username
			u.FullAccess = fullAccess
			return &u
		}
	} else {
		fmt.Println(err)
	}

	return nil
}

func checkHeaderCredentials(db *sql.DB, r *http.Request) *user {
	_u := r.Header.Values("x-tagtags-username")
	_p := r.Header.Values("x-tagtags-password")
	if _u == nil || len(_u) != 1 || _p == nil || len(_p) != 1 {
		return nil
	}

	return checkCredentials(db, _u[0], _p[0])
}

func checkCookieCredentials(db *sql.DB, r *http.Request) *user {
	identifier := getSessionIdentifier(r)

	if identifier != "" {
		row := db.QueryRow("SELECT s.user_id, u.username, u.full_access FROM current_sessions s LEFT JOIN users u ON u.user_id = s.user_id WHERE identifier = $1", identifier)

		var userID int
		var username string
		var fullAccess bool
		err := row.Scan(&userID, &username, &fullAccess)
		if err == nil {
			return &user{
				ID:         userID,
				Username:   username,
				FullAccess: fullAccess,
			}
		}
	}

	return nil
}

func validateUser(db *sql.DB, r *http.Request) *user {
	if u := checkHeaderCredentials(db, r); u != nil {
		return u
	}

	if u := checkCookieCredentials(db, r); u != nil {
		return u
	}

	return nil
}

func requireValidUser(db *sql.DB, w http.ResponseWriter, r *http.Request) *user {
	if u := validateUser(db, r); u != nil {
		return u
	}

	log.Printf("Invalid access attempt from %s\n", r.RemoteAddr)
	http.Redirect(w, r, "/login", http.StatusSeeOther)

	return nil
}

func persistSession(db *sql.DB, u *user, remember bool) (*http.Cookie, error) {
	hashsum := sha256.Sum256([]byte(fmt.Sprintf("@DFuv^VJ$owy7ALpRQeipt6d7dU*!2JjH^pX2u6zWZcvH8ENDUUyBnYyUVR9^XhF!pKr43tZLjg&R7MPN&mgpKGp#YaJAovCoGLY2YLatK*3ck3yMFqu8w %d %v", u.ID, time.Now().UTC().UnixNano())))
	hexstring := hex.EncodeToString(hashsum[:])

	cookie := http.Cookie{Name: "TAGTAGS", Path: "/", Value: hexstring}

	if remember {
		_, err := db.Exec("INSERT INTO sessions(user_id, identifier, expires) VALUES(?, ?, datetime('now', '+1 year'))", u.ID, hexstring)

		if err != nil {
			return nil, err
		}

		cookie.Expires = time.Now().Add(time.Hour * 8640) //24h * 360days, omitting 5 days just as a buffer.
	} else {
		if _, err := db.Exec("INSERT INTO sessions(user_id, identifier) VALUES(?, ?)", u.ID, hexstring); err != nil {
			return nil, err
		}
	}

	return &cookie, nil
}

func createSession(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	username := r.FormValue("username")
	password := r.FormValue("password")
	remember := r.FormValue("remember") == "true"

	if u := checkCredentials(db, username, password); u != nil {
		cookie, err := persistSession(db, u, remember)

		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			log.Println(err)
			return
		}

		http.SetCookie(w, cookie)
	} else {
		w.WriteHeader(http.StatusUnauthorized)
		fmt.Fprint(w, "Invalid username or password.")
	}
}

func destroySession(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	if identifier := getSessionIdentifier(r); identifier != "" {
		if _, err := db.Exec("DELETE FROM sessions WHERE identifier = $1", identifier); err != nil {
			w.WriteHeader(http.StatusInternalServerError)
		} else {
			cookie := http.Cookie{Name: "TAGTAGS", Path: "/"}
			http.SetCookie(w, &cookie)
		}
	} else {
		w.WriteHeader(http.StatusBadRequest)
	}
}

func createUser(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	name := r.FormValue("username")
	pass := r.FormValue("password")
	fullAccess, _ := strconv.ParseBool(r.FormValue("full_access"))
	defer db.Close()

	user := validateUser(db, r)
	if user == nil || !user.FullAccess {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	rawHash, err := bcrypt.GenerateFromPassword([]byte(pass), 10)

	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		fmt.Fprint(w, "An unexpected error occurred while reading the password.")
		return
	}

	_, err = db.Exec("INSERT INTO users(username, pwhash, full_access) VALUES(?, ?, ?)", name, rawHash, fullAccess)
	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "An error occurred while trying to create the user: '%s'. Does a user with that name already exist?", err)
		return
	}

	row := db.QueryRow("SELECT user_id FROM users WHERE username = ?", name)
	var uid int
	if err := row.Scan(&uid); err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "The user was created but the user ID was not returned: '%v'", err)
		return
	}

	fmt.Fprintf(w, "%d", uid)
}

func setUserPassword(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	uid, _ := strconv.Atoi(mux.Vars(r)["uid"])
	pass := r.FormValue("password")
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil || (!u.FullAccess && u.ID != uid) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	if pass == "" {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Password can not be blank")
		return
	}

	rawHash, err := bcrypt.GenerateFromPassword([]byte(pass), 10)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		fmt.Fprint(w, "An unexpected error occurred while reading your password.")
		return
	}

	_, err = db.Exec("UPDATE users SET pwhash = ? WHERE user_id = ?", rawHash, uid)

	if err != nil {
		log.Println(err)
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "An error occurred while trying to update the password.")
	}
}

func setUserDetails(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	uid, _ := strconv.Atoi(mux.Vars(r)["uid"])
	rawData := r.FormValue("data")
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil || (!u.FullAccess && u.ID != uid) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	var nu user
	if err := json.Unmarshal([]byte(rawData), &nu); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	if nu.Username == "" {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "Username cant be blank.")
		return
	}

	if !u.FullAccess && nu.FullAccess {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	if u.FullAccess && u.ID == uid && !nu.FullAccess {
		w.WriteHeader(http.StatusBadRequest)
		fmt.Fprint(w, "You cant remove your own admin privileges")
		return
	}

	_, err := db.Exec("UPDATE users SET username = ?, full_access = ? WHERE user_id = ?", nu.Username, nu.FullAccess, uid)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprint(w, "Could not update the user, is the username taken?")
		log.Println(err)
		return
	}
}

func createGroup(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	groupname := r.FormValue("name")
	if groupname == "" {
		w.WriteHeader(http.StatusNotAcceptable)
		fmt.Fprint(w, "Blank names are not allowed.")
		return
	}

	_, err := db.Exec("INSERT INTO groups(name) VALUES(?)", groupname)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "Could not insert group: '%v'", err)
		log.Println(err)
		return
	}

	row := db.QueryRow("SELECT group_id FROM groups WHERE name = ?", groupname)
	var groupID int
	if err := row.Scan(&groupID); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Error while fetching new group ID '%v'\n", err)
		return
	}

	fmt.Fprintf(w, `{"group_id": %d}`, groupID)
}

func deleteGroup(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	groupID, _ := strconv.Atoi(mux.Vars(r)["group"])

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.isModOfGroup(db, groupID) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	_, err := db.Exec("DELETE FROM groups WHERE group_id = ?", groupID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Printf("Could not delete group %d: '%v'\n", groupID, err)
		return
	}
}

func addGroupMember(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	groupID, _ := strconv.Atoi(mux.Vars(r)["group"])
	userID, _ := strconv.Atoi(r.FormValue("user_id"))
	modify := r.FormValue("modify") == "true"

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.isModOfGroup(db, groupID) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	modifyInt := 0
	if modify {
		modifyInt = 1
	}

	_, err := db.Exec("INSERT INTO user_groups(user_id, group_id, modify) VALUES(?, ?, ?)", userID, groupID, modifyInt)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func updateGroupMember(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	groupID, _ := strconv.Atoi(mux.Vars(r)["group"])
	userID, _ := strconv.Atoi(mux.Vars(r)["user"])
	modify := r.FormValue("modify") == "true"

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.isModOfGroup(db, groupID) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	modifyInt := 0
	if modify {
		modifyInt = 1
	}

	_, err := db.Exec("UPDATE user_groups SET modify = ? WHERE user_id = ? AND group_id = ?", modifyInt, userID, groupID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func removeGroupMember(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	groupID, _ := strconv.Atoi(mux.Vars(r)["group"])
	userID, _ := strconv.Atoi(mux.Vars(r)["user"])

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.isModOfGroup(db, groupID) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	_, err := db.Exec("DELETE FROM user_groups WHERE user_id = ? AND group_id = ?", userID, groupID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func addProjectGroup(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	proj := mux.Vars(r)["project"]

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	canMod := 0
	if r.FormValue("can_modify") == "true" {
		canMod = 1
	}

	groupID, err := strconv.Atoi(r.FormValue("group"))
	if err != nil || groupID == 0 {
		w.WriteHeader(http.StatusNotAcceptable)
		return
	}

	_, err = db.Exec("INSERT INTO project_groups(project, group_id, can_modify) VALUES(?, ?, ?)", proj, groupID, canMod)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
}

func changeProjectGroup(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	proj := mux.Vars(r)["project"]
	groupID, _ := strconv.Atoi(mux.Vars(r)["group"])
	canMod := 0
	if r.FormValue("can_modify") == "true" {
		canMod = 1
	}

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	_, err := db.Exec("UPDATE project_groups SET can_modify = ? WHERE project = ? AND group_id = ?", canMod, proj, groupID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
}

func deleteProjectGroup(w http.ResponseWriter, r *http.Request) {
	db := getDBConnection()
	defer db.Close()

	proj := mux.Vars(r)["project"]
	groupID, _ := strconv.Atoi(mux.Vars(r)["group"])

	u := requireValidUser(db, w, r)
	if u == nil {
		return
	} else if !u.FullAccess && !u.canModifyProject(db, proj) {
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	_, err := db.Exec("DELETE FROM project_groups WHERE project = ? AND group_id = ?", proj, groupID)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		log.Println(err)
		return
	}
}
