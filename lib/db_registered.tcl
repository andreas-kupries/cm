## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::registered 0
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
    namespace export registered
    namespace ensemble create
}
namespace eval ::cm::db::registered {
    namespace export listing add remove pupil-of setup dump
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/registered
debug prefix cm/db/registered {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::registered::pupil-of {registration slot tutorial} {
    debug.cm/db/registered {}
    setup

    # tutorial => tutorial_schedule.id -- check conference vs registration conference.

    lappend map @@@ tut$slot

    if {($tutorial eq {}) || ($tutorial < 0)} {
	debug.cm/db/registered {NULL, ($map)}
	db do eval [string map $map {
	    UPDATE registered
	    SET    @@@ = NULL
	    WHERE  id  = :registration
	}]
    } else {
	set tc [db do onecolumn {
	    SELECT conference
	    FROM   tutorial_schedule
	    WHERE id = :tutorial
	}]
	set rc [db do onecolumn {
	    SELECT conference
	    FROM   registered
	    WHERE id = :registration
	}]

	debug.cm/db/registered {T [format %4d $tutorial] => C $tc}
	debug.cm/db/registered {R [format %4d $registration] => C $rc}

	if {$tc != $rc} {
	    return -code error "Conference mismatch for chosen tutorial"
	}

	debug.cm/db/registered {set ($map)}
	db do eval [string map $map {
	    UPDATE registered
	    SET    @@@ = :tutorial
	    WHERE  id  = :registration
	}]
    }
    return
}

# MOVE this to the tutorial db layer FUTURE TODO
proc ::cm::db::registered::get-t-title {id} {
    debug.cm/db/registered {}
    setup

    if {$id eq {}} { return {} }
    if {$id < 0} { return {} }
    return [db do onecolumn {
	SELECT T.title AS title
	FROM tutorial_schedule TS
	,    tutorial          T
	WHERE TS.id       = :id
	AND   TS.tutorial = T.id
    }]
}

proc ::cm::db::registered::listing {conference} {
    debug.cm/db/registered {}
    setup

    set r {}
    db do eval {
	SELECT C.dname   AS dname
	,      R.walkin  AS walkin
	,      R.tech    AS tech
	,      R.tut1    AS ta_id
	,      R.tut2    AS tb_id
	,      R.tut3    AS tc_id
	,      R.tut4    AS td_id
	FROM registered R
	,    contact    C
	WHERE R.conference = :conference
	AND   R.contact    = C.id
	ORDER BY dname
    } {
	# Explicit left outer join... __HACK__
	set ta [get-t-title $ta_id]
	set tb [get-t-title $tb_id]
	set tc [get-t-title $tc_id]
	set td [get-t-title $td_id]
	lappend r $dname $walkin $tech $ta $tb $tc $td
    }
    return $r

    # Should be done with left outer join.
    # Unclear on the syntax for the multiple LOJ.
    # Doing it explicitly, see above. __HACK__
    return [db do eval {
	SELECT C.dname   AS dname
	,      R.walkin  AS walkin
	,      R.tech    AS tech
	,      TA.title  AS ta_title
	,      TB.title  AS tb_title
	,      TC.title  AS tc_title
	,      TD.title  AS td_title
	FROM registered        R
	,    contact           C
	,    tutorial_schedule TSA
	,    tutorial_schedule TSB
	,    tutorial_schedule TSC
	,    tutorial_schedule TSD
	,    tutorial          TA
	,    tutorial          TB
	,    tutorial          TC
	,    tutorial          TD
	WHERE R.conference = :conference
	AND   R.contact    = C.id
	AND   R.tut1       = TSA.id
	AND   R.tut2       = TSB.id
	AND   R.tut3       = TSC.id
	AND   R.tut4       = TSD.id
	AND   TSA.tutorial = TA.id
	AND   TSB.tutorial = TB.id
	AND   TSC.tutorial = TC.id
	AND   TSD.tutorial = TD.id
	ORDER BY dname
    }]
}

proc ::cm::db::registered::add {conference contact walkin tech} {
    debug.cm/db/registered {}
    setup

    db do eval {
	INSERT
	INTO registered
	VALUES (NULL
	,	:conference
	,	:contact
	,	:walkin
	,	:tech
	,	NULL, NULL, NULL, NULL -- tutorials 1..4
	)
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::registered::remove {conference contact} {
    debug.cm/db/registered {}
    setup

    db do eval {
	DELETE
	FROM registered
	WHERE conference = :conference
	AND   contact    = :contact
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::registered::setup {} {
    debug.cm/db/registered {}

    # TODO: registered - setup conference
    # TODO: registered - setup contact
    # TODO: registered - setup tutorial_schedule

    if {![dbutil initialize-schema ::cm::db::do error registered {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER NOT NULL REFERENCES conference,
	    contact	INTEGER	NOT NULL REFERENCES contact,	-- can_register (person)
	    walkin	INTEGER NOT NULL,			-- late-register fee
	    tech	INTEGER NOT NULL,			-- flag for tech session attendance
	    tut1	INTEGER REFERENCES tutorial_schedule,	-- tutorial selection
	    tut2	INTEGER REFERENCES tutorial_schedule,	-- all nullable
	    tut3	INTEGER REFERENCES tutorial_schedule,
	    tut4	INTEGER REFERENCES tutorial_schedule,
	    UNIQUE (conference, contact)
	    --	constraint: conference == tutX->conference, if tutX NOT NULL, X in 1-4
	} {
	    {id         INTEGER 1 {} 1}
	    {conference INTEGER 1 {} 0}
	    {contact    INTEGER 1 {} 0}
	    {walkin     INTEGER 1 {} 0}
	    {tech       INTEGER 1 {} 0}
	    {tut1       INTEGER 0 {} 0}
	    {tut2       INTEGER 0 {} 0}
	    {tut3       INTEGER 0 {} 0}
	    {tut4       INTEGER 0 {} 0}
	} {}
    }]} {
	db setup-error registered $error
    }

    # Shortcircuit further calls
    proc ::cm::db::registered::setup {args} {}
    return
}

proc ::cm::db::registered::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/registered {}
    setup

    # TODO future - call from conference dump /arg: conference.
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::registered 0
return
