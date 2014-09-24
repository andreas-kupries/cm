-- Database schema for conference mgmt

CREATE TABLE city (	-- we have been outside US in past
	cid		INTEGER PRIMARY KEY AUTOINCREMENT,
	name		TEXT,
	state		TEXT,
	nation		TEXT,
	UNIQUE (name, state, nation)
);
CREATE TABLE hotel (
	-- normally the location too.
	-- not really needed to model separation, except in the transport info block
	hid		INTEGER PRIMARY KEY AUTOINCREMENT,
	cid		INTEGER REFERENCES city,
	name		TEXT,
	streetaddress	TEXT	UNIQUE,
	zipcode		TEXT,
	book-fax	TEXT	NULLABLE,	-- defaults to the local-*
	book-link	TEXT	NULLABLE,
	book-phone	TEXT	NULLABLE,
	local-fax	TEXT	UNIQUE,
	local-link	TEXT	UNIQUE,
	local-phone	TEXT	UNIQUE,
	transportation	TEXT,			-- html block (maps, descriptions, etc)
);
CREATE TABLE rate (				-- rates change from year to year
	hid		INTEGER	REFERENCES hotel,
	cid		INTEGER	REFERENCES conference,
	rate		INTEGER,		-- per night, pennies, i.e. stored x100.
	groupcode	TEXT,
	begindate	INTEGER,		-- date [epoch]
	enddate		INTEGER,		-- date [epoch]
	UNIQUE (hid, cid)
);
CREATE TABLE person (
	pid		INTEGER PRIMARY KEY AUTOINCREMENT,
	tag		TEXT	UNIQUE,		-- for html anchors
	familyname	TEXT,
	firstname	TEXT,
	biography	TEXT,
	affiliation	TEXT,
	cfpreceiver	INTEGER,		-- mark CFP receivers
	nocfptemp	INTEGER			-- mark temp CFP deactivation
);
CREATE TABLE mailinglist (	-- CFP destinations
	mid		INTEGER PRIMARY KEY AUTOINCREMENT,
	title		TEXT	UNIQUE,
	email		TEXT	UNIQUE,
	link		TEXT	UNIQUE,
	cfpreceiver	INTEGER,		-- flag
	nocfptemp	INTEGER			-- flag
);
CREATE TABLE email (
	mid		INTEGER PRIMARY KEY AUTOINCREMENT,
	pid		INTEGER	REFERENCES person,
	email		TEXT	UNIQUE,
	inactive	INTEGER			-- mark outdated addresses
);
CREATE TABLE link (
	lid		INTEGER PRIMARY KEY AUTOINCREMENT,
	pid 		INTEGER	REFERENCES person,
	link		TEXT,
	title		TEXT,
	UNIQUE (pid, link)
);
CREATE TABLE tutorial (
	tid		INTEGER PRIMARY KEY AUTOINCREMENT,
	speaker		INTEGER	REFERENCES person,
	tag		TEXT,			-- for html anchors
	title		TEXT,
	prereq		TEXT,
	description	TEXT,
	UNIQUE (speaker, tag),
	UNIQUE (speaker, title)
);
CREATE TABLE conference (
	cid		INTEGER PRIMARY KEY AUTOINCREMENT,
	title		TEXT	UNIQUE,
	year		INTEGER,
	hid		INTEGER	REFERENCES hotel,
	startdate	INTEGER,		-- [*], date [epoch]
	enddate		INTEGER,		--	date [epoch]
	chair		INTEGER	REFERENCES person,
	fchair		INTEGER	REFERENCES person,
	pchair		INTEGER	REFERENCES person,	-- responsible for transport info
	talklength	INTEGER,			-- minutes	 -- here we can configure
	sessionlen	INTEGER				-- in #talks max -- basic scheduling.
					 				 -- shorter talks => longer sessions.
					 				 -- standard: 30 min x3
	-- [Ad *] from this we can compute a basic timeline
	--	for deadlines and actions (cfp's, submission
	--	deadline, material deadline, etc)
	--	Should possibly save it in a table, and allow
	--	for conversion into ical and other calender formats.
	--
	-->	Google Calendar of the Conference, Mgmt + Public
);
CREATE TABLE tutorial (_selection
	cid	INTEGER	REFERENCES conference
	tid	INTEGER	REFERENCES tutorial
	day	-- 1,2,... (offset to start of conference, 1-based)
	hid	INTEGER	REFERENCES half
	track	-- 1,2,...
);
CREATE TABLE half (	-- fixed content
	hid	-- 1,2,3
	text	-- morning,afternoon,evening
);
CREATE TABLE submission (
	sid
	cid	INTEGER	REFERENCES conference
	abstract
	summary
	invited	-- keynotes are a special submission made by mgmt
);
CREATE TABLE submitter (
	sid	INTEGER	REFERENCES submission
	pid	INTEGER	REFERENCES person
	note	-- distinguish author, co-author, if wanted
);
CREATE TABLE pcommittee (
	cid	INTEGER	REFERENCES conference
	pid	INTEGER	REFERENCES person
);
CREATE TABLE talk (
	tid
	cid	INTEGER	REFERENCES conference
	tpid	INTEGER	REFERENCES talktype
	stid	reference talkstate
	sid	INTEGER	REFERENCES submission	nullable
	isremote -- hangout, skype, other ?
);
CREATE TABLE talker (
	tid	INTEGER	REFERENCES talk
	pid	INTEGER	REFERENCES person

	-- We allow multiple speakers => panel, co-presentation
	-- Note: Presenter is not necessarily any of the submitters
);
CREATE TABLE talktype (	-- fixed contents
	tid	-- invited, submitted, keynote, panel
	text
);
CREATE TABLE talkstate ( -- fixed contents
	tid	-- material pending, received
	text
);
CREATE TABLE schedule (
	cid	INTEGER	REFERENCES conference
	day			-- 3,4,... (offset to start of conference, 1-based)
	sid			-- session within day
	ssid	nullable	-- slot within session, null => whole session talk (keynotes)
	tid	INTEGER	REFERENCES talk
);
CREATE TABLE registered ( (== attendees)
	cid	INTEGER	REFERENCES conference
	pid	INTEGER	REFERENCES person	-- !isgroup
	walkin				-- late-register fee
	tid1	INTEGER	REFERENCES tutorial	-- tutorial selection
	tid2	INTEGER	REFERENCES tutorial	-- all nullable
	tid3	INTEGER	REFERENCES tutorial
	tid4	INTEGER	REFERENCES tutorial
	talk	INTEGER	REFERENCES talk nullable -- presenter discount
);
CREATE TABLE booked (	-- hotel bookings
	cid	INTEGER	REFERENCES conference
	pid	INTEGER	REFERENCES person
);
CREATE TABLE notes (
	cid	INTEGER	REFERENCES conference
	pid	INTEGER	REFERENCES person	nullable
	text
	-- general notes, and attached to people
	-- ex: we know that P will not use the con hotel
);
-- speaker state is derivable from the contents of
--	talk, registered, booked, plus notes

-- should possibly also store (templated) text blocks, i.e. for web
-- site, cfp mail, various author mails (instructions, ping for booking,
-- ping for register, etc)
