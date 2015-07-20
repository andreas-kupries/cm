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
package require dbutil
package require debug
package require debug::caller
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
    namespace export new delete all 2name get select label known \
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

    # Actual key, list for syntax, lower-case normalized for
    # case-insensitive uniqueness.
    lappend csnkey [string tolower $name]
    lappend csnkey [string tolower $state]
    lappend csnkey [string tolower $nation]

    db do transaction {
	db do eval {
	    INSERT INTO city
	    VALUES (NULL,	-- id, automatic
		    :name,	-- name
		    :state,	-- state
		    :nation,	-- nation
		    :csnkey)	-- csnkey
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

proc ::cm::db::city::get {city} {
    debug.cm/db/city {}
    setup

    return [db do eval {
	SELECT name, state, nation
	FROM   city
	WHERE  id = :city
    }]
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
    setup

    set map {}
    db do eval {
	SELECT id, csnkey
	FROM   city
    } {
	# csnkey : list (name, state, nation)
	#        : state may be the empty string.
	#        : all lower-case normalized

	if {[lindex $csnkey 1] == {}} {
	    set csnkey [lreplace $csnkey 1 1]
	}

	dict set map $csnkey $id
    }

    # Permute the key lists, keep those which are still unique.
    set map [util dict-fill-permute   $map]
    set map [util dict-drop-ambiguous $map]
    set map [util dict-join-keys      $map {, }]

    # Rewrite the keys, join elements into a plain string (*),
    # separator is comma.
    # (*) User should not have to write Tcl list syntax!

    debug.cm/db/city {==> ($map)}
    return $map
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::city::select {p} {
    debug.cm/db/city {}
    return [util select $p city Selection]
}

proc ::cm::db::city::Selection {} {
    debug.cm/db/city {}
    setup

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

# # ## ### ##### ######## ############# ######################

cm db setup cm::db::city {
    debug.cm/db/city {}

    if {![dbutil initialize-schema ::cm::db::do error city {
	{
	    -- Base data for hotels, resorts, and other locations:
	    -- The city they are in.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name	TEXT    NOT NULL,
	    state	TEXT,
	    nation	TEXT    NOT NULL,
	    csnkey	TEXT    NOT NULL,	-- actual key, lower-case
	    UNIQUE (name, state, nation),
	    UNIQUE (csnkey)
	} {
	    {id     INTEGER 1 {} 1}
	    {name   TEXT    1 {} 0}
	    {state  TEXT    0 {} 0}
	    {nation TEXT    1 {} 0}
	    {csnkey TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error city $error
    }
    return
}

proc ::cm::db::city::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/city {}

    foreach {_ name state nation} [all] {
	cm dump save \
	    city new $name $state $nation
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::city 0
return
