ALTER TABLE users ADD create_projects BOOL NOT NULL DEFAULT FALSE;
ALTER TABLE projects ADD created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL;

DROP VIEW view_project_access;
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

UPDATE tagtags SET schema_version = 3;