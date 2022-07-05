DROP VIEW view_projects;

CREATE VIEW view_projects AS SELECT
    p.project,
    COALESCE((SELECT COUNT(*) FROM sheets s WHERE s.project = p.project), 0) number_of_sheets,
    COALESCE((SELECT COUNT(*) FROM (SELECT DISTINCT identifier FROM data d WHERE d.project = p.project) a), 0) number_of_identifiers,
    COALESCE((SELECT COUNT(*) FROM data d WHERE d.project = p.project), 0) number_of_datapoints,
    COALESCE((SELECT datetime(MAX(modified), 'unixepoch', 'localtime') FROM data d WHERE d.project = p.project), 'never') last_modified
FROM projects p;

UPDATE tagtags SET schema_version = 2;