## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::tutorial 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta tutorial    http:/core.tcl.tk/akupries/cm
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
package require debug
package require debug::caller
package require dbutil
package require try

#package provide cm::tutorial 0 ;# circular through contact, campaign, conference

package require cm::db
package require cm::db::tutorial
package require cm::db::contact
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export tutorial
    namespace ensemble create
}
namespace eval ::cm::tutorial {
    namespace export \
	create list-all show set-title set-desc set-req set-tag
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::db::contact
    namespace import ::cm::db::tutorial
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/tutorial
debug prefix cm/tutorial {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::tutorial::list-all {config} {
    debug.cm/tutorial {}
    tutorial setup
    db show-location

    [table t {Speaker Tag Note Title} {
	foreach {speaker stag sbio tag title} [tutorial all] {
	    set notes {}
	    if {$stag eq {}} { lappend notes [color bad {No speaker tag}] }
	    if {$sbio eq {}} { lappend notes [color bad {No speaker biography}] }

	    $t add $speaker @${stag}:$tag [join $notes \n] $title
	}
    }] show
    return
}

proc ::cm::tutorial::create {config} {
    debug.cm/tutorial {}
    tutorial setup
    db show-location
    # try to insert, report failure as user error

    set prereq      [$config @requisites]
    set speaker     [$config @speaker]
    set tag         [$config @tag]
    set title       [$config @title]

    if {![$config @description set?]} {
	set description [read stdin]
    } else {
	set description [$config @description]
    }

    puts -nonewline "Creating \"[color name [contact 2name $speaker]]\" tutorial \"[color name $title]\" ... "

    try {
	tutorial new $speaker $tag $title $prereq $description
    } on error {e o} {
	# Report insert failure as user error
	# TODO: trap only proper insert error, if possible.
	util user-error $e TUTORIAL CREATE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::tutorial::show {config} {
    debug.cm/tutorial {}
    tutorial setup
    db show-location

    set tutorial [$config @name]
    set details  [tutorial get $tutorial]

    dict with details {}

    set w [util tspace [expr {[string length Description]+7}] 60]
    set xspeaker [contact 2name $xspeaker]

    puts "Details of [color name $xspeaker]'s tutorial \"[color name [tutorial 2name $tutorial]]\":"
    [table t {Property Value} {
	set issues [tutorial issues $details]
	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
	    $t add -------- -----
	}

	$t add Speaker      [color name $xspeaker]
	$t add Tag          $xtag
	$t add Title        $xtitle
	$t add Requisites   [util adjust $w $xprereq]
	$t add Description  [util adjust $w $xdescription]
    }] show
    return
}

proc ::cm::tutorial::set-title {config} {
    debug.cm/conference {}
    tutorial setup
    db show-location

    set tutorial [$config @tutorial] 
    set text     [$config @text]

    puts -nonewline "Set title of \"[color name [tutorial 2name $tutorial]]\" ... "
    flush stdout

    tutorial title= $tutorial $text

    puts [color good OK]
    return
}

proc ::cm::tutorial::set-desc {config} {
    debug.cm/conference {}
    tutorial setup
    db show-location

    set tutorial [$config @tutorial] 

    if {![$config @text set?]} {
	set text [read stdin]
    } else {
	set text [$config @text]
    }

    puts -nonewline "Set description of \"[color name [tutorial 2name $tutorial]]\" ... "
    flush stdout

    tutorial desc= $tutorial $text

    puts [color good OK]
    return
}

proc ::cm::tutorial::set-req {config} {
    debug.cm/conference {}
    tutorial setup
    db show-location

    set tutorial [$config @tutorial] 
    set text     [$config @text]

    puts -nonewline "Set requisites of \"[color name [tutorial 2name $tutorial]]\" ... "
    flush stdout

    tutorial req= $tutorial $text

    puts [color good OK]
    return
}

proc ::cm::tutorial::set-tag {config} {
    debug.cm/conference {}
    tutorial setup
    db show-location

    set tutorial [$config @tutorial] 
    set text     [$config @text]

    puts -nonewline "Set tag of \"[color name [tutorial 2name $tutorial]]\" ... "
    flush stdout

    tutorial tag= $tutorial $text

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::tutorial 0
return
