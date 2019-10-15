-- - - -- --- ----- -------- ------------- ---------------------
-- Added column "contact.honorific"

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE new_contact (
	-- General data for specific types of contact:
	-- actual person
	-- A badge description (affiliation) to put with the name

	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	tag		TEXT 	UNIQUE,			-- for html anchors, and quick identification
	type		INTEGER NOT NULL REFERENCES contact_type,
	name	 	TEXT	NOT NULL UNIQUE,	-- identification NOCASE -- lower(dname)
	dname	 	TEXT	NOT NULL,		-- display name
	honorific	TEXT,				-- a person's honorific to put before the name
	badge		TEXT,				-- a person's badge text (affiliation)
	biography	TEXT,				-- a person's bio, or list/project/company description
	bio_public	INTEGER NOT NULL,		-- bio is generally public
	can_recvmail	INTEGER NOT NULL,	-- valid recipient of conference mail (call for papers)
	can_register	INTEGER NOT NULL,	-- actual person can register for attendance
	can_book	INTEGER NOT NULL,	-- actual person can book hotels
	can_talk	INTEGER NOT NULL,	-- actual person can do presentation
	can_submit	INTEGER NOT NULL,	-- actual person, or company can submit talks
	is_dead         INTEGER NOT NULL	-- true for deceased person ...
);

-- - - -- --- ----- -------- ------------- ---------------------
-- default honorific to nothing
INSERT INTO new_contact
SELECT id, tag, type, name, dname, honorific, NULL, biography, 0,
       can_recvmail, can_register, can_book, can_talk, can_submit, is_dead
FROM contact
;

-- - - -- --- ----- -------- ------------- ---------------------
-- Switch things around
DROP TABLE contact
;
ALTER TABLE new_contact RENAME TO contact
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
