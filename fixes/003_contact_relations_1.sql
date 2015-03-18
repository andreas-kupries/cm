-- - - -- --- ----- -------- ------------- ---------------------
-- New tables "affiliation" and "liaison" take to contain the
-- relationships between contacts.

-- This step creates the tables and fills them based on the data
-- in "contact.affiliation" and "contact.type".
-- 
-- A second step will remove the colunm "contact.affiliation"
-- after it is not used by the code any longer.

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE affiliation (
	-- Relationship between contacts.
	-- People may be affiliated with an organization, like their employer
	-- A table is used as a person may be affiliated with several orgs.

    	id	INTEGER NOT NULL PRIMARY KEY,
	person	INTEGER NOT NULL REFERENCES contact,
	company	INTEGER NOT NULL REFERENCES contact,
	UNIQUE (person, company)
);

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE liaison (
	-- Relationship between contacts.
	-- Company/orgs have people serving as their point of contact
	-- A table is used as an org may have several representatives

    	id	INTEGER NOT NULL PRIMARY KEY,
	company	INTEGER NOT NULL REFERENCES contact,
	person	INTEGER NOT NULL REFERENCES contact,
	UNIQUE (company, person)
);


-- - - -- --- ----- -------- ------------- ---------------------
-- Type 1 - Person       - affiliation (IF NOT NULL) => company the person is affiliated with
-- Type 2 - Company      - affiliation (IF NOT NULL) => person serving as liasion of the company
-- Type 3 - Mailing list - See type 2, although currently not used that way.

INSERT INTO affiliation
  -- VALUES (id,   person, company)
  SELECT     NULL, id,     affiliation
  FROM   contact
  WHERE  type = 1
  AND    affiliation IS NOT NULL
;

INSERT INTO liaison
  -- VALUES (id,   company, person)
  SELECT     NULL, id,      affiliation
  FROM   contact
  WHERE  type != 1
  AND    affiliation IS NOT NULL
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
