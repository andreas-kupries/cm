-- - - -- --- ----- -------- ------------- ---------------------
-- New column	"talk.done_mail_accepted"
-- 
-- Default to insert: 0 <=> no mail

-- --------------------------------------------------------------

CREATE TABLE new_talk (
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    submission	INTEGER	NOT NULL REFERENCES submission,	-- implies conference
	    type	INTEGER	NOT NULL REFERENCES talk_type,
	    state	INTEGER	NOT NULL REFERENCES talk_state,
	    isremote	INTEGER	NOT NULL,			-- hangout, skype, other ? => TEXT?
	    done_mail	INTEGER	NOT NULL,	-- acceptance mail has gone out for this one already

	    UNIQUE (submission) -- Not allowed to have the same submission in multiple conferences.

	    -- constraint: talk.conference == talk.submission.conference
)
;

-- Copy data
INSERT
INTO	new_talk
SELECT	id, submission, type, state, isremote, 0
FROM    talk
;

-- Switch things around
DROP TABLE talk
;
ALTER TABLE new_talk RENAME TO talk
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
