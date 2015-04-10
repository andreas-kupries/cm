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
package require try

package require cm::table
package require cm::util
package require cm::db
package require cm::db::city

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export city
    namespace ensemble create
}
namespace eval ::cm::city {
    namespace export create delete show list-all
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cm::util
    namespace import ::cm::db
    namespace import ::cm::db::city

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/city
debug prefix cm/city {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::city::list-all {config} {
    debug.cm/city {}
    city setup
    db show-location

    [table t {Name State Nation} {
	foreach {id name state nation} [city all] {
	    $t add $name $state $nation
	}
    }] show
    return
}

proc ::cm::city::create {config} {
    debug.cm/city {}
    city setup
    db show-location

    set name   [$config @name]
    set state  [$config @state]
    set nation [$config @nation]
    set label  [city label $name $state $nation]

    puts -nonewline "Creating new city \"[color name $label]\" ... "

    try {
	city new $name $state $nation
    } on error {e o} {
	# Report insert failure as user error
	# TODO: trap only proper insert error, if possible.
	util user-error $e CITY CREATE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::city::delete {config} {
    debug.cm/city {}
    city setup
    db show-location

    set city [$config @city]

    puts -nonewline "Deleting city \"[color name [city 2name $city]]\" ... "

    # TODO: constrain deletion to cities not in use by locations or
    # conferences.

    try {
	city delete $city
    } on error {e o} {
	# Report deletion failure as user error
	# TODO: trap only proper insert error, if possible.
	util user-error $e CITY DELETE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::city::show {config} {
    debug.cm/city {}
    city setup
    db show-location

    set city [$config @city]

    [table t {Property Value} {
	lassign [city get $city] name state nation
	$t add Name   [color name $name]
	$t add State  $state
	$t add Nation $nation
    }] show
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::city 0
return
