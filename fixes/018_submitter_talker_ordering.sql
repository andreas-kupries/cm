-- - - -- --- ----- -------- ------------- ---------------------
-- Added columns "submitter.ordering", "talker.ordering"

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE new_talker (
    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
    talk	INTEGER	NOT NULL REFERENCES talk,
    contact	INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk||can_submit
    ordering    INTEGER NOT NULL,
    UNIQUE (talk, contact)

    -- We allow multiple speakers => panels, co-presentation
    -- Note: Presenter is not necessarily any of the submitters of the submission behind the talk
);

CREATE TABLE new_submitter (
    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
    submission	INTEGER	NOT NULL REFERENCES submission,
    contact	INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk||can_submit
    note	TEXT,					-- distinguish author, co-author, if wanted
    ordering    INTEGER NOT NULL,
    UNIQUE (submission, contact)
);

-- - - -- --- ----- -------- ------------- ---------------------
-- default ordering to rowid.
INSERT INTO new_talker
SELECT id, talk, contact, rowid
FROM talker
;

INSERT INTO new_submitter
SELECT id, submission, contact, note, rowid
FROM submitter
;

-- - - -- --- ----- -------- ------------- ---------------------
-- Switch things around
DROP TABLE talker
;
ALTER TABLE new_talker RENAME TO talker
;

DROP TABLE submitter
;
ALTER TABLE new_submitter RENAME TO submitter
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
