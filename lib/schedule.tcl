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
package require cmdr::validate::time::minute
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
	context-setup context-set-track context-cross-tracks context-get-track \
	active-or-select just-select validate \
	add remove rename select select-clear selected focus show listing test-known \
	test-select track-add track-remove track-rename test-track-known \
	test-track-select item-add-event item-add-placeholder test-item-day-known
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
## Callbacks for focus location and associated defaults

proc ::cm::schedule::context-setup {p} {
    debug.cm/schedule {}
    pschedule setup

    set pschedule [pschedule active_get]
    if {$pschedule eq {}} {
	return {
	    schedule {}
	    focus {
		xactiveitem  {}
		xactiveday   {}
		xactivetrack {}
		xactivetime  {}
		xaitemday    {}
		xaitemtrack  {}
		xaitemstart  {}
		xaitemlen    {}
	    }
	    flags {
		item  system
		day   system
		track system
		time  system
	    }
	}
    }

    set focus [pschedule focus $pschedule]
    return [dict create \
		schedule $pschedule \
		focus    $focus \
		flags {
		    item  system
		    day   system
		    track system
		    time  system
		}]
}

proc ::cm::schedule::context-set-track {p track} {
    debug.cm/schedule {}
    # RMW operation on the context.
    # User-specified track.

    # Read ...
    set context [$p config @context]

    # ... Modify ... (Setting user spec)
    dict set context focus xactivetrack $track
    dict set context flags track        user

    # ... Writeback
    $p config @context set $context

    return $track
}

proc ::cm::schedule::context-cross-tracks {p track} {
    debug.cm/schedule {}

    # RMW operation on the context.
    # User-specified track NULL (reach across tracks)

    # Read ...
    set context [$p config @context]

    # ... Modify ... (Setting user spec)
    dict set context focus xactivetrack {}
    dict set context flags track        user

    # ... Writeback
    $p config @context set $context

    return $track
}

proc ::cm::schedule::context-get-track {p} {
    debug.cm/schedule {}

    # Read operation on the context.
    set context [$p config @context]

    # assert (dict get $context flags track) == system

    # Pull relevant focus data (active item, item track, active track).
    set ci [dict get $context focus xactiveitem]
    set it [dict get $context focus xaitemtrack]
    set ct [dict get $context focus xactivetrack]

    debug.cm/schedule {active item       = $ci}
    debug.cm/schedule {active item track = $it}
    debug.cm/schedule {active track      = $ct}

    # No active item, return active track
    if {$ci eq {}} {
	return $ct
    }

    # The active item crosses tracks, return active track
    if {$it eq {}} {
	return $ct
    }

    # Return the active item's track. Same as the active track (ct)
    # for an item not crossing tracks.
    return $it

    # UGH ... Reading the comments and looking at returns, it seems
    # that we can simply always return the active track without all
    # the checks and complexity.
    #
    # TODO test the above possibility
}

# # ## ### ##### ######## ############# ######################
## Callbacks for active schedule

proc ::cm::schedule::active-or-select {p} {
    debug.cm/schedule {}
    pschedule setup

    # Return the active schedule
    # Fall back to user selection of the schedule to work with.
    # Ask user if they wish to make that schedule active as well.

    set pschedule [pschedule active_get]
    if {$pschedule ne {}} {
	return $pschedule
    }

    set pschedule [util select $p schedule {pschedule selection}]
    if {$pschedule eq {}} {
	$p undefined!
    }

    set pslabel [pschedule piece $pschedule dname]
    if {[ask yn "Activate schedule \"[color name $pslabel]\" ?" yes]} {
	pschedule active_set $pschedule
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

	    # New schedule is automatically active.
	    puts -nonewline "Activating ... "
	    flush stdout
	    pschedule active_set $pschedule

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

proc ::cm::schedule::select-clear {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [pschedule active_get]

    if {$pschedule eq {}} {
	puts \n[color note {No active schedule, operation ignored.}]
	return
    }

    set name [pschedule piece $pschedule dname]

    puts -nonewline "\nDeactivating schedule \"[color name $name]\" ... "
    flush stdout

    db do transaction {
	pschedule active_set {}
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::selected {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [pschedule active_get]

    if {$pschedule eq {}} {
	puts \n[color note {No active schedule}]
	return
    }

    set name [pschedule piece $pschedule dname]

    puts "\nActive schedule is \"[color name $name]\""
    return
}

proc ::cm::schedule::select {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @name]

    puts -nonewline "\nActivating schedule \"[color name [$config @name string]]\" ... "
    flush stdout

    db do transaction {
	pschedule active_set $pschedule
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

    set active_ps [pschedule active_get]
    set psd       [pschedule details $pschedule]
    dict with psd {} ;# xid, xdname, xname, xactive{day,track,item,open}

    [table/d t {
	if {$active_ps == $pschedule} { $t add [color note Active] }
	$t add Name   $xdname
	$t add Days   [pschedule day-cover $xid]
	$t add Tracks [TrackList $xid]

	# Extension: Mark the active track and day.
    }] show
    return
}

proc ::cm::schedule::listing {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set active_ps [pschedule active_get]

    puts "\nSchedules:"
    [table t {{} Name Days Tracks} {
	foreach {pschedule name _ _ _ _ _} [pschedule all] {
	    set tracks [TrackList $pschedule]
	    set days   [pschedule day-cover $pschedule]

	    util highlight-current active_ps $pschedule mark name days tracks
	    $t add $mark $name $days $tracks

	    # Extension: Mark the active track, and day.
	}
    }] show
    return
}

proc ::cm::schedule::focus {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [pschedule active_get]

    if {$pschedule eq {}} {
	puts \n[color note {No active schedule}]
	return
    }

    set name  [pschedule piece $pschedule dname]
    set focus [pschedule focus $pschedule]
    dict with focus {} ;# => xactive{item,day,track,time},xaitem{day,track,start,len}

    if {$xactivetrack ne {}} { set xactivetrack [track-piece $xactivetrack dname] }
    if {$xaitemtrack  ne {}} { set xaitemtrack  [track-piece $xaitemtrack  dname] }

    puts "\nFocus"
    [table/d t {
	$t add Schedule  $name
	if {$xactiveitem eq {}} {
	    # No item. Use saved historical data
	    $t add Day       $xactiveday
	    $t add Track     $xactivetrack
	    $t add Time      $xactivetime
	} else {
	    # Use item information, and show delta to historical
	    if {$xactiveday == $xaitemday} {
		$t add Day   "I $xaitemday"
	    } else {
		$t add Day   "I $xaitemday (-- $xactiveday)"
	    }
	    if {$xactivetrack eq $xaitemtrack} {
		$t add Track "I $xaitemtrack"
	    } else {
		$t add Track "I $xaitemtrack (-- $xactivetrack)"
	    }
	    $t add Time  "I $xaitemstart $xaitemlen (-- $xactivetime)" ;# -- TODO: format start, activetime
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::TrackList {pschedule} {
    debug.cm/schedule {}
    set tracks {}

    set trackstats [pschedule track-name-counts $pschedule]
    # (name -> icount, sorted by name)

    foreach name [util padr [util even $trackstats]] icount [util odd $trackstats] {
	debug.cm/schedule { - $name = $icount}
	append tracks $name " (" $icount ")\n"
    }
    set tracks [string trimright $tracks \n]

    debug.cm/schedule {==> ($tracks)}
    return $tracks
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

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece $pschedule dname]
    set name      [$config @name]

    debug.cm/schedule {pschedule = $pschedule '$pslabel'}
    debug.cm/schedule {name      = '$name'}

    # try to insert, report failure as user error
    puts -nonewline "Schedule \"[color name $pslabel]\": Creating track \"[color name $name]\" ... "
    flush stdout

    try {
	db do transaction {
	    set track [pschedule track-new $pschedule $name]

	    # New track is automatically active.
	    puts -nonewline "Activating ... "
	    flush stdout
	    pschedule track-active-set $pschedule $track

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

    set pslabel [pschedule piece [$config @schedule] dname]
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

    set pslabel [pschedule piece [$config @schedule] dname]
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

    set pslabel [pschedule piece $pschedule dname]

    puts "Schedule \"[color name $pslabel]\": Creating event \"$desc\" ... "
    puts "* Track:  [color name [$config @track string]]"
    puts "* Day:    $day"
    puts "* Start:  [cmdr::validate::time::minute 2external $start]"
    puts "* Length: $length"
    puts "* Note:   $note"

    try {
	db do transaction {
	    set item [pschedule item-new-event $pschedule $track $day $start $length $desc $note]

	    # New item is automatically active.
	    puts -nonewline "Activating ... "
	    flush stdout
	    pschedule item-active-set $pschedule $item

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

    set pslabel   [pschedule piece $pschedule dname]

    puts "Schedule \"[color name $pslabel]\": Creating placeholder \"$label\" ... "
    puts "* Track:  [color name [$config @track string]]"
    puts "* Day:    $day"
    puts "* Start:  [cmdr::validate::time::minute 2external $start]"
    puts "* Length: $length"
    puts "* Label:  $label"

    try {
	db do transaction {
	    set item [pschedule item-new-placeholder $pschedule $track $day $start $length $label]

	    # New item is automatically active.
	    puts -nonewline "Activating ... "
	    flush stdout
	    pschedule item-active-set $pschedule $item

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
