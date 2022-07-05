CREATE TABLE settings (
	column_count INTEGER NOT NULL DEFAULT 0,
	sync_over_mobile INTEGER NOT NULL DEFAULT 0,
	download_images BOOL INTEGER NULL DEFAULT 0,
	accept_all_ssl_certificates INTEGER NOT NULL DEFAULT 0
);
INSERT INTO settings(column_count, sync_over_mobile, download_images) VALUES(0, 0, 0);

CREATE TABLE servers (
	id INTEGER PRIMARY KEY,
	address TEXT NOT NULL,
	username TEXT NOT NULL,
	password TEXT NOT NULL
);

CREATE TABLE projects (
	project TEXT NOT NULL PRIMARY KEY,
	server_id INTEGER REFERENCES servers(id) ON DELETE SET NULL
);

CREATE TABLE sync_log (
	project TEXT NOT NULL,
	synctime REAL NOT NULL DEFAULT ((julianday('now')-2440587.5) * 86400.0),
	manual INTEGER NOT NULL DEFAULT false
);

CREATE TABLE sheets (
	id TEXT NOT NULL,
    project TEXT NOT NULL REFERENCES projects(project),
    name TEXT NOT NULL,
    version INT DEFAULT 1 NOT NULL,
    sheet TEXT NOT NULL,
    PRIMARY KEY(id, project),
    UNIQUE(project, name)
);

CREATE TABLE types (
	id INTEGER PRIMARY KEY,
	name TEXT NOT NULL UNIQUE
);
INSERT INTO types(id,name) VALUES 
	(1,'text'), (2,'number'), 
	(3,'select'), (4,'date'), 
	(5,'time'), (6,'boolean'), 
	(7,'coordinates'), (8,'photo'), 
	(9,'data-view'), (10,'calculated');
	
CREATE TABLE identifiers (
	sheet_id TEXT NOT NULL,
    project TEXT NOT NULL,
    parameter TEXT NOT NULL,
    type_id INTEGER REFERENCES types(id),
    value TEXT NOT NULL,
    PRIMARY KEY(sheet_id, project, parameter),
    FOREIGN KEY(sheet_id, project) REFERENCES sheets(id, project) ON DELETE CASCADE
);

CREATE TABLE data (
	project TEXT NOT NULL REFERENCES projects(project),
	identifier TEXT NOT NULL,
	parameter TEXT NOT NULL,
	type_id INTEGER NOT NULL REFERENCES types(id),
	value TEXT NOT NULL,
	modified REAL NOT NULL DEFAULT ((julianday('now')-2440587.5) * 86400.0),
	synced INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY(project, identifier, parameter)
);
