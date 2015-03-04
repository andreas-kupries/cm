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
package require debug
package require debug::caller
package require dbutil
#package require interp
#package require linenoise
#package require textutil::adjust
package require try

package require cm::table
#package require cm::util
package require cm::db
#package require cm::validate::city

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::city {
    namespace export cmd_create cmd_list
    namespace ensemble create

    namespace import ::cmdr::color
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
    # try to insert, report failure as user error

    set name   [$config @name]
    set state  [$config @state]
    set nation [$config @nation]

    set str $name
    if {$state ne {}} {append str /$state}
    append str " \[$nation\]"

    puts -nonewline "Creating city \"[color note $str]\" ... "

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

proc ::cm::city::Setup {} {
    debug.cm/city {}
    upvar 1 config config
    db do ;# Initialize db access.
    db show-location

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
	return -code error -errorcode {CM DB CITY SETUP} $error
    }

    # Shortcuit further calls
    proc ::cm::city::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::city 0
return
