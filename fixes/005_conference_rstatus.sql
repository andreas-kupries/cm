-- - - -- --- ----- -------- ------------- ---------------------
-- New column	"conference.rstatus", plus helper table for human-readable labeling.
-- 
-- Default to insert: 1 <=> pending

-- ---------------------------------------------------------------
CREATE TABLE rstatus (	-- fixed content
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	text		TEXT	NOT NULL UNIQUE
);
INSERT OR IGNORE INTO rstatus VALUES (1,'pending');
INSERT OR IGNORE INTO rstatus VALUES (2,'open');
INSERT OR IGNORE INTO rstatus VALUES (3,'closed');
-- --------------------------------------------------------------

CREATE TABLE new_conference (
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    title	TEXT	NOT NULL UNIQUE,
	    year	INTEGER NOT NULL,

	    management	INTEGER	NOT NULL REFERENCES contact,	-- Org/company/person managing the conference
	    submission	INTEGER	NOT NULL REFERENCES email,	-- Email to receive submissions.

	    city	INTEGER REFERENCES city,
	    hotel	INTEGER REFERENCES hotel, -- We do not immediately know where we will be
	    facility	INTEGER REFERENCES hotel, -- While sessions are usually at the hotel, they may not be.

	    startdate	INTEGER,		-- [*], date [epoch]
	    enddate	INTEGER,		--	date [epoch]
	    alignment	INTEGER NOT NULL,	-- iso8601 weekday (1:mon...7:sun), or -1 (no alignment)
	    length	INTEGER NOT NULL,	-- length in days

	    talklength	INTEGER NOT NULL,	-- minutes	  here we configure
	    sessionlen	INTEGER NOT NULL,	-- in #talks max  basic scheduling parameters.
						-- 		  shorter talks => longer sessions.
						-- 		  standard: 30 min x3
	    rstatus	INTEGER NOT NULL REFERENCES rstatus

	    -- Constraints:
	    -- * (city == facility->city) WHERE facility IS NOT NULL
	    -- * (city == hotel->city)    WHERE facility IS NULL AND hotel IS NOT NULL
	    --   Note: This covers the possibility of hotel->city != session->city
	    --   In that case we expect the conference to be in the city where the sessions are.
	    --
	    -- * year      == year-of    (start-date)
	    -- * alignment == weekday-of (start-date) WHERE alignment > 0.
	    -- * enddate   == startdate + length days

	    -- [Ad *] from this we can compute a basic timeline
	    --	for deadlines and actions (cfp's, submission
	    --	deadline, material deadline, etc)
	    --	Should possibly save it in a table, and allow
	    --	for conversion into ical and other calender formats.
	    --
	    -->	Google Calendar of the Conference, Mgmt + Public
)
;

-- Copy data
INSERT
INTO	new_conference
SELECT	id, title, year, management, submission, city, hotel, facility,
	startdate, enddate, alignment, length, talklength, sessionlen,
	1
FROM conference
;

-- Switch things around
DROP TABLE conference
;
ALTER TABLE new_conference RENAME TO conference
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
