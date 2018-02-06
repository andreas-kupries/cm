-- - - -- --- ----- -------- ------------- ---------------------
-- Added column "contact.is_dead"

-- - - -- --- ----- -------- ------------- ---------------------
CREATE TABLE new_affiliation (
    -- Relationship between contacts.
    -- People may be affiliated with an organization, like their employer
    -- A table is used as a person may be affiliated with several orgs.
    -- The flag `mailable` allows the person to control which of the
    -- affiliations should be listed in campaign mails.

    id		INTEGER NOT NULL PRIMARY KEY,
    person	INTEGER NOT NULL REFERENCES contact,
    company	INTEGER NOT NULL REFERENCES contact,
    mailable    INTEGER NOT NULL,
    UNIQUE (person, company)
);

-- - - -- --- ----- -------- ------------- ---------------------
-- default mailable to false.
INSERT INTO new_affiliation
SELECT id, person, company, 0
FROM affiliation
;

-- - - -- --- ----- -------- ------------- ---------------------
-- Switch things around
DROP TABLE affiliation
;
ALTER TABLE new_affiliation RENAME TO affiliation
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
