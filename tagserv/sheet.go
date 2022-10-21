package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

type tagTagsField struct {
	ID               string   `json:"id"`
	Title            string   `json:"title"`
	TypeID           uint     `json:"type"`
	Desc             *string  `json:"description,omitempty"`
	Mandatory        *bool    `json:"mandatory,omitempty"`
	RememberValues   *bool    `json:"rememeber_values,omitempty"`
	VisibleIf        *string  `json:"visible_if,omitempty"`
	Alternatives     []string `json:"alternatives,omitempty"`
	AllowOther       *bool    `json:"allow_other,omitempty"`
	CheckedIsDefault *bool    `json:"default_checked,omitempty"`
	BarcodeReader    *bool    `json:"barcode,omitempty"`
	Function         *string  `json:"function,omitempty"`
	FollowUpValues   []string `json:"followup_values,omitempty"`
}

type tagTagsGroup struct {
	Title       string         `json:"title"`
	Description *string        `json:"description,omitempty"`
	Fields      []tagTagsField `json:"fields"`
	Constructor string         `json:"constructor,omitempty"`
}

type tagTagsSheet struct {
	Columns    uint           `json:"columns"`
	SinglePage bool           `json:"single_page,omitempty"`
	Name       string         `json:"name"`
	Project    string         `json:"-"`
	Version    uint           `json:"-"`
	Identifier tagTagsGroup   `json:"identifier"`
	Groups     []tagTagsGroup `json:"groups"`
}

func sheetFromJSON(sheet []byte) (*tagTagsSheet, error) {
	var ns tagTagsSheet
	err := json.Unmarshal(sheet, &ns)
	if err != nil {
		return nil, err
	}

	return &ns, nil
}

func getSheetFromDB(db *sql.DB, id int) (*tagTagsSheet, error) {
	row := db.QueryRow("SELECT sheet FROM sheets WHERE id = ?", id)
	var sheet string
	if err := row.Scan(&sheet); err != nil {
		return nil, err
	}

	return sheetFromJSON([]byte(sheet))
}

func sheetBelongsToProject(db *sql.DB, project string, sheet int) bool {
	row := db.QueryRow("SELECT COUNT(*) FROM sheets WHERE id = ? AND project = ?", sheet, project)
	var count int
	if err := row.Scan(&count); err != nil {
		return false
	}

	fmt.Println(sheet, project, count)

	return count == 1
}

func (s *tagTagsSheet) getAllFields() []string {
	fields := make([]string, 0)

	for _, g := range s.Groups {
		for _, f := range g.Fields {
			fields = append(fields, f.ID)
		}
	}

	return fields
}
