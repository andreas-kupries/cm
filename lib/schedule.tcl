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
package require cm::validate::pschedule-day

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export schedule
    namespace ensemble create
}
namespace eval ::cm::schedule {
    namespace export \
	current-or-select just-select validate \
	add remove rename select show listing test-known test-select \
	track-add track-remove track-rename test-track-known test-track-select \
	item-add-event item-add-placeholder test-item-day-known
    #item-remove item-rename
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::db
    namespace import ::cm::db::pschedule
    namespace import ::cm::util
    namespace import ::cm::validate::pschedule-day

    namespace import ::cm::table::do
    namespace import ::cm::table::dict
    rename do   table
    rename dict table/d
}

# # ## ### ##### ######## ############# ######################

debug level  cm/schedule
debug prefix cm/schedule {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::current-or-select {p} {
    debug.cm/schedule {}
    pschedule setup

    # Return the current schedule
    # Fall back to user selection of the schedule to work with.
    # Ask user if they wish to make that schedule current as well.

    set pschedule [pschedule current_get]
    if {$pschedule ne {}} {
	return $pschedule
    }

    set pschedule [util select $p schedule {pschedule selection}]
    if {$pschedule eq {}} {
	$p undefined!
    }

    set pslabel [dict get [pschedule details $pschedule] xdname]
    if {[ask yn "Make schedule \"[color name $pslabel]\" current ?" yes]} {
	pschedule current_set $pschedule
    }

    return $pschedule
}

proc ::cm::schedule::just-select {p} {
    debug.cm/schedule {}
    pschedule setup

    set pschedule [util select $p schedule {pschedule selection}]
    if {$pschedule eq {}} {
	$p undefined!
    }

    return $pschedule
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::validate {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    try {
	pschedule validate
    } on error {e o} {
	util user-error Failed:\n$e SCHEDULE VALIDATE
    }

    puts [color good OK]
    return
}

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
    db do transaction {
	pschedule remove $pschedule
	pschedule validate
    }

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

    db do transaction {
	pschedule rename $pschedule $new
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::select {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @name]

    puts -nonewline "\nSchedule \"[color name [$config @name string]]\": Make current ... "
    flush stdout

    db do transaction {
	pschedule current_set $pschedule
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::show {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @name]
    puts "\nSchedule \"[color name [$config @name string]]\":"

    set current_ps [pschedule current_get]
    set psd        [pschedule details $pschedule]
    dict with psd {} ;# xid, xdname, xname, xcurrent{day,track,item,open}

    [table/d t {
	if {$current_ps == $pschedule} { $t add [color note Current] }
	$t add Name   $xdname
	$t add Tracks [join [pschedule track-names $xid] \n]

	# Extensions: Day range, #Items.
	# Extension: Mark the current track, current day.
    }] show
    return
}

proc ::cm::schedule::listing {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set current_ps [pschedule current_get]

    puts "\nSchedules:"
    [table t {{} Name Tracks} {
	foreach {pschedule name _ _ _ _ _} [pschedule all] {
	    set tracks [join [pschedule track-names $pschedule] \n]
	    set mark   [expr {$current_ps == $pschedule ? "->" : ""}]

	    $t add $mark $name $tracks
	    # Extensions: Day range, #Items.
	    # Extension: Mark the current track, current day.
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

proc ::cm::schedule::track-add {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    # try to insert, report failure as user error

    set pslabel   [$config @schedule string]
    set pschedule [$config @schedule]
    set name      [$config @name]

    puts -nonewline "Schedule \"[color name $pslabel]\": Creating track \"[color name $name]\" ... "
    flush stdout

    try {
	db do transaction {
	    set track [pschedule track-new $pschedule $name]
	    pschedule validate
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	util user-error $e SCHEDULE-TRACK CREATE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-remove {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pslabel [$config @schedule string]
    set track   [$config @name]

    puts -nonewline "Schedule \"[color name $pslabel]\": Remove track \"[color name [$config @name string]]\" ... "
    flush stdout

    # TODO: prevent removal if (its schedule is) used in conferences
    db do transaction {
	pschedule track-remove $track
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-rename {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pslabel [$config @schedule string]
    set track   [$config @name]
    set new     [$config @newname]

    puts -nonewline "Schedule \"[color name $pslabel]\": Rename track \"[color name [$config @name string]]\" to \"[color name $new]\" ... "
    flush stdout

    db do transaction {
	pschedule track-rename $track $new
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::test-track-known {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location
    util pdict [pschedule track-known [$config @schedule]]
    return
}

proc ::cm::schedule::test-track-select {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location
    util pdict [pschedule track-selection [$config @schedule]]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::item-add-event {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set track     [$config @track]
    set day       [$config @day]
    set start     [$config @start-time]
    set length    [$config @length]
    set desc      [$config @description]
    set note      [$config @note]

    # try to insert, report failure as user error

    set pslabel   [$config @schedule string]

    puts "Schedule \"[color name $pslabel]\": Creating event \"$description\" ... "
    puts "* Track:  [color name [$config @track string]]"
    puts "* Day:    $day"
    puts "* Start:  [pschedule-day 2external $start]"
    puts "* Length: $length"
    puts "* Note:   $note"

    try {
	db do transaction {
	    set track [pschedule item-new-event $pschedule $track $day $start $length $desc $note]
	    pschedule validate
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	util user-error $e SCHEDULE-ITEM CREATE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::item-add-placeholder {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set track     [$config @track]
    set day       [$config @day]
    set start     [$config @start-time]
    set length    [$config @length]
    set label     [$config @label]

    # try to insert, report failure as user error

    set pslabel   [$config @schedule string]

    puts "Schedule \"[color name $pslabel]\": Creating placeholder \"$label\" ... "
    puts "* Track:       [color name [$config @track string]]"
    puts "* Day:         $day"
    puts "* Start:       [pschedule-day 2external $start]"
    puts "* Length:      $length"
    puts "* Description: $description"

    try {
	db do transaction {
	    set track [pschedule item-new-placeholder $pschedule $track $day $start $length $label]
	    pschedule validate
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	util user-error $e SCHEDULE-ITEM CREATE
	return
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::test-item-day-known {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location
    util pdict \
	[dict create \
	     max [pschedule day-max [$config @schedule]]]
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::schedule 0
return
