## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::schedule 0
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

package require cm::util
package require cm::table
package require cm::db
package require cm::db::pschedule

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export schedule
    namespace ensemble create
}
namespace eval ::cm::schedule {
    namespace export \
	add remove rename show listing test-known test-select
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::db
    namespace import ::cm::db::pschedule
    namespace import ::cm::util

    namespace import ::cm::table::do
    namespace import ::cm::table::dict
    rename do   table
    rename dict table/d
}

# # ## ### ##### ######## ############# ######################

debug level  cm/schedule
debug prefix cm/schedule {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::add {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    # try to insert, report failure as user error

    set name [$config @name]

    puts -nonewline "Creating schedule \"[color name $name]\" ... "
    flush stdout

    try {
	db do transaction {
	    set pschedule [pschedule new $name]
	    pschedule validate
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	util user-error $e SCHEDULE CREATE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::remove {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @name]

    puts -nonewline "Remove schedule \"[color name [$config @name string]]\" ... "
    flush stdout

    # TODO: prevent removal if used in conferences
    pschedule remove $pschedule

    puts [color good OK]
    return
}

proc ::cm::schedule::rename {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @name]
    set new       [$config @newname]

    puts -nonewline "Rename schedule \"[color name [$config @name string]]\" to \"[color name $new]\" ... "
    flush stdout

    pschedule rename $pschedule $new

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::show {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @name]
    puts "\nSchedule [color name [$config @name string]]:"

    set psd [pschedule details $pschedule]
    dict with psd {} ;# xid, xdname, xname, xcurrent{day,track,item,open}

    [table/d t {
	$t add Name $xdname
	# Extensions: Track list, Day range, #Items.
	# Extension: Mark the current schedule, current track, current day.
    }] show
    return
}

proc ::cm::schedule::listing {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    puts "\nSchedules:"
    [table t {Name} {
	foreach {_ name _ _ _ _ _} [pschedule all] {
	    $t add $name
	    # Extensions: Track list, Day range, #Items.
	    # Extension: Mark the current schedule, current track, current day.
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::test-known {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location
    util pdict [pschedule known]
    return
}

proc ::cm::schedule::test-select {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location
    util pdict [pschedule selection]
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::schedule 0
return
