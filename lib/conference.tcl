## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::conference 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require cmdr::color
package require cmdr::ask
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::table
package require cm::city
package require cm::config::core
package require cm::db
package require cm::util
package require cm::hotel
package require cmdr::validate::date
package require cmdr::validate::weekday

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export conference
    namespace ensemble create
}
namespace eval ::cm::conference {
    namespace export \
	cmd_create cmd_list cmd_select cmd_show cmd_center \
	cmd_hotel cmd_timeline_init cmd_timeline_clear \
	select label current get insert
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cmdr::validate::date
    namespace import ::cmdr::validate::weekday
    namespace import ::cm::city
    namespace import ::cm::db
    namespace import ::cm::hotel
    namespace import ::cm::util

    namespace import ::cm::config::core
    rename core config

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/conference
debug prefix cm/conference {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_list {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set cid [config get* @current-conference {}]

    [table t {{} Name Start End City} {
	db do eval {
	    SELECT C.id                    AS id,
                   C.title                 AS title,
	           C.startdate             AS start,
	           c.enddate               AS end,
	           CC.name                 AS city,
	           CC.state                AS state,
	           CC.nation               AS nation
	    FROM      conference C
            LEFT JOIN city      CC
	    ON        CC.id = C.city
	    ORDER BY C.title
	} {
	    set start [date 2external $start]
	    set end   [date 2external $end]

	    set city    [city label $city $state $nation]
	    set issues  [issues [details $id]]
	    if {$issues ne {}} {
		append title \n $issues
	    }

	    util highlight-current cid $id current title start end city
	    $t add $current $title $start $end $city
	}
    }] show
    return
}

proc ::cm::conference::cmd_create {config} {
    debug.cm/conference {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set title  [$config @title]
    set year   [$config @year]
    set align  [$config @alignment]
    set start  [$config @start]
    set length [$config @length]

    puts -nonewline "Creating conference \"[color name $title]\" ... "

    # move start-date into alignment
    if {$align > 0} {
	while {[clock format $start -format %u] != $align} {
	    set start [clock add $start -1 days]
	}
    }

    # check year-of start-date vs year
    if {[clock format $start -format %Y] != $year} {
	util user-error "Start date does not match conference year" YEAR MISMATCH
    }

    # calculate end-date
    set end [clock add $start $length days]

    # defaults for talk-length and session-length - see sql below
    try {
	db do transaction {
	    db do eval {
		INSERT INTO conference
		VALUES (NULL, :title, :year, NULL, NULL, NULL,
			:start, :end, :align, :length, 30, 3)
		-- 30 minutes per talk, at 3 talks per session - defaults
	    }
	}
	set id [db do last_insert_rowid]
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    timeline-init $id

    puts [color good OK]

    puts -nonewline "Setting as current conference ... "
    config assign @current-conference $id
    puts [color good OK]

    puts [color warning {Please remember to set the location information}]
    return
}

proc ::cm::conference::cmd_select {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id [$config @conference]

    puts -nonewline "Setting current conference to \"[color name [get $id]]\" ... "
    config assign @current-conference $id
    puts [color good OK]
    return
}

proc ::cm::conference::cmd_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]

    puts "Details of \"[color name [get $id]]\":"
    [table t {Property Value} {
	set issues [issues $details]
	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
	    $t add -------- -----
	}

	dict with details {}

	set xstart [hdate $xstart]
	set xend   [hdate $xend]

	if {$xalign > 0} {
	    set xalign [weekday 2external $xalign]
	} else {
	    set xalign <<none>>
	}

	if {$xcity     ne {}} { set xcity     [city  get $xcity] }
	if {$xhotel    ne {}} { set xhotel    [hotel get $xhotel] }
	if {$xsessions ne {}} { set xsessions [hotel get $xsessions] }

	$t add Year          $xyear
	$t add Start         $xstart
	$t add End           $xend
	$t add Aligned       $xalign
	$t add Days          $xlength
	$t add In            $xcity
	$t add @Hotel        $xhotel
	$t add @Center       $xsessions
	$t add Minutes/Talk  $xtalklen
	$t add Talks/Session $xsesslen

	# Show the timeline...
	db do eval {
	    SELECT T.date AS date,
	           E.text AS text
	    FROM   timeline      T,
	           timeline_type E
	    WHERE T.con  = :id
	    AND   T.type = E.id
	    ORDER BY T.date
	} {
	    $t add "- $text" [hdate $date]
	}
    }] show
    return
}

proc ::cm::conference::cmd_center {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]
    dict with details {}

    set hotel   [$config @hotel]
    set hlabel  [hotel get $hotel]
    set city    [dict get [hotel details $hotel] xcity]
    set clabel  [city get $city]

    puts "Conference \"[color name [get $id]]\":"
    puts "- Set C.Center as \"[color name $hlabel]\""
    puts "- Set city     as \"[color name $clabel]\""

    dict set details xsessions $hotel
    dict set details xcity $city

    if {$xhotel eq {}} {
	puts "- Set hotel    as the same"
	dict set details xhotel $hotel
    }

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

proc ::cm::conference::cmd_hotel {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]
    dict with details {}

    set hotel   [$config @hotel]
    set hlabel  [hotel get $hotel]
    set city    [dict get [hotel details $hotel] xcity]
    set clabel  [city get $city]

    puts "Conference \"[color name [get $id]]\":"
    puts "- Set hotel    as \"[color name $hlabel]\""

    dict set details xhotel $hotel

    if {$xsessions eq {}} {
	puts "- Set C.Center as the same"
	puts "- Set city     as \"[color name $clabel]\""

	dict set details xsessions $hotel
	dict set details xcity $city
    }

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

proc ::cm::conference::cmd_timeline_init {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id [current]

    puts "Conference \"[color name [get $id]]\", initialize timeline ... "
    flush stdout

    timeline-init $id

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_timeline_clear {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id [current]

    puts "Conference \"[color name [get $id]]\", clear timeline ... "
    flush stdout

    timeline-clear $id

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::conference::timeline-clear {conference} {
    debug.cm/conference {}
    Setup
    # clear the timeline ...

    db do eval {
	DELETE
	FROM  timeline
	WHERE con = :conference
    }
    return
}

proc ::cm::conference::timeline-init {conference} {
    debug.cm/conference {}
    Setup
    # Compute an initial timeline based on the conference start date.

    set details [details $conference]
    dict with details {}

    puts "Proposed timeline ..."
    [table t {Item Date} {
	db do eval {
	    SELECT id, offset, text, ispublic
	    FROM timeline_type
	    ORDER BY offset
	} {
	    set new [clock add $xstart $offset days]

	    if {$ispublic} {
		$t add [color note $text] [color note [hdate $new]]
	    } else {
		$t add $text [hdate $new]
	    }
	    db do eval {
		INSERT INTO timeline
		VALUES (NULL, :conference, :new, :id)
	    }
	}
    }] show
    return
}

proc ::cm::conference::insert {id text} {
    debug.cm/conference {}
    Setup

    set details [details $id]
    dict with details {}
    set xtitle [get $id]

    set clabel [city get $xcity]

    set hotel  [hotel details $xhotel]
    dict with hotel {} ;# overwrites conference city
    set hclabel [city get $xcity]

    #array set _ $details ; parray _ ; unset _
    #array set _ $hotel ; parray _ ; unset _

    # Needs:
    # - conference information
    #   - year
    #   - title
    #   - start-date
    #   - end-end
    #   - timeline
    #   - location-references
    #     - location info (phone, fax, link)
    #   - sponsors
    #   - comittee
    #
    # --> insertion into template

    lappend map @h:hotel@      $xname
    lappend map @h:city@       $hclabel
    lappend map @h:street@     "$xstreet, $xzipcode"
    lappend map @h:transport@  $xtransport

    lappend map @h:bookphone   [ifempty $xbookphone $xlocalphone]
    lappend map @h:bookfax     [ifempty $xbookfax   $xlocalfax]
    lappend map @h:booklink    [ifempty $xbooklink  $xlocallink]

    lappend map @h:localphone  $xlocalphone
    lappend map @h:localfax    $xlocalfax
    lappend map @h:locallink   $xlocallink

    lappend map @c:name@       $xtitle
    lappend map @c:city@       $clabel
    lappend map @c:year@       $xyear
    lappend map @c:start@      [hdate $xstart]
    lappend map @c:end@        [hdate $xend]
    lappend map @c:when@       [when $xstart $xend]
    lappend map @c:contact@    tclconference@googlegroups.com ;# TODO configurable
    lappend map @c:sponsors@   TODO
    lappend map @c:comittee@   TODO
    lappend map @c:talklength@ $xtalklen

    db do eval {
	SELECT E.key  AS key,
	       T.date AS date
	FROM   timeline      T,
	       timeline_type E
	WHERE  T.type = E.id
	AND    E.ispublic
	AND    T.con = :id
    } {
	lappend map @c:t:${key}@ [hdate $date]
    }

    set text [string map $map $text]
    return $text
}

proc ::cm::conference::ifempty {x y} {
    if {$x ne {}} { return $x }
    return $y
}

proc ::cm::conference::hdate {x} {
    clock format $x -format {%B %d, %Y}
}

proc ::cm::conference::hmday {x} {
    clock format $x -format {%B %d}
}

proc ::cm::conference::hmon {x} {
    clock format $x -format %B
}

proc ::cm::conference::when {s e} {
    lassign [clock format $s -format {%Y %m %d}] sy sm sd
    lassign [clock format $e -format {%Y %m %d}] ey em ed

    if {$sy != $ey} {
	# Across years, show full dates
	return "[hdate $s] - [hdate $e]"
    }

    # Same year.
    if {$sm != $em} {
	# Across months
	return "[hmday $s] - [hmday $e], $sy"

    }

    # Same year, same month.
    return "[hmon $s] $sd - $ed, $sy"
}

proc ::cm::conference::known {} {
    debug.cm/conference {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, title
	FROM  conference
    } {
	dict set known $title $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::issues {details} {
    debug.cm/conference {}
    dict with details {}

    set issues {}

    foreach {var message} {
	xcity     "Location is not known"
	xhotel    "Hotel is not known"
	xsessions "C.Center is not known"
	xstart    "Start date is not known"
	xend      "End date is not known"
    } {
	if {[set $var] ne {}} continue
	+issue $message
    }

    if {![db do exists {
	SELECT id
	FROM   timeline
	WHERE con = :xconference
    }]} {
	+issue "Timeline missing"
    }

    if {![llength $issues]} return
    return [join $issues \n]
}

proc ::cm::conference::+issue {text} {
    debug.cm/conference {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

proc ::cm::conference::get {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT title
	FROM  conference
	WHERE id = :id
    }]
}

proc ::cm::conference::details {id} {
    debug.cm/conference {}
    Setup

    return [db do eval {
	SELECT "xconference", id,
	       "xyear",       year,
	       "xcity",       city,
	       "xhotel",      hotel,
	       "xsessions",   sessions,
	       "xstart",      startdate,
	       "xend",        enddate,
	       "xalign",      alignment,
	       "xlength",     length,
	       "xtalklen",    talklength,
	       "xsesslen",    sessionlen
	FROM  conference
	WHERE id = :id
    }]
}

proc ::cm::conference::write {id details} {
    debug.cm/conference {}
    Setup

    dict with details {}
    db do eval {
	UPDATE conference
	SET    year       = :xyear,
	       city       = :xcity,
	       hotel      = :xhotel,
	       sessions   = :xsessions,
	       startdate  = :xstart,
	       enddate    = :xend,
	       alignment  = :xalign,
	       length     = :xlength,
	       talklength = :xtalklen,
	       sessionlen = :xsesslen
	WHERE id = :id
    }
}

proc ::cm::conference::current {} {
    debug.cm/conference {}

    try {
	set id [config get @current-conference]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	puts [color bad "No conference chosen, please \"select\" a conference"]
	::exit 0
    }
    if {[has $id]} { return $id }

    puts [color bad "Bad conference index, please \"select\" a conference"]
    ::exit 0
}

proc ::cm::conference::has {id} {
    debug.cm/conference {}
    Setup

    return [db do exists {
	SELECT title
	FROM   conference
	WHERE  id = :id
    }]
}

proc ::cm::conference::select {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set conferences [known]
    set choices     [lsort -dict [dict keys $conferences]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $conferences 1]
	}
    }

    set choice [ask menu "" "Which conference: " $choices]

    # Map back to id
    return [dict get $conferences $choice]
}

proc ::cm::conference::Setup {} {
    debug.cm/conference {}

    ::cm::config::core::Setup

    if {![dbutil initialize-schema ::cm::db::do error conference {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    title	TEXT	NOT NULL UNIQUE,
	    year	INTEGER NOT NULL,

	    city	INTEGER REFERENCES city,
	    hotel	INTEGER REFERENCES hotel, -- We do not immediately know where we will be
	    sessions	INTEGER REFERENCES hotel, -- While sessions are usually at the hotel, they may not be.

	    startdate	INTEGER,		-- [*], date [epoch]
	    enddate	INTEGER,		--	date [epoch]
	    alignment	INTEGER NOT NULL,	-- iso8601 weekday (1:mon...7:sun), or -1 (no alignment)
	    length	INTEGER NOT NULL,	-- length in days

	    talklength	INTEGER NOT NULL,	-- minutes	  here we configure
	    sessionlen	INTEGER NOT NULL	-- in #talks max  basic scheduling parameters.
						-- 		  shorter talks => longer sessions.
						-- 		  standard: 30 min x3

	    -- Constraints:
	    -- * (city == session->city) WHERE session IS NOT NULL
	    -- * (city == hotel->city)   WHERE session IS NULL AND hotel IS NOT NULL
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
	} {
	    {id			INTEGER 1 {} 1}
	    {title		TEXT    1 {} 0}
	    {year		INTEGER 1 {} 0}
	    {city		INTEGER 0 {} 0}
	    {hotel		INTEGER 0 {} 0}
	    {sessions		INTEGER 0 {} 0}
	    {startdate		INTEGER	0 {} 0}
	    {enddate		INTEGER	0 {} 0}
	    {alignment		INTEGER	1 {} 0}
	    {length		INTEGER	1 {} 0}
	    {talklength		INTEGER	1 {} 0}
	    {sessionlen		INTEGER	1 {} 0}
	} {}
    }]} {
	db setup-error conference $error
    }

    if {![dbutil initialize-schema ::cm::db::do error timeline {
	{
	    -- conference timeline/calendar of action items, deadlines, etc.

	    id	 INTEGER NOT NULL PRIMARY KEY,
	    con	 INTEGER NOT NULL REFERENCES conference,
	    date INTEGER NOT NULL,		-- when this happens [epoch]
	    type INTEGER NOT NULL REFERENCES timeline_type
	} {
	    {id   INTEGER 1 {} 1}
	    {con  INTEGER 1 {} 0}
	    {date INTEGER 1 {} 0}
	    {type INTEGER 1 {} 0}
	} {con}
    }]} {
	db setup-error timeline $error
    }

    if {![dbutil initialize-schema ::cm::db::do error timeline_type {
	{
	    -- The possible types of action items in the conference timeline
	    -- public items are for use within mailings, the website, etc.
	    -- internal items are for the mgmt only.
	    -- the offset [in days] is used to compute the initial proposal
	    -- of a timeline for the conference. 

	    id		INTEGER NOT NULL PRIMARY KEY,
	    ispublic	INTEGER NOT NULL,
	    offset	INTEGER NOT NULL,	-- >0 => days after conference start
	    					-- <0 => days before start
	    key		TEXT    NOT NULL UNIQUE,	-- internal key for the type
	    text	TEXT    NOT NULL UNIQUE		-- human-readable
	} {
	    {id		INTEGER 1 {} 1}
	    {ispublic	INTEGER 1 {} 0}
	    {offset	INTEGER 1 {} 0}
	    {key	TEXT    1 {} 0}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error timeline_type $error
    } else {
	db do eval {
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
	}
    }

    # Shortcircuit further calls
    proc ::cm::conference::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::conference 0
return
