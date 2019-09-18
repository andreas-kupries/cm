## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::schedule 0
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
package require dbutil
package require try
package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export schedule
    namespace ensemble create
}
namespace eval ::cm::db::schedule {
    namespace export \
	setup add_empty add_talk add_tutorial add_fixed \
	set_talk set_tutorial set_fixed \
	drop of known
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/schedule
debug prefix cm/db/schedule {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::schedule::add_empty {conference label} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	INSERT
	INTO   schedule
	VALUES ( NULL
	       , :conference
	       , :label
	       , NULL
	       , NULL
	       , NULL)
    }
    return
}

proc ::cm::db::schedule::add_talk {conference label talk} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	INSERT
	INTO   schedule
	VALUES ( NULL
	       , :conference
	       , :label
	       , :talk
	       , NULL
	       , NULL)
    }
    return
}

proc ::cm::db::schedule::add_tutorial {conference label tutorial} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	INSERT
	INTO   schedule
	VALUES ( NULL
	       , :conference
	       , :label
	       , NULL
	       , :tutorial
	       , NULL)
    }
    return
}

proc ::cm::db::schedule::add_fixed {conference label fixed} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	INSERT
	INTO   schedule
	VALUES ( NULL
	       , :conference
	       , :label
	       , NULL
	       , NULL
	       , :fixed)
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::schedule::set_talk {slot talk} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	UPDATE schedule
	SET   talk     = :talk
	,     tutorial = NULL
	,     session  = NULL
	WHERE id = :slot
    }
    return
}

proc ::cm::db::schedule::set_tutorial {slot tutorial} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	UPDATE schedule
	SET   talk     = NULL
	,     tutorial = :tutorial
	,     session  = NULL
	WHERE id = :slot
    }
    return
}

proc ::cm::db::schedule::set_fixed {slot fixed} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	UPDATE schedule
	SET   talk     = NULL
	,     tutorial = NULL
	,     session  = :fixed
	WHERE id = :slot
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::schedule::drop {conference} {
    debug.cm/db/schedule {}
    setup

    db do eval {
	DELETE
	FROM  schedule
	WHERE conference = :conference
    }
    return
}

proc ::cm::db::schedule::of {conference {links 0}} {
    debug.cm/db/schedule {}
    setup
    # -- TODO: tutorial setup
    # -- TODO: conference/talk/submission setup

    set r {}
    db do eval {
	SELECT label, talk, tutorial, session
	FROM   schedule
	WHERE  conference = :conference
	ORDER BY label
    } {
	debug.cm/db/schedule {$label => Ta|$talk| Tu|$tutorial| S|$session|}

	set speaker {}
	# Explicit left outer joins -> talk              -> submission
	#                           -> tutorial_schedule -> tutorial
	if {$talk ne {}} {
	    set s [::cm::conference::talk-tagged-speakers $talk]
	    if {$links} {
		set speaker [join [::cm::conference::link-speakers $s] {, }]
	    } else {
		set speaker [join [p1 $s] {, }]
	    }
	    
	    set title [db do onecolumn {
		SELECT title
		FROM   submission
		WHERE  id IN (SELECT submission
			      FROM   talk
			      WHERE  id = :talk)
	    }]

	    if {$links} {
		set talk [::cm::conference::link $title abstracts.html T$talk]
	    } else {
		set talk $title
	    }
	}
	if {$tutorial ne {}} {
	    set s [::cm::conference::tutorial-speakers $tutorial]
	    if {$links} {
		set speaker [join [::cm::conference::link-speakers $s] {, }]
	    } else {
		set speaker [join [p1 $s] {, }]
	    }

	    set title [db do onecolumn {
		SELECT title
		FROM   tutorial
		WHERE  id IN (SELECT tutorial
			      FROM   tutorial_schedule
			      WHERE  id = :tutorial)
	    }]

	    if {$links} {
		lassign [db do eval {
		    SELECT C.tag, T.tag
		    FROM   tutorial          T
		    ,      contact           C
		    ,      tutorial_schedule S
		    WHERE  S.id = :tutorial
		    AND    T.id = S.tutorial
		    AND    C.id = T.speaker
		}] stag tag
		set tag $stag:$tag
		set tutorial [::cm::conference::link $title tutorials.html $tag]
	    } else {
		set tutorial $title
	    }
	}
	lappend r $label $talk $tutorial $session $speaker
    }
    return $r
}

proc ::cm::db::schedule::p1 {speakers} {
    debug.cm/db/schedule {}
    set r {}
    foreach {dname tag} $speakers {
	lappend r $dname
    }
    return $r
}

proc ::cm::db::schedule::known {conference} {
    debug.cm/db/schedule {}
    setup
    # -- TODO: tutorial setup
    # -- TODO: conference/talk/submission setup

    return [db do eval {
	SELECT label, id
	FROM   schedule
	WHERE  conference = :conference
	ORDER BY label
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::schedule::setup {} {
    debug.cm/db/schedule {}

    # schedule - Linkage conference </> pschedule

    # TODO !! Change label into a 'pschedule_item' reference, placeholder, same phys schedule as the conference.

    if {![dbutil initialize-schema ::cm::db::do error schedule {
	{
	    -- Logical schedule linking a physical schedule with the
	    -- talks and tutorials of a conference. Actually simply
	    -- the set of logical items filling in the placeholders
	    -- of the physical schedule of the conference.

	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
	    ,   conference	INTEGER NOT NULL REFERENCES conference	-- owning conference, implies physical schedule.
	    ,	label		TEXT	NOT NULL			-- placeholder label the slot refers to.
	    --	----------------------------------------------------------
	    ,	talk		INTEGER		 REFERENCES talk		--     talk for the slot, providing (speaker)description.
	    ,	tutorial	INTEGER		 REFERENCES tutorial_schedule	-- XOR tutorial for the slot.
	    ,	session		TEXT						-- XOR fixed title for sessions.
	    --	----------------------------------------------------------
	    ,	UNIQUE (conference, label)
	    -- constraint: conference == talk->submission->conference
	    -- constraint: conference == tutorial->conference
	    -- constraint: Cannot have more than one of "talk", "tutorial", "session" as not-null.
	    --             Exactly two must be null. Exactly one must be not-null.
	    -- constraint: Must have items for all placeholders in the physical schedule.
	    -- constraint: Must have items for all tutorials in the con's tutorial_schedule.
	} {
	    {id           INTEGER 1 {} 1}
	    {conference   INTEGER 1 {} 0}
	    {label        TEXT    1 {} 0}
	    {talk         INTEGER 0 {} 0}
	    {tutorial     INTEGER 0 {} 0}
	    {session      TEXT    0 {} 0}
	} {}
    }]} {
	db setup-error schedule $error
    }

    # Shortcircuit further calls
    proc ::cm::db::schedule::setup {args} {}
    return
}

proc ::cm::db::schedule::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/schedule {}

    # TODO: call from conference

    error nyi/schedule
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::schedule 0
return
