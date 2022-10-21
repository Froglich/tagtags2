CREATE TABLE tagtags (
    schema_version INTEGER NOT NULL
);
INSERT INTO tagtags(schema_version) VALUES (2);

CREATE TABLE users (
    user_id INTEGER NOT NULL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    pwhash TEXT NOT NULL,
    create_projects BOOL NOT NULL DEFAULT FALSE,
    full_access BOOL NOT NULL DEFAULT FALSE
);

CREATE TABLE sessions (
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    identifier TEXT NOT NULL UNIQUE,
    expires TIMESTAMP NOT NULL DEFAULT (datetime('now', '+1 day'))
);

CREATE VIEW current_sessions AS SELECT
    user_id, identifier
FROM sessions
WHERE datetime('now') < expires;

CREATE TABLE groups (
    group_id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE user_groups (
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES groups(group_id) ON DELETE CASCADE,
    modify INTEGER NOT NULL DEFAULT false,
    PRIMARY KEY(user_id, group_id)
);

CREATE TABLE projects (
    project TEXT NOT NULL PRIMARY KEY,
    created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE project_groups (
    project TEXT NOT NULL REFERENCES projects(project) ON DELETE CASCADE,
    group_id INTEGER NOT NULL REFERENCES groups(group_id) ON DELETE CASCADE,
    can_modify BOOL NOT NULL DEFAULT FALSE,
    PRIMARY KEY(project, group_id)
);

CREATE TABLE sheets (
    id INTEGER NOT NULL PRIMARY KEY,
    project TEXT NOT NULL REFERENCES projects(project) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,
    name TEXT NOT NULL,
    sheet TEXT NOT NULL,
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

CREATE TABLE data (
    project TEXT NOT NULL REFERENCES projects(project) ON DELETE CASCADE,
    identifier TEXT NOT NULL,
    parameter TEXT NOT NULL,
    type_id INT NOT NULL REFERENCES types(id),
    value TEXT NOT NULL,
    modified REAL NOT NULL DEFAULT ((julianday('now')-2440587.5)*86400.0),
    synctime REAL NOT NULL DEFAULT ((julianday('now')-2440587.5)*86400.0)
);
CREATE INDEX idx_identity ON data(project, identifier, parameter);

CREATE VIEW latest_data AS SELECT
    u.project,
    u.identifier,
    u.parameter,
    (SELECT type_id FROM data d WHERE d.project = u.project AND d.identifier = u.identifier AND d.parameter = u.parameter ORDER BY modified DESC LIMIT 1) type_id,
    (SELECT value FROM data d WHERE d.project = u.project AND d.identifier = u.identifier AND d.parameter = u.parameter ORDER BY modified DESC LIMIT 1) value,
    (SELECT modified FROM data d WHERE d.project = u.project AND d.identifier = u.identifier AND d.parameter = u.parameter ORDER BY modified DESC LIMIT 1) modified,
    (SELECT synctime FROM data d WHERE d.project = u.project AND d.identifier = u.identifier AND d.parameter = u.parameter ORDER BY modified DESC LIMIT 1) synctime
FROM(SELECT DISTINCT project, identifier, parameter FROM data) u;

CREATE VIEW view_projects AS SELECT
    p.project,
    COALESCE((SELECT COUNT(*) FROM sheets s WHERE s.project = p.project), 0) number_of_sheets,
    COALESCE((SELECT COUNT(*) FROM (SELECT DISTINCT identifier FROM data d WHERE d.project = p.project) a), 0) number_of_identifiers,
    COALESCE((SELECT COUNT(*) FROM data d WHERE d.project = p.project), 0) number_of_datapoints,
    COALESCE((SELECT datetime(MAX(modified), 'unixepoch', 'localtime') FROM data d WHERE d.project = p.project), 'never') last_modified
FROM projects p;

CREATE VIEW view_project_identifiers AS SELECT
    d.project,
    d.identifier,
    COALESCE((SELECT COUNT(*) FROM (SELECT DISTINCT parameter FROM data da WHERE da.project = d.project AND da.identifier = d.identifier) a), 0) number_of_parameters,
    COALESCE((SELECT COUNT(*) FROM data da WHERE da.project = d.project AND da.identifier = d.identifier), 0) number_of_datapoints,
    COALESCE((SELECT datetime(MAX(modified), 'unixepoch', 'localtime') FROM data da WHERE da.project = d.project AND da.identifier = d.identifier), 'never') last_modified
FROM (SELECT DISTINCT project, identifier FROM data d) d;

CREATE VIEW view_project_access AS SELECT
    u.user_id,
    p.project,
    CASE
        WHEN u.full_access
        THEN 1
        WHEN (SELECT COUNT(*) FROM project_groups pg LEFT JOIN user_groups ug ON ug.group_id = pg.group_id WHERE pg.project = p.project AND ug.user_id = u.user_id) > 0
        THEN 1
        WHEN u.user_id = p.created_by
        THEN 1
        ELSE 0
    END viewable,
    CASE
        WHEN u.full_access
        THEN 1
        WHEN (SELECT COUNT(*) FROM project_groups pg LEFT JOIN user_groups ug ON ug.group_id = pg.group_id WHERE pg.project = p.project AND ug.user_id = u.user_id AND pg.can_modify = 1) > 0
        THEN 1
        WHEN u.user_id = p.created_by
        THEN 1
        ELSE 0
    END editable
FROM users u, projects p;

CREATE VIEW view_sheet_access AS SELECT
    vpa.project,
    vpa.user_id,
    s.id sheet_id,
    s.name sheet_name,
    s.version sheet_version,
    vpa.viewable
FROM view_project_access vpa
LEFT JOIN sheets s ON s.project = vpa.project
WHERE s.id IS NOT NULL;