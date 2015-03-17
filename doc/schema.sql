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
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	speaker		INTEGER	REFERENCES contact,	-- can_register||can_book||can_talk
	tag		TEXT,				-- for html anchors
	title		TEXT,
	prereq		TEXT,
	description	TEXT,
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
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	con		INTEGER	REFERENCES conference,
	day		INTEGER,			-- 0,1,... (offset from start of conference, 0-based)
	half		INTEGER	REFERENCES dayhalf,
	track		INTEGER,			-- 1,2,...
	tutorial	INTEGER REFERENCES tutorial,	-- While setting up the con
	UNIQUE (con, tutorial),
	UNIQUE (con, day, half, track)
);
-- ---------------------------------------------------------------
CREATE TABLE dayhalf (	-- fixed content
	id		INTEGER	PRIMARY KEY,	-- 1,2,3
	text		TEXT	UNIQUE		-- morning,afternoon,evening
);
INSERT OR IGNORE INTO dayhalf VALUES (1,'morning');
INSERT OR IGNORE INTO dayhalf VALUES (2,'afternoon');
INSERT OR IGNORE INTO dayhalf VALUES (3,'evening');
-- ---------------------------------------------------------------
CREATE TABLE submission (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	con		INTEGER	REFERENCES conference,
	abstract	TEXT,
	summary		TEXT,
	invited		INTEGER				-- keynotes are a special submission made by mgmt
);
-- ---------------------------------------------------------------
CREATE TABLE submitter (
	submission	INTEGER	REFERENCES submission,	-- can_register||can_book||can_talk||can_submit
	contact		INTEGER	REFERENCES contact,
	note		TEXT,				-- distinguish author, co-author, if wanted
	UNIQUE (submission, contact)
);
-- ---------------------------------------------------------------
CREATE TABLE talk (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	con		INTEGER	REFERENCES conference,
	type		INTEGER	REFERENCES talk_type,
	state		INTEGER REFERENCES talk_state,
	submission	INTEGER	REFERENCES submission,
	isremote	INTEGER,			 -- hangout, skype, other ? => TEXT?
	UNIQUE (con, submission)
	-- constraint: con == submission->con
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
	con		INTEGER	REFERENCES conference,
	day		INTEGER,			-- 2,3,4,... (offset from start of conference, 0-based)
	session		INTEGER,			-- session within the day
	slot		INTEGER,			-- slot within the session, null => whole session talk (keynotes)
	talk		INTEGER REFERENCES talk,	-- While setting things up
	UNIQUE (con, day, session, slot)
	-- constraint: con == talk->con (== talk->submission->con)
);
-- ---------------------------------------------------------------
CREATE TABLE register ( -- conference registrations <=> attendee register
	con		INTEGER	REFERENCES conference,
	contact		INTEGER	REFERENCES contact,		-- can_register
	walkin		INTEGER,				-- late-register fee
	tut1		INTEGER REFERENCES tutorial_schedule,	-- tutorial selection
	tut2		INTEGER REFERENCES tutorial_schedule,	-- all nullable
	tut3		INTEGER REFERENCES tutorial_schedule,
	tut4		INTEGER REFERENCES tutorial_schedule,
	talk		INTEGER REFERENCES talk,		-- presenter discount
	UNIQUE (con, contact)
	--	constraint: con == tutX->con, if tutX NOT NULL, X in 1-4
);
-- ---------------------------------------------------------------
CREATE TABLE booked (	-- hotel bookings
	con		INTEGER	REFERENCES conference,
	contact		INTEGER	REFERENCES contact,	-- can_book
	hotel		INTEGER	REFERENCES location,	-- may not be the conference hotel!
	UNIQUE (con, pcontact)
);
-- ---------------------------------------------------------------
CREATE TABLE notes (
	con		INTEGER	REFERENCES conference,
	contact		INTEGER REFERENCES contact,
	text		TEXT
	-- general notes, and attached to people
	-- ex: we know that P will not use the con hotel
);

-- ---------------------------------------------------------------
-- speaker state is derivable from the contents of
--	talk, registered, booked, plus notes
--
-- should possibly also store (templated) text blocks, i.e. for web
-- site, cfp mail, various author mails (instructions, ping for booking,
-- ping for register, etc)
