-- - - -- --- ----- -------- ------------- ---------------------
-- New column	"conference.pschedule"
-- 
-- Default to insert: NULL

-- ---------------------------------------------------------------

ALTER TABLE conference
ADD COLUMN pschedule INTEGER REFERENCES pschedule
;

-- Done
-- - - -- --- ----- -------- ------------- ---------------------
