## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::tutorial 0
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
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::db::dayhalf
package require cm::contact
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export tutorial
    namespace ensemble create
}
namespace eval ::cm::db::tutorial {
    namespace export \
	all new title= desc= req= tag= 2name get update select \
	known known-tag known-title dayrange trackrange cell speakers \
	scheduled schedule unschedule \
	issues setup dump
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::db::dayhalf
    namespace import ::cm::contact
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/tutorial
debug prefix cm/db/tutorial {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::tutorial::all {config} {
    debug.cm/db/tutorial {}
    setup

    return [db do eval {
	SELECT C.dname     AS speaker,
	       C.tag       AS stag,
	       C.biography AS sbio,
	       T.tag       AS tag,
	       T.title     AS title
	FROM   tutorial T,
	       contact  C
	WHERE  C.id = T.speaker
	ORDER BY C.dname, T.title
    }]
}

proc ::cm::db::tutorial::new {speaker tag title prereq description} {
    debug.cm/db/tutorial {}
    setup

    db do transaction {
	db do eval {
	    INSERT INTO tutorial
	    VALUES (NULL, :speaker, :tag, :title, :prereq, :description)
	}
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::tutorial::title= {tutorial text} {
    debug.cm/db/tutorial {}
    setup

    db do eval {
	UPDATE tutorial
	SET    title = :text
	WHERE  id    = :tutorial
    }
    return
}

proc ::cm::db::tutorial::desc= {tutorial text} {
    debug.cm/db/tutorial {}
    setup

    db do eval {
	UPDATE tutorial
	SET    description = :text
	WHERE  id          = :tutorial
    }
    return
}

proc ::cm::db::tutorial::req= {tutorial text} {
    debug.cm/db/tutorial {}
    setup

    db do eval {
	UPDATE tutorial
	SET    prereq = :text
	WHERE  id     = :tutorial
    }
    return
}

proc ::cm::db::tutorial::tag= {tutorial text} {
    debug.cm/db/tutorial {}
    setup

    db do eval {
	UPDATE tutorial
	SET    tag = :text
	WHERE  id  = :tutorial
    }
    return
}

proc ::cm::db::tutorial::issues {details} {
    debug.cm/db/tutorial {}

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

proc ::cm::db::tutorial::+issue {text} {
    debug.cm/db/tutorial {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

proc ::cm::db::tutorial::select {p} {
    debug.cm/db/tutorial {}
    return [util select $p tutorial Selection]
}

proc ::cm::db::tutorial::Selection {} {
    debug.cm/db/tutorial {}
    setup

    # dict: label -> id
    set selection {}

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
	dict set selection $key $id
    }

    return $selection

}

proc ::cm::db::tutorial::known-tag {speaker} {
    debug.cm/db/tutorial {}
    setup

    set known {}

    db do eval {
	SELECT id, tag
	FROM   tutorial
	WHERE  speaker = :speaker
    } {
	dict set known $tag $id
    }

    debug.cm/db/tutorial {==> ($known)}
    return $known
}

proc ::cm::db::tutorial::known-title {speaker} {
    debug.cm/db/tutorial {}
    setup

    set known {}

    db do eval {
	SELECT id, title
	FROM   tutorial
	WHERE  speaker = :speaker
    } {
	dict set known $title $id
    }

    debug.cm/db/tutorial {==> ($known)}
    return $known
}

proc ::cm::db::tutorial::known {} {
    debug.cm/db/tutorial {}
    setup

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
    #set map [util dict-fill-permute $map] - Not good for the speaker/title combination
    set known [util dict-drop-ambiguous $map]

    debug.cm/db/tutorial {==> ($known)}
    return $known
}

proc ::cm::db::tutorial::2name {tutorial} {
    debug.cm/db/tutorial {}
    setup

    return [db do onecolumn {
	SELECT title
	FROM   tutorial
	WHERE  id = :tutorial
    }]
}

proc ::cm::db::tutorial::get {tutorial} {
    debug.cm/db/tutorial {}
    setup

    return [db do eval {
	SELECT 'xspeaker',     speaker,
               'xtag',         tag,
	       'xtitle',       title,
	       'xprereq',      prereq,
	       'xdescription', description
	FROM   tutorial
	WHERE  id = :tutorial
    }]
}

proc ::cm::db::tutorial::update {tutorial details} {
    debug.cm/db/tutorial {}
    setup

    dict with details {}

    db do eval {
	UPDATE tutorial
	SET    speaker     = :xspeaker,
	       tag         = :xtag,
	       title       = :xtitle,
	       prereq      = :xprereq,
	       description = :xdescription
	WHERE  id          = :tutorial
    }
}

proc ::cm::db::tutorial::dayrange {conference} {
    debug.cm/db/tutorial {}
    setup

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

proc ::cm::db::tutorial::trackrange {conference} {
    debug.cm/db/tutorial {}
    setup

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

proc ::cm::db::tutorial::cell {conference day half track} {
    debug.cm/db/tutorial {}
    setup

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

proc ::cm::db::tutorial::speakers* {conference} {
    debug.cm/db/tutorial {}
    setup

    # Get data from the exactly addressed cell in the schedule.
    return [db do eval {
	SELECT dname, tag, biography
	FROM   contact
	WHERE  id IN (SELECT DISTINCT T.speaker
		      FROM  tutorial_schedule S,
		            tutorial          T
		      WHERE S.conference = :conference
		      AND   S.tutorial   = T.id)
    }]
}

proc ::cm::db::tutorial::speakers {conference} {
    debug.cm/db/tutorial {}
    setup

    return [db do eval {
	SELECT DISTINCT T.speaker
	FROM  tutorial_schedule S,
	      tutorial          T
	WHERE S.conference = :conference
	AND   S.tutorial   = T.id)
    }]
}

proc ::cm::db::tutorial::scheduled {conference} {
    debug.cm/db/tutorial {}
    setup

    return [db do onecolumn {
	SELECT count(id)
	FROM   tutorial_schedule
	WHERE  conference = :conference
    }]
}

proc ::cm::db::tutorial::schedule {conference tutorial day half track} {
    debug.cm/db/tutorial {}
    setup

    # convert external 1-based offset into the internal 0-based offset
    # used to store the information
    incr day -1

    db do eval {
	INSERT INTO tutorial_schedule
	VALUES (NULL,
		:conference,
		:day,
		:half,
		:track,
		:tutorial)
    }
    return
}

proc ::cm::db::tutorial::unschedule {conference tutorial} {
    debug.cm/db/tutorial {}
    setup

    db do eval {
	DELETE
	FROM  tutorial_schedule
	WHERE conference = :conference
	AND   tutorial   = :tutorial
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::tutorial::setup {} {
    debug.cm/db/tutorial {}

    dayhalf setup
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

    # Shortcircuit further calls
    proc ::cm::db::tutorial::setup {args} {}
    return
}

proc ::cm::db::tutorial::dump {} {
    debug.cm/db/tutorial {}

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
package provide cm::db::tutorial 0
return
