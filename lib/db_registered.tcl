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
package require debug
package require debug::caller
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

proc ::cm::db::registered::tutorial-title {id} {
    debug.cm/db/registered {}

    if {$id eq {}} { return {} }
    if {$id < 0}   { return {} }

    return [tutorial 2name-from-schedule $id]
}

proc ::cm::db::registered::listing {conference} {
    debug.cm/db/registered {}
    setup

    set r {}
    db do eval {
	SELECT C.dname   AS dname
	,      R.walkin  AS walkin
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
	set ta [tutorial-title $ta_id]
	set tb [tutorial-title $tb_id]
	set tc [tutorial-title $tc_id]
	set td [tutorial-title $td_id]
	lappend r $dname $walkin $ta $tb $tc $td
    }
    return $r

    # Should be done with left outer join.
    # Unclear on the syntax for the multiple LOJ.
    # Doing it explicitly, see above. __HACK__
    return [db do eval {
	SELECT C.dname   AS dname
	,      R.walkin  AS walkin
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

proc ::cm::db::registered::add {conference contact walkin} {
    debug.cm/db/registered {}
    setup

    db do eval {
	INSERT
	INTO registered
	VALUES (NULL,
		:conference,
		:contact,
		:walkin,
		NULL, NULL, NULL, NULL) -- tut 1..4
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

cm db setup cm::db::registered {
    debug.cm/db/registered {}

    db use contact
    db use tutorial
    # TODO: registered - setup conference

    if {![dbutil initialize-schema ::cm::db::do error registered {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER NOT NULL REFERENCES conference,
	    contact	INTEGER	NOT NULL REFERENCES contact,		-- can_register (person)
	    walkin	INTEGER NOT NULL,				-- late-register fee
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
	    {tut1       INTEGER 0 {} 0}
	    {tut2       INTEGER 0 {} 0}
	    {tut3       INTEGER 0 {} 0}
	    {tut4       INTEGER 0 {} 0}
	} {}
    }]} {
	db setup-error registered $error
    }
    return
}

proc ::cm::db::registered::dump {conference} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/registered {}
    setup

    set first 1
    db do eval {
	SELECT C.dname  AS contact
	,      R.walkin AS walkin
	,      R.tut1   AS t1
	,      R.tut2   AS t2
	,      R.tut3   AS t3
	,      R.tut4   AS t4
	FROM   registered R
	,      contact    C
	WHERE R.conference = :id
	AND   R.contact    = C.id
	ORDER BY contact
    } {
	if {$first} { cm dump step  ; set first 0 }

	set taken {}
	if {$t1 ne {}} { lappend taken --taking [tutorial 2name-from-schedule $t1] }
	if {$t2 ne {}} { lappend taken --taking [tutorial 2name-from-schedule $t2] }
	if {$t3 ne {}} { lappend taken --taking [tutorial 2name-from-schedule $t3] }
	if {$t4 ne {}} { lappend taken --taking [tutorial 2name-from-schedule $t4] }

	set walkin [expr {$walkin ? "--walkin" : ""}]

	cm dump save \
	    registration add $contact {*}$walkin {*}$taken
    }

    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::registered 0
return
