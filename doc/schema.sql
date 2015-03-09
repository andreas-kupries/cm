-- Database schema for conference mgmt

CREATE TABLE city (	-- we have been outside US in past
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	name		TEXT,
	state		TEXT,
	nation		TEXT,
	UNIQUE (name, state, nation)
);
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
CREATE TABLE location_staff (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	location	INTEGER REFERENCES location,
	position	TEXT,
	familyname	TEXT,
	firstname	TEXT,
	email		TEXT,
	phone		TEXT,
	UNIQUE (location, position, familyname, firstname) -- Same person may have multiple positions
);
CREATE TABLE rate (				-- rates change from year to year
	conference	INTEGER	REFERENCES conference,
	location	INTEGER	REFERENCES location,
	rate		INTEGER,		-- per night, pennies, i.e. stored x100.
	groupcode	TEXT,
	begindate	INTEGER,		-- date [epoch]
	enddate		INTEGER,		-- date [epoch]
	UNIQUE (con, location)
);
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
	affiliation	INTEGER REFERENCES contact,	-- company, if any; not for lists nor companies

	can_recvmail	INTEGER NOT NULL,	-- valid recipient of conference mail (call for papers)
	can_register	INTEGER NOT NULL,	-- actual person can register for attendance
	can_book	INTEGER NOT NULL,	-- actual person can book hotels
	can_talk	INTEGER NOT NULL,	-- actual person can do presentation
	can_submit	INTEGER NOT NULL,	-- actual person, or company can submit talks

	-- Note: Deactivation of contact in a campaign is handled by the contact/campaign linkage
);
-- INDEX on type
CREATE TABLE contact_type (
    	id	INTEGER NOT NULL PRIMARY KEY,
    	text	TEXT    NOT NULL UNIQUE
);
INSERT OR IGNORE INTO contact_type VALUES (1,'Person');
INSERT OR IGNORE INTO contact_type VALUES (2,'Company');
INSERT OR IGNORE INTO contact_type VALUES (3,'Mailinglist');
CREATE TABLE email (
	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	email		TEXT	NOT NULL UNIQUE,
	contact		INTEGER	NOT NULL REFERENCES contact,
	inactive	INTEGER	NOT NULL 	-- mark outdated addresses
);
-- INDEX on contact
CREATE TABLE link (
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	contact		INTEGER	NOT NULL REFERENCES contact,
	link		TEXT	NOT NULL, -- same link text can be used by multiple contacts
	title		TEXT,
	UNIQUE (contact, link)
);
-- INDEX on contact
-- INDEX on link

CREATE TABLE campaign (
	-- Email campaign for a conference.

	id	INTEGER NOT NULL 	PRIMARY KEY AUTOINCREMENT,
	con	INTEGER NOT NULL UNIQUE	REFERENCES conference,	-- one campaign per conference only
	active	INTEGER NOT NULL				-- flag
);
CREATE TABLE campaign_destination (
	-- Destination addresses for the campaign

	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	campaign	INTEGER	NOT NULL REFERENCES campaign,
	email		INTEGER NOT NULL REFERENCES email,	-- contact is indirect
	UNIQUE (campaign,email)
);
CREATE TABLE campaign_mailrun (
	-- Mailings executed so far

	id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	campaign	INTEGER	NOT NULL REFERENCES campaign,
	template	INTEGER NOT NULL REFERENCES template,	-- mail text template
	date		INTEGER NOT NULL			-- timestamp [epoch]
);
-- INDEX on campaign
-- INDEX on template

CREATE TABLE campaign_received (
	-- The addresses which received mailings. In case of a repeat mailing
	-- for a template this information is used to prevent sending mail to
	-- destinations which already got it.

	id	INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	mailrun	INTEGER	NOT NULL REFERENCES campaign_mailrun/,
	email	INTEGER	NOT NULL REFERENCES email	-- under contact
);
-- INDEX on mailrun

CREATE TABLE template (
	-- Text templates for mail campaigns

	id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	name	TEXT    NOT NULL UNIQUE,
	value	TEXT	NOT NULL
);
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
CREATE TABLE conference (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	title		TEXT	UNIQUE,
	year		INTEGER,
	city		INTEGER	REFERENCES city,
	startdate	INTEGER,		-- [*], date [epoch]
	enddate		INTEGER,		--	date [epoch]
	talklength	INTEGER,			-- minutes	  here we configure
	sessionlen	INTEGER,			-- in #talks max  basic scheduling parameters.
					 		-- 		  shorter talks => longer sessions.
					 		-- 		  standard: 30 min x3
	hotel		INTEGER REFERENCES location	-- We will not immediately know where we will be
	sessions	INTEGER REFERENCES location	-- While sessions are usually at the hotel, they may not be.
	--	constraint: city == hotel->city, if hotel NOT NULL

	-- [Ad *] from this we can compute a basic timeline
	--	for deadlines and actions (cfp's, submission
	--	deadline, material deadline, etc)
	--	Should possibly save it in a table, and allow
	--	for conversion into ical and other calender formats.
	--
	-->	Google Calendar of the Conference, Mgmt + Public
);
CREATE TABLE conference_staff (
	con		INTEGER	REFERENCES conference,
	contact		INTEGER	REFERENCES contact,	-- can_register||can_book||can_talk
	role		INTEGER	REFERENCES staff_role,
	UNIQUE (con, contact, role)
	-- Multiple people can have the same role (ex: program commitee)
	-- One person can have multiple roles (ex: prg.chair, prg. committee)
);
CREATE TABLE staff_role (	-- semi-fixed content
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	text		TEXT	UNIQUE	-- chair, facilities chair, program chair, program committee,
					-- web admin, proceedings editor, hotel liason, ...
);
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
CREATE TABLE dayhalf (	-- fixed content
	id		INTEGER	PRIMARY KEY,	-- 1,2,3
	text		TEXT	UNIQUE		-- morning,afternoon,evening
);
CREATE TABLE submission (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	con		INTEGER	REFERENCES conference,
	abstract	TEXT,
	summary		TEXT,
	invited		INTEGER				-- keynotes are a special submission made by mgmt
);
CREATE TABLE submitter (
	submission	INTEGER	REFERENCES submission,	-- can_register||can_book||can_talk||can_submit
	contact		INTEGER	REFERENCES contact,
	note		TEXT,				-- distinguish author, co-author, if wanted
	UNIQUE (submission, contact)
);
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
CREATE TABLE talker (
	talk		INTEGER	REFERENCES talk,
	contact		INTEGER	REFERENCES contact,	-- can_talk
	UNIQUE (talk, contact)
	-- We allow multiple speakers => panels, co-presentation
	-- Note: Presenter is not necessarily any of the submitters of the submission behind the talk
);
CREATE TABLE talk_type (	-- fixed contents
	id		INTEGER PRIMARY KEY AUTOINCREMENT,	-- invited, submitted, keynote, panel
	text		TEXT	UNIQUE
);
CREATE TABLE talk_state (	-- fixed contents
	id		INTEGER PRIMARY KEY AUTOINCREMENT,	-- material pending, received
	text		TEXT	UNIQUE
);
CREATE TABLE schedule (
	con		INTEGER	REFERENCES conference,
	day		INTEGER,			-- 2,3,4,... (offset from start of conference, 0-based)
	session		INTEGER,			-- session within the day
	slot		INTEGER,			-- slot within the session, null => whole session talk (keynotes)
	talk		INTEGER REFERENCES talk,	-- While setting things up
	UNIQUE (con, day, session, slot)
	-- constraint: con == talk->con (== talk->submission->con)
);
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
CREATE TABLE booked (	-- hotel bookings
	con		INTEGER	REFERENCES conference,
	contact		INTEGER	REFERENCES contact,	-- can_book
	hotel		INTEGER	REFERENCES location,	-- may not be the conference hotel!
	UNIQUE (con, pcontact)
);
CREATE TABLE notes (
	con		INTEGER	REFERENCES conference,
	contact		INTEGER REFERENCES contact,
	text		TEXT
	-- general notes, and attached to people
	-- ex: we know that P will not use the con hotel
);

-- speaker state is derivable from the contents of
--	talk, registered, booked, plus notes
--
-- should possibly also store (templated) text blocks, i.e. for web
-- site, cfp mail, various author mails (instructions, ping for booking,
-- ping for register, etc)
