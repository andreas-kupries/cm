-- Database schema for conference mgmt

CREATE TABLE city (	-- we have been outside US in past
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	name		TEXT,
	state		TEXT,
	nation		TEXT,
	UNIQUE (name, state, nation)
);
CREATE TABLE hotel (
	-- normally the location too.
	-- not really needed to model separation, except in the transport info block
	id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	name		TEXT    NOT NULL,
	city		INTEGER NOT NULL REFERENCES city,
	streetaddress	TEXT    NOT NULL,
	zipcode		TEXT    NOT NULL,
	book_fax	TEXT	NULLABLE,	-- defaults to the local-*
	book_link	TEXT	NULLABLE,
	book_phone	TEXT	NULLABLE,
	local_fax	TEXT	UNIQUE,
	local_link	TEXT	UNIQUE,
	local_phone	TEXT	UNIQUE,
	transportation	TEXT,			-- html block (maps, descriptions, etc)
	UNIQUE (city, streetaddress)
);
CREATE TABLE hotel_staff (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	hotel		INTEGER REFERENCES hotel,
	position	TEXT,
	familyname	TEXT,
	firstname	TEXT,
	email		TEXT,
	phone		TEXT,
	UNIQUE (hotel, position, familyname, firstname) -- Same person may have multiple positions
);
CREATE TABLE rate (				-- rates change from year to year
	conference	INTEGER	REFERENCES conference,
	hotel		INTEGER	REFERENCES hotel,
	rate		INTEGER,		-- per night, pennies, i.e. stored x100.
	groupcode	TEXT,
	begindate	INTEGER,		-- date [epoch]
	enddate		INTEGER,		-- date [epoch]
	UNIQUE (con, hotel)
);
CREATE TABLE person (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	tag		TEXT	UNIQUE,		-- for html anchors
	familyname	TEXT,
	firstname	TEXT,
	biography	TEXT,
	affiliation	TEXT,
	cfpreceiver	INTEGER,		-- mark CFP receivers
	nocfptemp	INTEGER			-- mark temp CFP deactivation
);
CREATE TABLE mailinglist (	-- CFP destinations
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	title		TEXT	UNIQUE,
	email		TEXT	UNIQUE,
	link		TEXT	UNIQUE,
	cfpreceiver	INTEGER,		-- flag
	nocfptemp	INTEGER			-- flag
);
CREATE TABLE email (
	id		INTEGER	PRIMARY KEY AUTOINCREMENT,
	person		INTEGER	REFERENCES person,
	email		TEXT	UNIQUE,
	inactive	INTEGER,		-- mark outdated addresses
	UNIQUE (person, email)
);
CREATE TABLE link (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	person 		INTEGER	REFERENCES person,
	link		TEXT,
	title		TEXT,
	UNIQUE (person, link)
);
CREATE TABLE tutorial (
	id		INTEGER PRIMARY KEY AUTOINCREMENT,
	speaker		INTEGER	REFERENCES person,
	tag		TEXT,			-- for html anchors
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
	hotel		INTEGER	NULLABLE REFERENCES hotel	-- We will not immediately know where we will be
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
	person		INTEGER	REFERENCES person,
	role		INTEGER	REFERENCES staff_role,
	UNIQUE (con, person, role)
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
	tutorial	INTEGER	NULLABLE REFERENCES tutorial,	-- While setting up the con
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
	submission	INTEGER	REFERENCES submission,
	person		INTEGER	REFERENCES person,
	note		TEXT,				-- distinguish author, co-author, if wanted
	UNIQUE (submission, person)
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
	person		INTEGER	REFERENCES person,
	UNIQUE (talk, person)
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
	day		INTEGER,				-- 2,3,4,... (offset from start of conference, 0-based)
	session		INTEGER,				-- session within the day
	slot		INTEGER	NULLABLE,			-- slot within the session, null => whole session talk (keynotes)
	talk		INTEGER	NULLABLE REFERENCES talk,	-- While setting things up
	UNIQUE (con, day, session, slot)
	-- constraint: con == talk->con (== talk->submission->con)
);
CREATE TABLE register ( -- conference registrations <=> attendee register
	con		INTEGER	REFERENCES conference,
	person		INTEGER	REFERENCES person,
	walkin		INTEGER,						-- late-register fee
	tut1		INTEGER	NULLABLE REFERENCES tutorial_schedule,	-- tutorial selection
	tut2		INTEGER	NULLABLE REFERENCES tutorial_schedule,	-- all nullable
	tut3		INTEGER	NULLABLE REFERENCES tutorial_schedule,
	tut4		INTEGER	NULLABLE REFERENCES tutorial_schedule,
	talk		INTEGER	NULLABLE REFERENCES talk,		-- presenter discount
	UNIQUE (con, person)
	--	constraint: con == tutX->con, if tutX NOT NULL, X in 1-4
);
CREATE TABLE booked (	-- hotel bookings
	con		INTEGER	REFERENCES conference,
	person		INTEGER	REFERENCES person,
	UNIQUE (con, person)
);
CREATE TABLE notes (
	con		INTEGER	REFERENCES conference,
	person		INTEGER	NULLABLE REFERENCES person,
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
