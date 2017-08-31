-- - - -- --- ----- -------- ------------- ---------------------
-- Added column "contact.bio_public"
-- Added column "email.public"

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE new_contact (
	-- General data for any type of contact:
	-- actual person, mailing list, company
	-- The flags determine what we can do with a contact.

	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	tag		TEXT 	UNIQUE,			-- for html anchors, and quick identification
	type		INTEGER NOT NULL REFERENCES contact_type,
	name	 	TEXT	NOT NULL UNIQUE,	-- identification NOCASE -- lower(dname)
	dname	 	TEXT	NOT NULL,		-- display name
	biography	TEXT,				-- a person's bio, or list/project/company description
	bio_public	INTEGER NOT NULL,		-- bio is generally public
	can_recvmail	INTEGER NOT NULL,	-- valid recipient of conference mail (call for papers)
	can_register	INTEGER NOT NULL,	-- actual person can register for attendance
	can_book	INTEGER NOT NULL,	-- actual person can book hotels
	can_talk	INTEGER NOT NULL,	-- actual person can do presentation
	can_submit	INTEGER NOT NULL	-- actual person, or company can submit talks
);

-- - - -- --- ----- -------- ------------- ---------------------
-- default bio publicity to 'private'
INSERT INTO new_contact
SELECT id, tag, type, name, dname, biography, 0,
       can_recvmail, can_register, can_book, can_talk, can_submit
FROM contact
;

-- - - -- --- ----- -------- ------------- ---------------------
-- Switch things around
DROP TABLE contact
;
ALTER TABLE new_contact RENAME TO contact
;

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE new_email (
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    email	TEXT	NOT NULL UNIQUE,
	    contact	INTEGER	NOT NULL REFERENCES contact,
	    inactive	INTEGER	NOT NULL,	-- mark outdated addresses
	    public	INTEGER	NOT NULL	-- mark visible addresses
);

-- - - -- --- ----- -------- ------------- ---------------------
-- default email publicity to 'private'
INSERT INTO new_email
SELECT id, email, contact, inactive, 0
FROM email
;

-- - - -- --- ----- -------- ------------- ---------------------
-- Switch things around
DROP TABLE email
;
ALTER TABLE new_email RENAME TO email
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
