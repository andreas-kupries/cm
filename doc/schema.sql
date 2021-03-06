-- Database schema for conference mgmt
-- ---------------------------------------------------------------
CREATE TABLE config (
	-- Configuration data of the application itself.
	-- No relations to the conference tables.

	key   TEXT NOT NULL PRIMARY KEY,
	value TEXT NOT NULL
);
-- ---------------------------------------------------------------
CREATE TABLE city (	-- we have been outside US in past
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	name		TEXT,
	state		TEXT,
	nation		TEXT,
	UNIQUE (name, state, nation)
);
-- ---------------------------------------------------------------
CREATE TABLE location (
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	name		TEXT    NOT NULL,
	city		INTEGER NOT NULL REFERENCES city,
	streetaddress	TEXT    NOT NULL,
	zipcode		TEXT    NOT NULL,
	book_fax	TEXT,		-- defaults to the local-*
	book_link	TEXT,
	book_phone	TEXT,
	local_fax	TEXT	UNIQUE,
	local_link	TEXT	UNIQUE,
	local_phone	TEXT	UNIQUE,
	transportation	TEXT,		-- html block (maps, descriptions, etc)
	UNIQUE (city, streetaddress)
);
-- ---------------------------------------------------------------
CREATE TABLE location_staff (
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	location	INTEGER NOT NULL REFERENCES location,
	position	TEXT	NOT NULL,
	name		TEXT	NOT NULL,
	email		TEXT,	-- either email or phone must be set, i.e. not null
	phone		TEXT,	-- no idea how to specify such constraint in sql
	UNIQUE (location, position, familyname, firstname) -- Same person may have multiple positions
);
-- ---------------------------------------------------------------
CREATE TABLE rate (				-- rates change from year to year
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	conference	INTEGER	NOT NULL REFERENCES conference,
	location	INTEGER	NOT NULL REFERENCES location,
	rate		INTEGER	NOT NULL,	-- per night
	decimal		INTEGER	NOT NULL,	-- number of digits stored after the decimal point
	currency	TEXT	NOT NULL,	-- name of the currency the rate is in
	groupcode	TEXT,
	begindate	INTEGER,		-- date [epoch] the discount begins
	enddate		INTEGER,		-- date [epoch] the discount ends
	deadline	INTEGER,		-- date [epoch] registration deadline
	pdeadline	INTEGER,		-- date [epoch] same, but publicly known
						-- show a worse deadline public for grace period
	-- Constraints: begin- and end-dates should cover the entire conference, at least.
	-- deadline should not be in the past on date of entry.
	UNIQUE (conference, location)
	-- We are sort of ready here for a future where we might have multiple hotels
	-- and associated rates. If so 'conference.hotel' would become bogus.
);
-- ---------------------------------------------------------------
CREATE TABLE contact (
	-- General data for any type of contact:
	-- actual person, mailing list, company
	-- The flags determine what we can do with a contact.

	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	tag		TEXT		 UNIQUE,	-- for html anchors, and quick identification
	type		INTEGER NOT NULL REFERENCES contact_type,
	name		TEXT	NOT NULL UNIQUE,	-- identification NOCASE -- lower(dname)
	dname		TEXT	NOT NULL,		-- display name
	biography	TEXT,

	affiliation	INTEGER REFERENCES contact,	-- person  => company they belong to
	                                                -- company => person used as liaison
	                                                -- mlist   => not applicable

	can_recvmail	INTEGER NOT NULL,	-- valid recipient of conference mail (call for papers)
	can_register	INTEGER NOT NULL,	-- actual person can register for attendance
	can_book	INTEGER NOT NULL,	-- actual person can book hotels
	can_talk	INTEGER NOT NULL,	-- actual person can do presentation
	can_submit	INTEGER NOT NULL,	-- actual person, or company can submit talks

	-- Note: Deactivation of contact in a campaign is handled by the contact/campaign linkage
);
-- INDEX on type
-- ---------------------------------------------------------------
CREATE TABLE contact_type (
    	id	INTEGER NOT NULL PRIMARY KEY,
    	text	TEXT    NOT NULL UNIQUE
);
INSERT OR IGNORE INTO contact_type VALUES (1,'Person');
INSERT OR IGNORE INTO contact_type VALUES (2,'Company');
INSERT OR IGNORE INTO contact_type VALUES (3,'Mailinglist');
-- ---------------------------------------------------------------
CREATE TABLE affiliation (
	-- Relationship between contacts.
	-- People may be affiliated with an organization, like their employer
	-- A table is used as a person may be affiliated with several orgs.

    	id	INTEGER NOT NULL PRIMARY KEY,
	person	INTEGER NOT NULL REFERENCES contact,
	company	INTEGER NOT NULL REFERENCES contact,
	UNIQUE (person, company)
);
-- ---------------------------------------------------------------
CREATE TABLE liaison (
	-- Relationship between contacts.
	-- Company/orgs have people serving as their point of contact
	-- A table is used as an org may have several representatives

    	id	INTEGER NOT NULL PRIMARY KEY,
	company	INTEGER NOT NULL REFERENCES contact,
	person	INTEGER NOT NULL REFERENCES contact,
	UNIQUE (company, person)
);
-- ---------------------------------------------------------------
CREATE TABLE email (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	email		TEXT	NOT NULL UNIQUE,
	contact		INTEGER	NOT NULL REFERENCES contact,
	inactive	INTEGER	NOT NULL 	-- mark outdated addresses
);
-- INDEX on contact
-- ---------------------------------------------------------------
CREATE TABLE link (
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	contact		INTEGER	NOT NULL REFERENCES contact,
	link		TEXT	NOT NULL, -- same link text can be used by multiple contacts
	title		TEXT,
	UNIQUE (contact, link)
);
-- INDEX on contact
-- INDEX on link
-- ---------------------------------------------------------------
CREATE TABLE campaign (
	-- Email campaign for a conference.

	id	INTEGER NOT NULL 	PRIMARY KEY AUTOINCREMENT,
	con	INTEGER NOT NULL UNIQUE	REFERENCES conference,	-- one campaign per conference only
	active	INTEGER NOT NULL				-- flag
);
-- ---------------------------------------------------------------
CREATE TABLE campaign_destination (
	-- Destination addresses for the campaign

	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	campaign	INTEGER	NOT NULL REFERENCES campaign,
	email		INTEGER NOT NULL REFERENCES email,	-- contact is indirect
	UNIQUE (campaign,email)
);
-- ---------------------------------------------------------------
CREATE TABLE campaign_mailrun (
	-- Mailings executed so far

	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	campaign	INTEGER	NOT NULL REFERENCES campaign,
	template	INTEGER NOT NULL REFERENCES template,	-- mail text template
	date		INTEGER NOT NULL			-- timestamp [epoch]
);
-- INDEX on campaign
-- INDEX on template
-- ---------------------------------------------------------------
CREATE TABLE campaign_received (
	-- The addresses which received mailings. In case of a repeat mailing
	-- for a template this information is used to prevent sending mail to
	-- destinations which already got it.

	id	INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	mailrun	INTEGER	NOT NULL REFERENCES campaign_mailrun/,
	email	INTEGER	NOT NULL REFERENCES email	-- under contact
);
-- INDEX on mailrun
-- ---------------------------------------------------------------
CREATE TABLE template (
	-- Text templates for mail campaigns

	id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	name	TEXT    NOT NULL UNIQUE,
	value	TEXT	NOT NULL
);
-- ---------------------------------------------------------------
CREATE TABLE tutorial (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	speaker		INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk
	tag		TEXT	NOT NULL,			-- for html anchors
	title		TEXT	NOT NULL,
	prereq		TEXT,
	description	TEXT	NOT NULL,
	UNIQUE (speaker, tag),
	UNIQUE (speaker, title)
);
-- ---------------------------------------------------------------
CREATE TABLE conference (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	title		TEXT	UNIQUE,
	year		INTEGER,

	management	INTEGER	NOT NULL REFERENCES contact,	-- Org/company/person managing the conference
	submission	INTEGER	NOT NULL REFERENCES email,	-- Email to receive submissions.

	city		INTEGER	REFERENCES city,
	hotel		INTEGER REFERENCES location	-- We will not immediately know where we will be
	facility	INTEGER REFERENCES location	-- While sessions are usually at the hotel, they may not be.

	startdate	INTEGER,		-- [*], date [epoch]
	enddate		INTEGER,		--	date [epoch]
	alignment	INTEGER NOT NULL,	-- iso8601 weekday (1:mon...7:sun), or -1 (no alignment)
	length		INTEGER NOT NULL,	-- length in days

	talklength	INTEGER,		-- minutes	  here we configure
	sessionlen	INTEGER,		-- in #talks max  basic scheduling parameters.
				 		-- 		  shorter talks => longer sessions.
				 		-- 		  standard: 30 min x3
	pschedule	INTEGER REFERENCES pschedule,
						-- physical schedule PS to use for the conference.
						-- the logical schedule filling the holes/placeholders
						-- in the PS are stored in table "schedule".
	rstatus		INTEGER NOT NULL REFERENCES rstatus

	-- future expansion columns:
	-- -- max day|range for tutorials
	-- -- max number of tracks for tutorials
	-- -- max number of tracks for sessions

	-- Constraints:
	-- * (city == facility->city) WHERE facility IS NOT NULL
	-- * (city == hotel->city)    WHERE facility IS NULL AND hotel IS NOT NULL
	--   Note: This covers the possibility of hotel->city != session->city
	--   In that case we expect the conference to be in the city where the sessions are.
	--
	-- * year      == year-of    (start-date)
	-- * alignment == weekday-of (start-date) WHERE alignment > 0.
	-- * enddate   == startdate + length days

	-- [Ad *] from this we can compute a basic timeline
	--	for deadlines and actions (cfp's, submission
	--	deadline, material deadline, etc)
	--	Should possibly save it in a table, and allow
	--	for conversion into ical and other calender formats.
	--
	-->	Google Calendar of the Conference, Mgmt + Public
);
-- ---------------------------------------------------------------
CREATE TABLE rstatus (	-- fixed content
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	text		TEXT	NOT NULL UNIQUE
);
INSERT OR IGNORE INTO rstatus VALUES (1,'pending');
INSERT OR IGNORE INTO rstatus VALUES (2,'open');
INSERT OR IGNORE INTO rstatus VALUES (3,'closed');
-- ---------------------------------------------------------------
CREATE TABLE conference_staff (
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	conference	INTEGER NOT NULL REFERENCES conference,
	contact		INTEGER NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk
	role		INTEGER NOT NULL REFERENCES staff_role,
	UNIQUE (conference, contact, role)
	-- Multiple people can have the same role (ex: program commitee)
	-- One person can have multiple roles (ex: prg.chair, prg. committee)
);
-- ---------------------------------------------------------------
CREATE TABLE staff_role (	-- semi-fixed content
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	text		TEXT	NOT NULL UNIQUE	-- chair, facilities chair, program chair, program committee,
					-- web admin, proceedings editor, hotel liason, ...
);
INSERT OR IGNORE INTO staff_role VALUES (1,'Chair');
INSERT OR IGNORE INTO staff_role VALUES (2,'Facilities chair');
INSERT OR IGNORE INTO staff_role VALUES (3,'Program chair');
INSERT OR IGNORE INTO staff_role VALUES (4,'Program committee');
INSERT OR IGNORE INTO staff_role VALUES (5,'Hotel liaison');
INSERT OR IGNORE INTO staff_role VALUES (6,'Web admin');
INSERT OR IGNORE INTO staff_role VALUES (7,'Proceedings editor');
-- ---------------------------------------------------------------
CREATE TABLE timeline (
	-- conference timeline/calendar of action items, deadlines, etc.

	id	INTEGER NOT NULL PRIMARY KEY,
	con	INTEGER NOT NULL REFERENCES conference,
	date	INTEGER NOT NULL,		-- when this happens [epoch]
	type	INTEGER NOT NULL REFERENCES timeline_type
);
-- INDEX on con
-- ---------------------------------------------------------------
CREATE TABLE timeline_type (
	-- The possible types of action items in the conference timeline
	-- public items are for use within mailings, the website, etc.
	-- internal items are for the mgmt only.
	-- the offset [in days] is used to compute the initial proposal
	-- of a timeline for the conference. 

	id		INTEGER NOT NULL PRIMARY KEY,
	ispublic	INTEGER NOT NULL,
	offset		INTEGER NOT NULL,	-- >0 => days after conference start
						-- <0 => days before start
	key		TEXT    NOT NULL UNIQUE,	-- internal key for the type
	text		TEXT    NOT NULL UNIQUE		-- human-readable
);
INSERT OR IGNORE INTO timeline_type VALUES ( 1,0,-168,'cfp1',      '1st Call for papers');         --  -24w
INSERT OR IGNORE INTO timeline_type VALUES ( 2,0,-126,'cfp2',      '2nd Call for papers');         --  -18w
INSERT OR IGNORE INTO timeline_type VALUES ( 3,0, -84,'cfp3',      '3rd Call for papers');         --  -12w
INSERT OR IGNORE INTO timeline_type VALUES ( 4,1, -84,'wipopen',   'WIP & BOF Reservations open'); --  -12w
INSERT OR IGNORE INTO timeline_type VALUES ( 5,1, -56,'submitdead','Submissions due');             --   -8w
INSERT OR IGNORE INTO timeline_type VALUES ( 6,1, -49,'authornote','Notifications to Authors');    --   -7w
INSERT OR IGNORE INTO timeline_type VALUES ( 7,1, -21,'writedead', 'Author Materials due');        --   -3w
INSERT OR IGNORE INTO timeline_type VALUES ( 8,0, -14,'procedit',  'Edit proceedings');            --   -2w
INSERT OR IGNORE INTO timeline_type VALUES ( 9,0,  -7,'procship',  'Ship proceedings');            --   -1w
INSERT OR IGNORE INTO timeline_type VALUES (10,1,   0,'begin-t',   'Tutorial Start');              --  <=>
INSERT OR IGNORE INTO timeline_type VALUES (11,1,   2,'begin-s',   'Session Start');               --  +2d
-- ---------------------------------------------------------------
CREATE TABLE tutorial_schedule (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	conference	INTEGER	NOT NULL REFERENCES conference,
	day		INTEGER	NOT NULL,			-- 0,1,... (offset from start of conference, 0-based)
	half		INTEGER	NOT NULL REFERENCES dayhalf,
	track		INTEGER	NOT NULL,				-- 1,2,... (future expansion)
	tutorial	INTEGER	NOT NULL REFERENCES tutorial,
	UNIQUE (conference, day, half, track),
	UNIQUE (conference, tutorial)
);
-- ---------------------------------------------------------------
CREATE TABLE dayhalf (	-- fixed content
	id		INTEGER	NOT NULL PRIMARY KEY,	-- 1,2,3
	text		TEXT	NOT NULL UNIQUE		-- morning,afternoon,evening
);
INSERT OR IGNORE INTO dayhalf VALUES (1,'morning');
INSERT OR IGNORE INTO dayhalf VALUES (2,'afternoon');
INSERT OR IGNORE INTO dayhalf VALUES (3,'evening');
-- ---------------------------------------------------------------
CREATE TABLE submission (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	conference	INTEGER	NOT NULL REFERENCES conference,
	title		TEXT	NOT NULL,
	abstract	TEXT	NOT NULL,
	summary		TEXT,
	invited		INTEGER	NOT NULL,	-- keynotes are a special submission made by mgmt
	submitdate	INTEGER	NOT NULL,	-- date of submission [epoch].
	UNIQUE (conference, title)

	-- acceptance is implied by having a talk referencing the submission.
);
-- ---------------------------------------------------------------
CREATE TABLE submitter (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	submission	INTEGER	NOT NULL REFERENCES submission,
	contact		INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk||can_submit
	note		TEXT,					-- distinguish author, co-author, if wanted
	UNIQUE (submission, contact)
);
-- INDEX on contact
-- ---------------------------------------------------------------
CREATE TABLE talk (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	submission	INTEGER	NOT NULL REFERENCES submission,	-- implies conference
	type		INTEGER	NOT NULL REFERENCES talk_type,
	state		INTEGER	NOT NULL REFERENCES talk_state,
	isremote	INTEGER	NOT NULL,			-- hangout, skype, other ? => TEXT?

	UNIQUE (submission) -- Not allowed to have the same submission in multiple conferences.

	-- constraint: talk.conference == talk.submission.conference
);
-- ---------------------------------------------------------------
CREATE TABLE attachment (
	id	INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	talk	INTEGER	NOT NULL REFERENCES talk,
	type	TEXT	NOT NULL,	-- Readable type/label
	mime	TEXT	NOT NULL,	-- mime type for downloads and the like?
	data	BLOB	NOT NULL,
	UNIQUE (talk, type)
);
-- ---------------------------------------------------------------
CREATE TABLE talker (
	talk		INTEGER	REFERENCES talk,
	contact		INTEGER	REFERENCES contact,	-- can_talk

	UNIQUE (talk, contact)

	-- We allow multiple speakers => panels, co-presentation
	-- Note: Presenter is not necessarily any of the submitters of the submission behind the talk
);
-- ---------------------------------------------------------------
CREATE TABLE talk_type (	-- fixed contents
	id		INTEGER PRIMARY KEY AUTOINCREMENT,	-- invited, submitted, keynote, panel
	text		TEXT	UNIQUE
);
INSERT OR IGNORE INTO talk_type VALUES (1,'invited');
INSERT OR IGNORE INTO talk_type VALUES (2,'submitted');
INSERT OR IGNORE INTO talk_type VALUES (3,'keynote');
INSERT OR IGNORE INTO talk_type VALUES (4,'panel');
-- ---------------------------------------------------------------
CREATE TABLE talk_state (	-- fixed contents
	id		INTEGER PRIMARY KEY AUTOINCREMENT,	-- material pending, received
	text		TEXT	UNIQUE
);
INSERT OR IGNORE INTO talk_state VALUES (1,'pending');
INSERT OR IGNORE INTO talk_state VALUES (2,'received');
-- ---------------------------------------------------------------
CREATE TABLE schedule (
	conference	INTEGER NOT NULL REFERENCES conference,
	day		INTEGER NOT NULL,		-- 2,3,4,... (offset from start of conference, 0-based)
	session		INTEGER NOT NULL,		-- session within the day
	slot		INTEGER,			-- slot within the session, null => whole session talk (keynotes)
	talk		INTEGER REFERENCES talk,	-- While setting things up
	UNIQUE (conference, day, session, slot)
	-- constraint: conference == talk->submission->conference)
);
-- ---------------------------------------------------------------
CREATE TABLE registered ( -- conference registrations <=> attendee register
	conference	INTEGER NOT NULL REFERENCES conference,
	contact		INTEGER	NOT NULL REFERENCES contact,		-- can_register
	walkin		INTEGER NOT NULL,				-- late-register fee
	tut1		INTEGER REFERENCES tutorial_schedule,	-- tutorial selection
	tut2		INTEGER REFERENCES tutorial_schedule,	-- all nullable
	tut3		INTEGER REFERENCES tutorial_schedule,
	tut4		INTEGER REFERENCES tutorial_schedule,
	talk		INTEGER REFERENCES talk,		-- presenter discount
	UNIQUE (conference, contact)
	--	constraint: conference == tutX->conference, if tutX NOT NULL, X in 1-4
);
-- ---------------------------------------------------------------
CREATE TABLE booked (	-- hotel bookings
	conference	INTEGER NOT NULL REFERENCES conference,
	contact		INTEGER NOT NULL REFERENCES contact,	-- can_book
	hotel		INTEGER	NOT NULL REFERENCES location,	-- may not be the conference hotel!
	UNIQUE (conference, contact)
);
-- ---------------------------------------------------------------
CREATE TABLE notes (
	conference	INTEGER REFERENCES conference,
	contact		INTEGER REFERENCES contact,
	text		TEXT    NOT NULL
	-- general notes, and notes attached to people
	-- constraint: only one of "conference" and "contact" is allowed to be NULL.
	-- example: we know that some contact C will not use the conference hotel
);

-- ---------------------------------------------------------------
-- speaker state is derivable from the contents of
--	talk, registered, booked, plus notes
--
-- Future:
-- - Track fee schedule for tutorials (pull out of the template)
-- - Track student/presenter discount flags
--   - Presenter flag is not redundant, registration / acceptance race.
-- - The storage of the tutorials for a registrant makes assumptions
--   about number of T's. And code makes more assumptions about the used
--   days/dayhalfs.
-- 

-- ---------------------------------------------------------------
CREATE TABLE pschedule (
	-- Common information for physical schedules:
	-- Names.
	-- The main scheduling information is found in the
	-- "pschedule_item"s instead.
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
,	name		TEXT	NOT NULL UNIQUE
);
-- ---------------------------------------------------------------
CREATE TABLE pschedule_track (
	-- Information for tracks of a physical schedule: Names.
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT	-- track identifier
,	pschedule	INTEGER	NOT NULL REFERENCES pschedule		-- schedule the track belongs to.
,	name		TEXT	NOT NULL				-- track name, unique with a schedule.
,	UNIQUE (pschedule, name)
);
-- ---------------------------------------------------------------
CREATE TABLE pschedule_item (
	-- A physical schedule consists of a set of items describing
        -- the events of the schedule. They are called "physical"
        -- because they specify exact timing of events, i.e. start/length,
	-- plus track information. Events can be fixed, or placeholders.
	-- The logical schedule of a specific conference will then reference
	-- and fill the placeholders with the missing information.

	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT	-- item identifier
,	pschedule	INTEGER	NOT NULL REFERENCES pschedule		-- schedule the item is part of
,	day		INTEGER NOT NULL				-- day of the event (0-based)
,	track		INTEGER		 REFERENCES pschedule_track	-- track the event is in. NULL is for events spanning tracks.
,	start		INTEGER NOT NULL				-- start of the event as offset in minutes from midnight
,	length		INTEGER NOT NULL				-- length of the event in minutes - length==0 is allowed.
,	group		INTEGER		 REFERENCES pschedule_item	-- Optional parent item - Must have matching day, track, schedule.
,	label		TEXT						-- label for placeholder.     NULL implies fixed event.
,	description	TEXT						-- event description.         NULL implies placeholder.
,	speakerdesc	TEXT						-- event speaker description.
	-- Notes and constraints.
	--
	-- * length 0 is allowed - Marker items
	-- * A non-NULL "label" marks a placeholder item.
	--   - "description" and "speakerdesc" will be ignored, and should be NULL.
	-- * A fixed event is indicated by ("label" is NULL).
	--   - "description" must not be NULL.
	--   - "speakerdesc" can be NULL even so.
	-- * An item in a group must have the same schedule|day|track information as the group.
	-- * The item in a group must not have gaps between them.
	-- * A group's start must match the lowest start of the items in the group.
	-- * A group's length must match the sum of the lengths of the items in the group.
	-- * A group item cannot be nested into another group.
	-- * items in the same track must not overlap, except for groupings.
	--   - items without group must not overlap each other.
	--   - items within a group must not overlap each other.
	--   - items within a group must overlap with their group.
	-- * For the purposes of item overlap checking items with ("track" IS NULL) belong to _all_ tracks.
	-- * Some of the constraints about overlapping can be captured in a unique constraint:
,	UNIQUE (pschedule, day, track, start, length, group)
	-- And the placeholder labels must be unique within their physical schedule as well.
,	UNIQUE (pschedule, label)
);
-- ---------------------------------------------------------------
CREATE TABLE schedule (
	-- Logical schedule for a conference. Actually just items.
	-- The physical schedule is stored in table "conference".
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT	-- item identifier
	conference	INTEGER NOT NULL REFERENCES conference		-- conference, implies physical schedule.
,	label		TEXT	NOT NULL				-- placeholder label the slot refers to.
	--	----------------------------------------------------------
,	talk		INTEGER		 REFERENCES talk		--     talk for the slot, providing (speaker)description.
,	tutorial	INTEGER		 REFERENCES tutorial_schedule	-- XOR tutorial for the slot.
,	session		TEXT						-- XOR title for sessions (groups).
	--	----------------------------------------------------------
,	UNIQUE (conference, label)
	-- constraint: conference == talk->submission->conference
	-- constraint: conference == tutorial->conference
	-- constraint: Cannot have more than one of "talk", "tutorial", "session" as not null. At least two must be null.
	-- constraint: Must have items for all placeholders in the physical schedule.
	-- constraint: Must have items for all tutorials in the con's tutorial_schedule.
);
