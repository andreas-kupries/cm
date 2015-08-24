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
package require cmdr::table
package require cmdr::validate::time::minute
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::util
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
	context-set-day context-get-day context-set-time context-get-time \
	context-request-parent context-get-parent \
	active-or-select just-select track-just-select day-just-select start validate \
	add remove rename select select-clear selected focus show listing test-known \
	test-select track-add track-remove track-rename \
	track-select track-select-clear track-selected \
	track-leftmost track-rightmost track-left track-right \
	test-track-known test-track-select \
	item-add-event item-add-placeholder test-item-day-max \
	day-select day-select-clear day-selected day-first day-last day-previous day-next

    #item-remove item-rename
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::db
    namespace import ::cm::db::pschedule
    namespace import ::cm::util
    namespace import ::cm::validate::pschedule-day

    namespace import ::cmdr::validate::time::minute

    namespace import ::cmdr::table::general ; rename general table
    namespace import ::cmdr::table::dict    ; rename dict    table/d
}

# # ## ### ##### ######## ############# ######################

debug level  cm/schedule
debug prefix cm/schedule {[debug caller] | }

# # ## ### ##### ######## ############# ######################
## Callbacks for focus location and associated defaults

proc ::cm::schedule::context-setup {p} {
    debug.cm/schedule {}
    pschedule setup

    # Initialize the context dictionary.
    dict set context schedule [set pschedule [$p config @schedule]]

    debug.cm/schedule {pschedule = ($pschedule)}
    if {$pschedule ne {}} {
	debug.cm/schedule {/focus}

	dict set context focus [pschedule focus $pschedule]

	# Absolute fallbacks for missing focus information.
	if {[dict get $context focus xactiveday] eq {}} {
	    dict set context focus xactiveday 0
	}
	if {[dict get $context focus xactivetime] eq {}} {
	    dict set context focus xactivetime  [pschedule start-get]
	}
    } else {
	debug.cm/schedule {/defaults}

	dict set context focus xactiveitem  {} ;# active item
	dict set context focus xactiveday   0  ;#        day
	dict set context focus xactivetrack {} ;#        track, time
	dict set context focus xactivetime  [pschedule start-get]

	dict set context focus xaitemday    {} ;# similar data
	dict set context focus xaitemtrack  {} ;# from the
	dict set context focus xaitemstart  {} ;# active item
	dict set context focus xaitemlen    {} ;#
    }

    dict set context parent {} ;# parent item to use

    debug.cm/schedule {==> ($context)}
    return $context
}

# # ## ### ##### ######## ############# ######################
## Logic for parent

proc ::cm::schedule::context-request-parent {p _ignored_} {
    debug.cm/schedule {}
    # RMW operation on the context.

    # NOTE: Cross-checking against options this one is not allowed
    # with is done at cmdr level (see cm.tcl, disallow-clauses).

    # Signal the system that item is child in need of a
    # parent. Compute the parent here => active item.
    # Throw error if we have no item usable as parent.

    # Read ...
    set context [$p config @context]
    debug.cm/schedule {context = ($context)}

    set ai [dict get $context focus xactiveitem]
    if {$ai eq {}} {
	return -code error -errorcode {CMDR VALIDATE} "No usable parent found"
    }

    # Check if the active item itself is a child. 
    set sparent [pschedule item-piece $ai parent]
    if {$sparent ne {}} {
	return -code error -errorcode {CMDR VALIDATE} "Bad parent, itself a child of $sparent."
    }

    # Compute derived information for the new item.

    set at [dict get $context focus xaitemtrack]
    set ad [dict get $context focus xaitemday]
    set as [dict get $context focus xaitemstart]
    set al [dict get $context focus xaitemlen]

    # ... Modify ...
    dict set context parent             $ai
    dict set context focus xactivetrack $at
    dict set context focus xactiveday   $ad
    dict set context focus xactivetime  [expr {$as + $al}]

    # ... Writeback
    $p config @context set $context
    return
}

proc ::cm::schedule::context-get-parent {p} {
    debug.cm/schedule {}

    # Read operation on the context.
    set context [$p config @context]
    return [dict get $context parent]
}

# # ## ### ##### ######## ############# ######################
## Logic for track

proc ::cm::schedule::context-set-track {p track} {
    debug.cm/schedule {}
    # RMW operation on the context.
    # User-specified track.

    # NOTE: Cross-checking against options this one is not allowed
    # with is done at cmdr level (see cm.tcl, disallow-clauses).

    # when-set hook: must do validation ourselves
    set track [{*}[$p validator] validate $p $track]

    # Read ...
    set context [$p config @context]

    # ... Modify ... (Setting user spec, and flag)
    dict set context focus xactivetrack $track
    dict set context flags track        .

    # ... Writeback
    $p config @context set $context
    return $track
}

proc ::cm::schedule::context-cross-tracks {p track} {
    debug.cm/schedule {}

    # RMW operation on the context.
    # User-specified track NULL (reach across tracks)

    # NOTE: Cross-checking against options this one is not allowed
    # with is done at cmdr level (see cm.tcl, disallow-clauses).

    # Read ...
    set context [$p config @context]

    # ... Modify ... (Setting user spec)
    dict set context focus xactivetrack {}
    dict set context flags across       .

    # ... Writeback
    $p config @context set $context
    return $track
}

proc ::cm::schedule::context-get-track {p} {
    debug.cm/schedule {}

    # Read operation on the context.
    set context [$p config @context]
    return [dict get $context focus xactivetrack]
}

# # ## ### ##### ######## ############# ######################
## Logic for day.

proc ::cm::schedule::context-set-day {p day} {
    debug.cm/schedule {}
    # RMW operation on the context.
    # User-specified day

    # NOTE: Cross-checking against options this one is not allowed
    # with is done at cmdr level (see cm.tcl, disallow-clauses).

    # when-set hook: must do validation ourselves
    set day [{*}[$p validator] validate $p $day]

    # Read ...
    set context [$p config @context]

    # ... Modify ... (Setting user spec)
    dict set context focus xactiveday $day
    dict set context flags day        .

    # ... Writeback
    $p config @context set $context
    return $day
}

proc ::cm::schedule::context-get-day {p} {
    debug.cm/schedule {}

    # Read operation on the context.
    set context [$p config @context]
    return [dict get $context focus xactiveday]
}

# # ## ### ##### ######## ############# ######################
## Logic for time.

proc ::cm::schedule::context-set-time {p offset} {
    debug.cm/schedule {}
    # RMW operation on the context.
    # User-specified starting time.

    # NOTE: Cross-checking against options this one is not allowed
    # with is done at cmdr level (see cm.tcl, disallow-clauses).

    # when-set hook: must do validation ourselves
    set offset [{*}[$p validator] validate $p $offset]

    # Read ...
    set context [$p config @context]

    # ... Modify ... (Setting user spec)
    dict set context focus xactivetime $offset
    dict set context flags time        .

    # ... Writeback
    $p config @context set $context
    return $offset
}

proc ::cm::schedule::context-get-time {p} {
    debug.cm/schedule {}

    # Read operation on the context.
    set context [$p config @context]
    return [dict get $context focus xactivetime]
}

# # ## ### ##### ######## ############# ######################
## Callbacks for active schedule

proc ::cm::schedule::active-or-select {p} {
    debug.cm/schedule {}
    pschedule setup

    # Return the active schedule
    # Fall back to user selection of the schedule to work with.
    # Ask user if they wish to make that schedule active as well.

    set pschedule [pschedule active-get]
    if {$pschedule ne {}} {
	debug.cm/schedule {active ==> $pschedule}
	return $pschedule
    }

    set pschedule [util select $p schedule {pschedule selection}]
    if {$pschedule eq {}} {
	debug.cm/schedule {undefined!}
	$p undefined!
    }

    set pslabel [pschedule piece $pschedule dname]
    if {[ask yn "Activate schedule \"[color name $pslabel]\" ?" yes]} {
	debug.cm/schedule {activate $pschedule}
	pschedule active-set $pschedule
    }

    debug.cm/schedule {==> $pschedule}
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

proc ::cm::schedule::track-just-select {p} {
    debug.cm/schedule {}
    pschedule setup

    lappend cmd pschedule track-selection [$p config @schedule]

    set track [util select $p track $cmd]
    if {$track eq {}} {
	$p undefined!
    }

    return $track
}

proc ::cm::schedule::day-just-select {p} {
    debug.cm/schedule {}
    pschedule setup

    lappend cmd pschedule day-selection [$p config @schedule]

    set day [util select $p day $cmd]
    if {$day eq {}} {
	$p undefined!
    }

    return $day
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

proc ::cm::schedule::start {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    if {[$config @time set?]} {
	set time [$config @time]
	set tlabel [minute 2external $time]

	puts -nonewline "\nSetting global start time to $tlabel ... "
	flush stdout

	pschedule start-set $time

	puts [color good OK]
    } else {
	puts ""
    }

    puts -nonewline "Current global start time: "
    flush stdout

    puts [minute 2external [pschedule start-get]]
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
	    pschedule active-set $pschedule

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

    set pschedule [pschedule active-get]

    if {$pschedule eq {}} {
	puts \n[color note {No active schedule, operation ignored.}]
	return
    }

    set name [pschedule piece $pschedule dname]

    puts -nonewline "\nDeactivating schedule \"[color name $name]\" ... "
    flush stdout

    db do transaction {
	pschedule active-set {}
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::selected {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [pschedule active-get]

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
    set pslabel   [pschedule piece $pschedule dname]

    puts -nonewline "\nActivating schedule \"[color name $pslabel]\" ... "
    flush stdout

    db do transaction {
	pschedule active-set $pschedule
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

    set active_ps [pschedule active-get]
    set psd       [pschedule details $pschedule]
    dict with psd {} ;# xid, xdname, xname, xactive{day,track,item,open}

    puts "\nSchedule \"[color name $xdname]\":"
    [table/d t {
	if {$active_ps == $pschedule} { $t add [color note Active] }
	#$t add Name   $xdname -- redundant -- See intro line above.

	if {$xactiveday ne {}} {
	    $t add Days "[pschedule day-cover $xid] ([color bold "@ $xactiveday"])"
	} else {
	    $t add Days [pschedule day-cover $xid]
	}
	$t add Tracks [TrackList $xid bold]
	$t add Items  [ItemList  $xid bold]
    }] show
    return
}

proc ::cm::schedule::listing {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set active_ps [pschedule active-get]

    puts "\nSchedules:"
    [table t {{} Name Days Tracks} {
	foreach {pschedule name _ _ activeday _ _} [pschedule all] {
	    set tracks [TrackList $pschedule]
	    set days   [pschedule day-cover $pschedule]
	    if {$activeday ne {}} {
		append days " (@ " $activeday ")"
	    }

	    util highlight-current active_ps $pschedule mark name days tracks
	    $t add $mark $name $days $tracks
	    # Note: Do not show item details. To much data for a list.
	}
    }] show
    return
}

proc ::cm::schedule::focus {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [pschedule active-get]

    if {$pschedule eq {}} {
	puts \n[color note {No active schedule}]
	return
    }

    set name  [pschedule piece $pschedule dname]
    set focus [pschedule focus $pschedule]
    dict with focus {} ;# => xactive{item,day,track,time},xaitem{day,track,start,len}

    if {$xactivetrack ne {}} { set xactivetrack [track-piece $xactivetrack dname] }
    if {$xaitemtrack  ne {}} { set xaitemtrack  [track-piece $xaitemtrack  dname] }

    if {$xaitemstart != {}} {
	set xaitemstart [minute 2external $xaitemstart]
    }
    if {$xactivetime != {}} {
	set xactivetime [minute 2external $xactivetime]
    }

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
	    $t add Time  "I $xaitemstart $xaitemlen (-- $xactivetime)"
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::TrackList {pschedule {color {}}} {
    debug.cm/schedule {}

    set trackstats [pschedule track-name-counts $pschedule]
    # (name -> icount, sorted by name)

    # Quick bailout when there are no tracks.
    if {![llength $trackstats]} { return {} }

    set at [pschedule track-active-get $pschedule]
    set at [pschedule track-piece $at dname]

    set tracks [string trimright [[table tx {{} Track Count} {
	$tx noheader
	$tx plain
	foreach {name icount} $trackstats {
	    set mark [expr {$at eq $name ? "->" : ""}]
	    if {($at eq $name) && ($color ne {})} {
		set mark   [color $color $mark]
		set name   [color $color $name]
		set icount [color $color $icount]
	    }
	    $tx add $mark $name ($icount)
	}
    }] show return] \n]

    debug.cm/schedule {==> ($tracks)}
    return $tracks
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::ItemList {pschedule {color {}} {map {}}} {
    debug.cm/schedule {}

    set items [pschedule item-all $pschedule]
    # (id schedule day trackname start length parent label dmajor dminor)

    # Quick bailout when there are no items.
    if {![llength $items]} { return {} }

    # Compute tracks in use, their max width, and calculate from that
    # a symbol to use for items going across tracks.
    set tracks {}
    foreach {_ _ _ track _ _ _ _ _ _} $items { lappend tracks $track }
    set maxt [util max-length $tracks]
    switch -exact $maxt {
	0 -
	1 { set across * }
	2 { set across <> }
	default {
	    incr maxt -2
	    set across <[string repeat - $maxt]>
	}
    }

    # Make the table.
    set ai    [pschedule item-active-get $pschedule]
    set lastday 0

    set items [string trimright [[table tx {{} {} Day Start End Length {} Track {} Desc Note} {
	#                             active^  ^parent
	$tx noheader
	$tx plain

	foreach {id _ day track start length parent label dmajor dminor} $items {

	    if {$day != $lastday} {
		$tx add {} {} {} {} {} {} - {} - {} {}
	    }

	    set mark   [expr {$id     eq $ai ? "->"  : ""}]
	    set parent [expr {$parent ne {}  ? " \\-" : "*"}]
	    set end    [minute 2external [expr {$start + $length}]]
	    set start  [minute 2external $start]
	    set length ([minute 2external $length])

	    if {$track  eq {}} { set track $across       }
	    if {$dmajor eq {}} {
		set dmajor <<${label}>>
		if {[dict exists $map $label]} {
		    lassign [dict get $map $label] str speaker
		    if {$str ne {}} {
			set dmajor ">> $str "
			set dminor $speaker
		    }
		}
	    }

	    if {($id eq $ai) && ($color ne {})} {
		set mark   [color $color $mark] 
		set parent [color $color $parent]
		set start  [color $color $start]
		set length [color $color $length]
		set end    [color $color $end]
		set track  [color $color $track] 
		set dmajor [color $color $dmajor]
		set dminor [color $color $dminor]
	    }

	    $tx add $mark $parent $day $start $end $length | $track | $dmajor $dminor
	    set lastday $day
	}
    }] show return] \n]

    debug.cm/schedule {==> ($items)}
    return $items
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

proc ::cm::schedule::track-select-clear {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece            $pschedule dname]
    set track     [pschedule track-active-get $pschedule]

    if {$track eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active track, operation ignored.}]"
	return
    }

    set tlabel [pschedule track-piece $track dname]

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Deactivating track \"[color name $tlabel]\" ... "
    flush stdout

    db do transaction {
	pschedule track-active-set $pschedule {}
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-selected {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece            $pschedule dname]
    set track     [pschedule track-active-get $pschedule]

    if {$track eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active track.}]"
	return
    }

    set tlabel [pschedule track-piece $track dname]

    puts "\nSchedule \"[color name $pslabel]\": Active track is \"[color name $tlabel]\"."
    return
}

proc ::cm::schedule::track-select {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set track     [$config @name]
    set pslabel   [pschedule piece $pschedule dname]
    set tlabel    [pschedule track-piece $track dname]

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating track \"[color name $tlabel]\" ... "
    flush stdout

    db do transaction {
	pschedule track-active-set $pschedule $track
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-leftmost {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece $pschedule dname]

    # TODO: leftmost - handle case of no tracks

    set tracks [pschedule track-map $pschedule]
    lassign [lrange $tracks 0 1] track tlabel

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating track \"[color name $tlabel]\" ... "
    flush stdout

    db do transaction {
	pschedule track-active-set $pschedule $track
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-rightmost {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece $pschedule dname]

    # TODO: rightmost - handle case of no tracks

    set tracks [pschedule track-all $pschedule]
    lassign [lrange $tracks end-1 end] track tlabel

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating track \"[color name $tlabel]\" ... "
    flush stdout

    db do transaction {
	pschedule track-active-set $pschedule $track
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-left {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece            $pschedule dname]
    set track     [pschedule track-active-get $pschedule]

    # No tracks falls under 'no active track'.

    if {$track eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active track, operation ignored.}]"
	return
    }

    # Previous track, with wrap-around to rightmost.
    set tracks [pschedule track-all $pschedule]
    set pos [lsearch -exact [dict keys $tracks] $track]
    incr pos $pos
    incr pos -2
    if {$pos < 0} { set pos end-1 }
    lassign [lrange $tracks $pos ${pos}+1] track tlabel

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating track \"[color name $tlabel]\" ... "
    flush stdout

    db do transaction {
	pschedule track-active-set $pschedule $track
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::track-right {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece            $pschedule dname]
    set track     [pschedule track-active-get $pschedule]

    # No tracks falls under 'no active track'.

    if {$track eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active track, operation ignored.}]"
	return
    }

    # Next track, with wrap-around to leftmost.
    set tracks [pschedule track-all $pschedule]
    set pos [lsearch -exact [dict keys $tracks] $track]
    incr pos $pos
    incr pos 2
    if {$pos > [llength $tracks]} { set pos 0 }
    lassign [lrange $tracks $pos ${pos}+1] track tlabel

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating track \"[color name $tlabel]\" ... "
    flush stdout

    db do transaction {
	pschedule track-active-set $pschedule $track
	pschedule validate
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::schedule::day-select-clear {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece          $pschedule dname]
    set day       [pschedule day-active-get $pschedule]

    if {$day eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active day, operation ignored.}]"
	return
    }

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Deactivating day \"[color name $day]\" ... "
    flush stdout

    db do transaction {
	pschedule day-active-set $pschedule {}
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::day-selected {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece          $pschedule dname]
    set day       [pschedule day-active-get $pschedule]

    if {$day eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active day.}]"
	return
    }

    puts "\nSchedule \"[color name $pslabel]\": Active day is \"[color name $day]\"."
    return
}

proc ::cm::schedule::day-select {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set day       [$config @day]
    set pslabel   [pschedule piece $pschedule dname]

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating day \"[color name $day]\" ... "
    flush stdout

    db do transaction {
	pschedule day-active-set $pschedule $day
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::day-first {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece $pschedule dname]

    set day 0

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating day \"[color name $day]\" ... "
    flush stdout

    db do transaction {
	pschedule day-active-set $pschedule $day
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::day-last {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece   $pschedule dname]
    set day       [pschedule day-max $pschedule]

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating day \"[color name $day]\" ... "
    flush stdout

    db do transaction {
	pschedule day-active-set $pschedule $day
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::day-previous {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece          $pschedule dname]
    set day       [pschedule day-active-get $pschedule]

    if {$day eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active day, operation ignored.}]"
	return
    }

    # Previous day, with wrap-around to last.
    incr day -1
    if {$day < 0} { set day [pschedule day-max $pschedule] }

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating day \"[color name $day]\" ... "
    flush stdout

    db do transaction {
	pschedule day-active-set $pschedule $day
	pschedule validate
    }

    puts [color good OK]
    return
}

proc ::cm::schedule::day-next {config} {
    debug.cm/schedule {}
    pschedule setup
    db show-location

    set pschedule [$config @schedule]
    set pslabel   [pschedule piece          $pschedule dname]
    set day       [pschedule day-active-get $pschedule]

    if {$day eq {}} {
	puts "\nSchedule \"[color name $pslabel]\": [color note {No active day, operation ignored.}]"
	return
    }

    # Next day, with wrap-around to first.
    set max [pschedule day-max $pschedule]
    incr day 1
    if {$day > $max} { set day 0 }

    puts -nonewline "\nSchedule \"[color name $pslabel]\": Activating day \"[color name $day]\" ... "
    flush stdout

    db do transaction {
	pschedule day-active-set $pschedule $day
	pschedule validate
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

    # Related information about focus, found in the context.
    set context   [$config @context]
    set pschedule [dict get $context schedule]
    set track     [dict get $context focus xactivetrack]
    set day       [dict get $context focus xactiveday]
    set start     [dict get $context focus xactivetime]
    set parent    [dict get $context parent]

    # Remainder, outside of context.
    set length    [$config @length]
    set desc      [$config @description]
    set note      [$config @note]

    set validate  [expr {![$config @dont-check]}]

    # try to insert, report failure as user error

    set pslabel [pschedule piece $pschedule dname]

    if {$track eq {}} {
	set tlabel {Across all tracks}
	set tcolor note
    } else {
	set tlabel [pschedule track-piece $track dname]
	set tcolor name
    }

    debug.cm/schedule { context   = ($context)}
    debug.cm/schedule { schedule  = $pschedule "$pslabel"}
    debug.cm/schedule { track     = ($track) "$tlabel"}
    debug.cm/schedule { day       = $day}
    debug.cm/schedule { start/len = $start ($length)}
    debug.cm/schedule { desc      = "$desc"}
    debug.cm/schedule { note      = "$note"}
    debug.cm/schedule { validate  = $validate}
    debug.cm/schedule { parent    = $parent }

    puts "Schedule \"[color name $pslabel]\": Creating event \"[color name $desc]\" ... "
    puts "* Track:  [color $tcolor $tlabel]"
    puts "* Day:    $day"
    puts "* Start:  [minute 2external $start]"
    puts "* Length: [minute 2external $length]"
    if {$note ne {}} {
	puts "* Note:   [color name $note]"
    }

    try {
	db do transaction {
	    set item [pschedule item-new-event \
			  $pschedule $track $day $start $length \
			  $parent \
			  $desc $note]

	    if {$parent eq {}} {
		# New item is automatically active, except if a child
		puts -nonewline "Activating ... "
		flush stdout
		pschedule item-active-set $pschedule $item
	    } else {
		# Affirm parent as active, with updated time/length
		pschedule item-active-set $pschedule $parent
	    }

	    if {$validate} { pschedule validate }
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

    # Related information about focus, found in the context.
    set context   [$config @context]
    set pschedule [dict get $context schedule]
    set track     [dict get $context focus xactivetrack]
    set day       [dict get $context focus xactiveday]
    set start     [dict get $context focus xactivetime]
    set parent    [dict get $context parent]

    # Remainder, outside of context.
    set length    [$config @length]
    set label     [$config @label]

    set validate  [expr {![$config @dont-check]}]

    # try to insert, report failure as user error

    set pslabel [pschedule piece       $pschedule dname]

    if {$track eq {}} {
	set tlabel {Across all tracks}
	set tcolor note
    } else {
	set tlabel [pschedule track-piece $track dname]
	set tcolor name
    }

    puts "Schedule \"[color name $pslabel]\": Creating placeholder \"[color name $label]\" ... "
    puts "* Track:  [color $tcolor $tlabel]"
    puts "* Day:    $day"
    puts "* Start:  [minute 2external $start]"
    puts "* Length: [minute 2external $length]"
    puts "* Label:  $label"

    try {
	db do transaction {
	    set item [pschedule item-new-placeholder \
			  $pschedule $track $day $start $length \
			  $parent \
			  $label]

	    if {$parent eq {}} {
		# New item is automatically active, except if a child
		puts -nonewline "Activating ... "
		flush stdout
		pschedule item-active-set $pschedule $item
	    } else {
		# Affirm parent as active, with updated time/length
		pschedule item-active-set $pschedule $parent
	    }

	    if {$validate} { pschedule validate }
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

proc ::cm::schedule::test-item-day-max {config} {
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
