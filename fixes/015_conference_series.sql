-- - - -- --- ----- -------- ------------- ---------------------
-- New column	"conference.series", plus table for human-readable labeling.
-- The supporting table ("series") already exists.
-- 
-- Default to insert: 1 <=> 'North-American Conferences'

-- ---------------------------------------------------------------

CREATE TABLE new_conference (
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    title	TEXT	NOT NULL UNIQUE,
	    year	INTEGER NOT NULL,

	    series INTEGER NOT NULL REFERENCES series,

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
	    rstatus	INTEGER NOT NULL REFERENCES rstatus,
	    pvisible	INTEGER NOT NULL REFERENCES pvisible,
	    pschedule   INTEGER REFERENCES pschedule
)
;

-- Copy data
INSERT
INTO	new_conference
SELECT	id, title, year, 1, management, submission, city, hotel, facility,
	startdate, enddate, alignment, length, talklength, sessionlen,
	rstatus, pvisible, pschedule
FROM conference
;

-- Switch things around
DROP TABLE conference
;
ALTER TABLE new_conference RENAME TO conference
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
