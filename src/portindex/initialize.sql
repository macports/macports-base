--
-- portindex-init.sql
-- 29-Jan-2004
-- kevin@opendarwin.org
--
-- This file creates the tables for the MacPorts port index and should
-- be executed before any subsequent portindex sql update files.

CREATE TABLE ports (
	pid INTEGER PRIMARY KEY NOT NULL,
	name VARCHAR(255) NOT NULL,
	version VARCHAR(255) NOT NULL,
	revision INTEGER NOT NULL
);

CREATE TABLE keywords (
	pid INTEGER NOT NULL,
	keyword VARCHAR(255) NOT NULL,
	value VARCHAR(255)
);
