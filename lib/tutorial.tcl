## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::tutorial 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta tutorial    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require cmdr::color
package require cmdr::ask
package require cmdr::table
package require debug
package require debug::caller
package require dbutil
package require try

package provide cm::tutorial 0 ;# circular through contact, campaign, conference

package require cm::contact
package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export tutorial
    namespace ensemble create
}
namespace eval ::cm::tutorial {
    namespace export \
	cmd_create cmd_list cmd_show cmd_settitle cmd_setdesc cmd_setreq \
	cmd_settag known known-tag known-title get details select \
	known-half get-half have-some dayrange trackrange \
	cell speakers scheduled
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::contact
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/tutorial
debug prefix cm/tutorial {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::tutorial::cmd_list {config} {
    debug.cm/tutorial {}
    Setup
    db show-location

    [table t {Speaker Tag Note Title} {
	db do eval {
	    SELECT C.dname     AS speaker,
	           C.tag       AS stag,
	           C.biography AS sbio,
	           T.tag       AS tag,
	           T.title     AS title
	    FROM   tutorial T,
	           contact  C
	    WHERE  C.id = T.speaker
	    ORDER BY C.dname, T.title
	} {
	    set notes {}
	    if {$stag eq {}} { lappend notes [color bad {No speaker tag}] }
	    if {$sbio eq {}} { lappend notes [color bad {No speaker biography}] }

	    $t add $speaker @${stag}:$tag [join $notes \n] $title
	}
    }] show
    return
}

proc ::cm::tutorial::cmd_create {config} {
    debug.cm/tutorial {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set prereq      [$config @requisites]
    set speaker     [$config @speaker]
    set tag         [$config @tag]
    set title       [$config @title]

    if {![$config @description set?]} {
	set description [read stdin]
    } else {
	set description [$config @description]
    }

    puts -nonewline "Creating \"[color name [cm::contact get $speaker]]\" tutorial \"[color name $title]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO tutorial
		VALUES (NULL, :speaker, :tag, :title, :prereq, :description)
	    }
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

proc ::cm::tutorial::cmd_show {config} {
    debug.cm/tutorial {}
    Setup
    db show-location

    set tutorial [$config @name]
    set details  [details $tutorial]

    dict with details {}

    set w [util tspace [expr {[string length Description]+7}] 60]
    set xspeaker [contact get $xspeaker]

    puts "Details of [color name $xspeaker]'s tutorial \"[color name [get $tutorial]]\":"
    [table t {Property Value} {
	set issues [issues $details]
	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
	    $t add -------- -----
	}

	$t add Speaker      [color name $xspeaker]
	$t add Tag          $xtag
	$t add Title        $xtitle
	$t add Requisites   [util adjust $w $xprereq]
	$t add Description  [util adjust $w $xdescription]
    }] show
    return
}

proc ::cm::tutorial::cmd_settitle {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set tutorial [$config @tutorial] 
    set text     [$config @text]

    puts -nonewline "Set title of \"[color name [get $tutorial]]\" ... "
    flush stdout

    db do eval {
	UPDATE tutorial
	SET    title = :text
	WHERE  id    = :tutorial
    }

    puts [color good OK]
    return
}

proc ::cm::tutorial::cmd_setdesc {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set tutorial [$config @tutorial] 

    if {![$config @text set?]} {
	set text [read stdin]
    } else {
	set text [$config @text]
    }

    puts -nonewline "Set description of \"[color name [get $tutorial]]\" ... "
    flush stdout

    db do eval {
	UPDATE tutorial
	SET    description = :text
	WHERE  id          = :tutorial
    }

    puts [color good OK]
    return
}

proc ::cm::tutorial::cmd_setreq {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set tutorial [$config @tutorial] 
    set text     [$config @text]

    puts -nonewline "Set requisites of \"[color name [get $tutorial]]\" ... "
    flush stdout

    db do eval {
	UPDATE tutorial
	SET    prereq = :text
	WHERE  id     = :tutorial
    }

    puts [color good OK]
    return
}

proc ::cm::tutorial::cmd_settag {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set tutorial [$config @tutorial] 
    set text     [$config @text]

    puts -nonewline "Set tag of \"[color name [get $tutorial]]\" ... "
    flush stdout

    db do eval {
	UPDATE tutorial
	SET    tag = :text
	WHERE  id  = :tutorial
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::tutorial::issues {details} {
    debug.cm/tutorial {}
    dict with details {}

    set sdetails [contact details $xspeaker]

    set issues {}
    if {[dict get $sdetails xtag]       eq {}} { +issue "Speaker tag missing" }
    if {[dict get $sdetails xbiography] eq {}} { +issue "Speaker biography missing" }

    if {[llength $issues]} {
	set issues [join $issues \n]
    }
    return $issues
}

proc ::cm::tutorial::+issue {text} {
    debug.cm/tutorial {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

proc ::cm::tutorial::select {p} {
    debug.cm/tutorial {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set tutorials [known-select]
    set choices   [lsort -dict [dict keys $tutorials]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $tutorials 1]
	}
    }

    set choice [ask menu "" "Which tutorial: " $choices]

    # Map back to id
    return [dict get $tutorials $choice]
}

proc ::cm::tutorial::known-select {} {
    debug.cm/contact {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	    SELECT T.id    AS id,
	           C.dname AS speaker,
	           C.tag   AS stag,
	           T.tag   AS tag,
	           T.title AS title
	    FROM   tutorial T,
	           contact  C
	    WHERE  C.id = T.speaker
    } {
	set key "(@${stag}:$tag) $speaker: $title"
	dict set known $key $id
    }

    return $known

}

proc ::cm::tutorial::known-tag {speaker} {
    debug.cm/tutorial {}
    Setup

    set known {}

    db do eval {
	SELECT id, tag
	FROM   tutorial
	WHERE  speaker = :speaker
    } {
	dict set known $tag $id
    }

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::known-title {speaker} {
    debug.cm/tutorial {}
    Setup

    set known {}

    db do eval {
	SELECT id, title
	FROM   tutorial
	WHERE  speaker = :speaker
    } {
	dict set known $title $id
    }

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::known {} {
    debug.cm/tutorial {}
    Setup

    # For validation.
    # See also contact.tcl for similar (helper) code.

    set map {}
    # dict: id -> labels. Will be inverted later.

    db do eval {
	SELECT T.id    AS id,
	       C.dname AS speaker,
	       C.tag   AS stag,
	       T.tag   AS tag, 
	       T.title AS title
	FROM  tutorial T,
	      contact  C
	WHERE C.id = T.speaker
    } {
	dict lappend map $id @${stag}:$tag
	dict lappend map $id "${speaker}/$title"
    }

    # Rekey by names
    set map [util dict-invert       $map]
    #set map [util dict-fill-permute $map] - Not good for the speaker/title cominbation
    set known [util dict-drop-ambiguous $map]

    debug.cm/tutorial {==> ($known)}
    return $known
}


proc ::cm::tutorial::scheduled {conference} {
    debug.cm/tutorial {}
    Setup

    # For validation - Tutorials assigned to a specific conference
    # See also contact.tcl for similar (helper) code.

    set map {}
    # dict: (id,day,half,tutorial) -> labels. Will be inverted later.

    db do eval {
	SELECT S.id    AS id
	,      T.id    AS tutorial
	,      C.dname AS speaker
	,      C.tag   AS stag
	,      T.tag   AS tag
	,      T.title AS title
	,      S.day   AS day
	,      S.half  AS half
	FROM  tutorial          T
	,     contact           C
	,     tutorial_schedule S
	WHERE C.id         = T.speaker
	AND   S.tutorial   = T.id
	AND   S.conference = :conference
    } {
	lappend id $day $half $tutorial

	dict lappend map $id @${stag}:$tag
	dict lappend map $id "${speaker}/$title"
    }

    # Rekey by names
    set map [util dict-invert       $map]
    #set map [util dict-fill-permute $map] - Not good for the speaker/title cominbation
    set known [util dict-drop-ambiguous $map]

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::get {id} {
    debug.cm/tutorial {}
    Setup

    return [db do onecolumn {
	SELECT title
	FROM   tutorial
	WHERE  id = :id
    }]
}

proc ::cm::tutorial::details {id} {
    debug.cm/tutorial {}
    Setup

    set details [db do eval {
	SELECT 'xspeaker',     speaker,
               'xtag',         tag,
	       'xtitle',       title,
	       'xprereq',      prereq,
	       'xdescription', description
	FROM   tutorial
	WHERE  id = :id
    }]

    return $details
}

proc ::cm::tutorial::write {id details} {
    debug.cm/tutorial {}
    Setup

    dict with details {}

    db do eval {
	UPDATE tutorial
	SET    speaker     = :xspeaker,
	       tag         = :xtag,
	       title       = :xtitle,
	       prereq      = :xprereq,
	       description = :xdescription
	WHERE id = :id
    }
}

proc ::cm::tutorial::known-half {} {
    debug.cm/tutorial {}
    Setup

    set known {}

    db do eval {
	SELECT id, text
	FROM   dayhalf
    } {
	dict set known $text $id
    }

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::get-half {id} {
    debug.cm/tutorial {}
    Setup

    return [db do eval {
	SELECT text
	FROM   dayhalf
	WHERE  id = :id
    }]
}

proc ::cm::tutorial::have-some {conference} {
    debug.cm/tutorial {}
    Setup

    return [db do exists {
	SELECT id
	FROM   tutorial_schedule
	WHERE  conference = :conference
    }]
}

proc ::cm::tutorial::dayrange {conference} {
    debug.cm/tutorial {}
    Setup

    lassign [db do eval {
	SELECT MIN(day), MAX (day)
	FROM   tutorial_schedule
	WHERE  conference = :conference
    }] daymin daymax

    if {$daymin eq {}} { set daymin  0 }
    if {$daymax eq {}} { set daymax -1 } else { incr daymax }

    set  daylast $daymax
    incr daylast -1

    return [list $daymin $daymax $daylast]
}

proc ::cm::tutorial::trackrange {conference} {
    debug.cm/tutorial {}
    Setup

    # Track range (across all days)
    lassign [db do eval {
	SELECT MIN(track), MAX (track)
	FROM   tutorial_schedule
	WHERE  conference = :conference
    }] trackmin trackmax

    if {$trackmin eq {}} { set trackmin  0 }
    if {$trackmax eq {}} { set trackmax -1 } else { incr trackmax }

    set  tracklast $trackmax
    incr tracklast -1

    return [list $trackmin $trackmax $tracklast]
}

proc ::cm::tutorial::cell {conference day half track} {
    debug.cm/tutorial {}
    Setup

    # Get data from the exactly addressed cell in the schedule.
    return [db do eval {
	SELECT tutorial
	FROM   tutorial_schedule
	WHERE  conference = :conference
	AND    day        = :day
	AND    half       = :half
	AND    track      = :track
    }]
}

proc ::cm::tutorial::speakers {conference} {
    debug.cm/tutorial {}
    Setup

    # Get data from the exactly addressed cell in the schedule.
    return [db do eval {
	SELECT dname, tag, biography
	FROM contact
	WHERE id IN (SELECT DISTINCT T.speaker
		     FROM  tutorial_schedule S,
		           tutorial          T
		     WHERE S.conference = :conference
		     AND   S.tutorial   = T.id)
	ORDER BY dname
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::tutorial::Setup {} {
    debug.cm/tutorial {}

    ::cm::contact::Setup

    if {![dbutil initialize-schema ::cm::db::do error tutorial {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    speaker	INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk
	    tag		TEXT	NOT NULL,			-- for html anchors
	    title	TEXT	NOT NULL,
	    prereq	TEXT,
	    description	TEXT	NOT NULL,
	    UNIQUE (speaker, tag),
	    UNIQUE (speaker, title)
	} {
	    {id			INTEGER 1 {} 1}
	    {speaker		INTEGER 1 {} 0}
	    {tag		TEXT    1 {} 0}
	    {title		TEXT    1 {} 0}
	    {prereq		TEXT    0 {} 0}
	    {description	TEXT	1 {} 0}
	} {}
    }]} {
	db setup-error tutorial $error
    }

    if {![dbutil initialize-schema ::cm::db::do error tutorial_schedule {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER	NOT NULL REFERENCES conference,
	    day		INTEGER	NOT NULL,			-- 0,1,... (offset from start of conference, 0-based)
	    half	INTEGER	NOT NULL REFERENCES dayhalf,
	    track	INTEGER	NOT NULL,			-- 1,2,... (future expansion)
	    tutorial	INTEGER	NOT NULL REFERENCES tutorial,
	    UNIQUE (conference, day, half, track),
	    UNIQUE (conference, tutorial)
	} {
	    {id			INTEGER 1 {} 1}
	    {conference		INTEGER 1 {} 0}
	    {day		INTEGER 1 {} 0}
	    {half		INTEGER 1 {} 0}
	    {track		INTEGER 1 {} 0}
	    {tutorial		INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error tutorial_schedule $error
    }

    if {![dbutil initialize-schema ::cm::db::do error dayhalf {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error dayhalf $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO dayhalf VALUES (1,'morning');
	    INSERT OR IGNORE INTO dayhalf VALUES (2,'afternoon');
	    INSERT OR IGNORE INTO dayhalf VALUES (3,'evening');
	}
    }

    # Shortcircuit further calls
    proc ::cm::tutorial::Setup {args} {}
    return
}

proc ::cm::tutorial::Dump {} {
    debug.cm/tutorial {}

    db do eval {
	SELECT T.id          AS id,
	       C.dname       AS nspeaker,
	       T.tag         AS tag,
	       T.title       AS title,
	       T.prereq      AS req,
	       T.description AS desc
	FROM   tutorial T,
	       contact  C
	WHERE  C.id = T.speaker
	ORDER BY nspeaker, title
    } {
	cm dump save \
	    tutorial add $nspeaker $tag $title \
	    < [cm dump write tutorial$id $desc]

	if {$req ne {}} {
	    cm dump save \
		tutorial set-prereq $req
	}

	cm dump step
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::tutorial 0
return
