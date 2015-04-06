-- - - -- --- ----- -------- ------------- ---------------------
-- New column	"timeline.done"
-- 
-- Default to insert: 1 <=> pending

-- --------------------------------------------------------------

CREATE TABLE new_timeline (
	    -- conference timeline/calendar of action items, deadlines, etc.

	    id	 INTEGER NOT NULL PRIMARY KEY,
	    con	 INTEGER NOT NULL REFERENCES conference,
	    date INTEGER NOT NULL,		-- when this happens [epoch]
	    type INTEGER NOT NULL REFERENCES timeline_type,
	    done INTEGER NOT NULL
)
;

-- Copy data
INSERT
INTO	new_timeline
SELECT	id, con, date, type, 0
FROM    timeline
;

-- Switch things around
DROP TABLE timeline
;
ALTER TABLE new_timeline RENAME TO timeline
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
