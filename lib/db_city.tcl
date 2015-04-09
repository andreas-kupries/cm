## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::city 0
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
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export city
    namespace ensemble create
}
namespace eval ::cm::db::city {
    namespace export new delete all 2name select label known \
	setup dump
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/city
debug prefix cm/db/city {[debug caller] | }

# # ## ### ##### ######## ############# ######################
##

proc ::cm::db::city::new {name state nation} {
    debug.cm/db/city {}
    setup

    db do transaction {
	db do eval {
	    INSERT INTO city
	    VALUES (NULL, :name, :state, :nation)
	}
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::city::delete {city} {
    debug.cm/db/city {}
    setup

    db do eval {
	DELETE
	FROM   city
	WHERE  id = :city
    }
    return
}

proc ::cm::db::city::all {} {
    debug.cm/db/city {}
    setup

    return [db do eval {
	SELECT id, name, state, nation
	FROM   city
	ORDER BY name, state, nation
    }]
}

proc ::cm::db::city::2name {city} {
    debug.cm/db/city {}
    setup

    lassign [db do eval {
	SELECT name, state, nation
	FROM   city
	WHERE  id = :city
    }] name state nation

    return [label $name $state $nation]
}

proc ::cm::db::city::label {name state nation} {
    debug.cm/db/city {}

    set label $name
    if {$state ne {}} {append label ", $state"}
    append label ", $nation"
    return $label
}

proc ::cm::db::city::known {} {
    debug.cm/db/city {}
    set map {}
    setup

    db do eval {
	SELECT id, name, state, nation
	FROM   city
    } {
	set display [label $name $state $nation]

	if {$state ne {}} {
	    set label "$name $state $nation"
	} else {
	    set label "$name $nation"
	}
	set label    [string tolower $label]
	set initials [util initials  $label]
	set display  [string tolower $display]

	dict lappend map $id $display $label "$initials $label"
    }

    set map [util dict-invert         $map]
    set map [util dict-fill-permute   $map]
    set map [util dict-drop-ambiguous $map]

    debug.cm/db/city {==> ($map)}
    return $map
}

proc ::cm::db::city::select {p} {
    debug.cm/db/city {}
    return [util select $p city Selection]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::city::Selection {} {
    debug.cm/db/city {}
    Setup

    # dict: label -> id
    set selection {}

    db do eval {
	SELECT id, name, state, nation
	FROM   city
    } {
	dict set selection [label $name $state $nation] $id
    }

    return $selection
}

proc ::cm::db::city::setup {} {
    debug.cm/db/city {}

    if {![dbutil initialize-schema ::cm::db::do error city {
	{
	    -- Base data for hotels, resorts, and other locations:
	    -- The city they are in.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name	TEXT    NOT NULL,
	    state	TEXT,
	    nation	TEXT    NOT NULL,
	    UNIQUE (name, state, nation)
	} {
	    {id     INTEGER 1 {} 1}
	    {name   TEXT    1 {} 0}
	    {state  TEXT    0 {} 0}
	    {nation TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error city $error
    }

    # Shortcircuit further calls
    proc ::cm::db::city::setup {args} {}
    return
}

proc ::cm::db::city::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/city {}

    foreach {id name state nation} [all] {
	cm dump save \
	    city create $name $state $nation
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::city 0
return
