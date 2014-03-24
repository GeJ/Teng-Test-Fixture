CREATE TABLE IF NOT EXISTS division (
  id   INTEGER     NOT NULL PRIMARY KEY ASC,
  name VARCHAR(32) NOT NULL
);

CREATE TABLE IF NOT EXISTS project (
  id          INTEGER     NOT NULL PRIMARY KEY ASC,
  name        VARCHAR(32) NOT NULL,
  division_id INTEGER     NOT NULL,
  FOREIGN KEY (division_id) REFERENCES division(id)
);

CREATE TABLE IF NOT EXISTS employee (
  id          INTEGER     NOT NULL PRIMARY KEY ASC,
  name        VARCHAR(32) NOT NULL,
  division_id INTEGER     NOT NULL,
  FOREIGN KEY (division_id) REFERENCES division(id)
);
CREATE UNIQUE INDEX employee_division_ukey ON employee(id, division_id);

CREATE TABLE IF NOT EXISTS team (
  id          INTEGER     NOT NULL PRIMARY KEY ASC,
  name        VARCHAR(32) NOT NULL,
  division_id INTEGER     NOT NULL,
  project_id  INTEGER     NOT NULL,
  FOREIGN KEY (division_id) REFERENCES division(id),
  FOREIGN KEY (project_id)  REFERENCES project(id)
);
CREATE UNIQUE INDEX team_division_ukey ON employee(id, division_id);

CREATE TABLE IF NOT EXISTS team_members (
  employee_id INTEGER NOT NULL,
  division_id INTEGER NOT NULL,
  team_id     INTEGER NOT NULL,
  FOREIGN KEY (employee_id, division_id) REFERENCES employee(id, division_id),
  FOREIGN KEY (team_id, division_id)     REFERENCES team(id, division_id)
);
