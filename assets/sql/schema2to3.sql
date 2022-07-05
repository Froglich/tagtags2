CREATE TABLE sheets_tmp (
    id TEXT NOT NULL,
    project TEXT NOT NULL REFERENCES projects(project),
    name TEXT NOT NULL,
    version INT DEFAULT 1 NOT NULL,
    sheet TEXT NOT NULL,
    PRIMARY KEY(id, project),
    UNIQUE(project, name)
);

insert into sheets_tmp(id, project, name, version, sheet)
select CAST(id AS TEXT), project, name, version, sheet
from sheets;

DROP TABLE sheets;

ALTER TABLE sheets_tmp RENAME TO sheets;

CREATE TABLE identifiers_tmp (
    sheet_id TEXT NOT NULL,
    project TEXT NOT NULL,
    parameter TEXT NOT NULL,
    type_id INTEGER REFERENCES types(id),
    value TEXT NOT NULL,
    PRIMARY KEY(sheet_id, project, parameter),
    FOREIGN KEY(sheet_id, project) REFERENCES sheets(id, project) ON DELETE CASCADE
);

INSERT INTO identifiers_tmp(sheet_id, project, parameter, type_id, value)
SELECT i.sheet_id, s.project, i.parameter, i.type_id, i.value
FROM identifiers i
LEFT JOIN sheets s ON s.id = CAST(i.sheet_id AS TEXT);

DROP TABLE identifiers;

ALTER TABLE identifiers_tmp RENAME TO identifiers;