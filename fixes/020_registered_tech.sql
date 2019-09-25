-- - - -- --- ----- -------- ------------- ---------------------
-- Added column "registered.tech"

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE new_registered (
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER NOT NULL REFERENCES conference,
	    contact	INTEGER	NOT NULL REFERENCES contact,	-- can_register (person)
	    walkin	INTEGER NOT NULL,			-- late-register fee
	    tech	INTEGER NOT NULL,			-- flag for tech session attendance
	    tut1	INTEGER REFERENCES tutorial_schedule,	-- tutorial selection
	    tut2	INTEGER REFERENCES tutorial_schedule,	-- all nullable
	    tut3	INTEGER REFERENCES tutorial_schedule,
	    tut4	INTEGER REFERENCES tutorial_schedule,
	    UNIQUE (conference, contact)
	    --	constraint: conference == tutX->conference, if tutX NOT NULL, X in 1-4
);

-- - - -- --- ----- -------- ------------- ---------------------
-- default to attendance of tech session
INSERT INTO new_registered
SELECT id, conference, contact, walkin, 1, tut1, tut2, tut3, tut4
FROM   registered
;

-- - - -- --- ----- -------- ------------- ---------------------
-- Switch things around
DROP TABLE registered
;
ALTER TABLE new_registered RENAME TO registered
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
