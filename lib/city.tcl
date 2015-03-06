## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::city 0
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
#package require cm::util
package require cm::db
#package require cm::validate::city

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export city
    namespace ensemble create
}
namespace eval ::cm::city {
    namespace export cmd_create cmd_list \
	select label get
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    #namespace import ::cm::util
    namespace import ::cm::db

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/city
debug prefix cm/city {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::city::cmd_list {config} {
    debug.cm/city {}
    Setup
    db show-location

    [table t {Name State Nation} {
	db do eval {
	    SELECT name, state, nation
	    FROM city
	    ORDER BY name, state, nation
	} {
	    $t add $name $state $nation
	}
    }] show
    return
}

proc ::cm::city::cmd_create {config} {
    debug.cm/city {}
    Setup
    db show-location

    # try to insert, report failure as user error

    set name   [$config @name]
    set state  [$config @state]
    set nation [$config @nation]
    set label  [label $name $state $nation]

    puts -nonewline "Creating city \"[color note $label]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO city
		VALUES (NULL, :name, :state, :nation)
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

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::city::get {id} {
    debug.cm/city {}
    Setup

    lassign [db do eval {
	SELECT name, state, nation
	FROM  city
	WHERE id = :id
    }] name state nation

    return [label $name $state $nation]
}

proc ::cm::city::label {name state nation} {
    debug.cm/city {}

    set label $name
    if {$state ne {}} {append label "/$state"}
    append label "-$nation"
    return $label
}

proc ::cm::city::known {p} {
    debug.cm/city {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, name, state, nation
	FROM city
    } {
	dict set known [label $name $state $nation] $id
    }

    return $known
}

proc ::cm::city::select {p} {
    debug.cm/city {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set cities  [known $p]
    set choices [lsort -dict [dict keys $cities]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note
	    return [lindex $cities 1]
	}
    }

    set choice [ask menu "" "Which city: " $choices]

    # Map back to id
    return [dict get $cities $choice]
}

proc ::cm::city::Setup {} {
    debug.cm/city {}

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
	db setup-error $error CITY
    }

    # Shortcircuit further calls
    proc ::cm::city::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::city 0
return
