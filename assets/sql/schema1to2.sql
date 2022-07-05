CREATE TABLE identifiers_tmp (
	sheet_id INTEGER NOT NULL REFERENCES sheets(id) ON DELETE CASCADE,
	parameter TEXT NOT NULL,
	type_id INTEGER REFERENCES types(id),
	value TEXT NOT NULL,
	PRIMARY KEY (sheet_id, parameter)
);
INSERT INTO identifiers_tmp(sheet_id, parameter, type_id, value) SELECT sheet_id, parameter, type_id, value FROM identifiers;
DROP TABLE identifiers;
ALTER TABLE identifiers_tmp RENAME TO identifiers;