-- - - -- --- ----- -------- ------------- ---------------------
-- Add unique constraint toi "campaign_received" (mailrun, email)
--
-- Done via a helper table as sqlite's ALTER TABLE can only append new
-- columns and rename entire tables

CREATE TABLE new_campaign_received (
	    -- The addresses which received mailings. In case of a repeat mailing
	    -- for a template this information is used to prevent sending mail to
	    -- destinations which already got it.

	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    mailrun	INTEGER	NOT NULL REFERENCES campaign_mailrun,
	    email	INTEGER	NOT NULL REFERENCES email,	-- under contact
	    UNIQUE (mailrun,email)
)
;

-- Copy data
INSERT INTO new_campaign_received SELECT * FROM campaign_received
;

-- Switch things around
DROP TABLE campaign_received
;
ALTER TABLE new_campaign_received RENAME TO campaign_received
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
