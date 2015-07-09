# -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# # ## ### ##### ######## ############# #####################

# @@ Meta Begin
# Package cm::table 0
# Meta author      ?
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require TclOO
package require debug
package require debug::caller
package require report
package require cmdr::color
package require struct::matrix

# # ## ### ##### ######## ############# ######################

debug level  table
debug prefix table {[debug caller] | }

# # ## ### ##### ######## ############# ######################
## Styles used in the table reports.

# Borders and header row.
::report::defstyle table/borders {} {
    data	set [split "[string repeat "| "   [columns]]|"]
    top		set [split "[string repeat "+ - " [columns]]+"]
    bottom	set [top get]
    topdata	set [data get]
    topcapsep	set [top get]
    top		enable
    bottom	enable
    topcapsep	enable
    tcaption	1
    for {set i 0 ; set n [columns]} {$i < $n} {incr i} {
	pad $i both { }
    }
    return
}

# Borders, no header row.
::report::defstyle table/borders/nohdr {} {
    data	set [split "[string repeat "| "   [columns]]|"]
    top		set [split "[string repeat "+ - " [columns]]+"]
    bottom	set [top get]
    top		enable
    bottom	enable
    for {set i 0 ; set n [columns]} {$i < $n} {incr i} {
	pad $i both { }
    }
    return
}

# No borders, with header row.
::report::defstyle table/plain {} {
    tcaption	1
    for {set i 1 ; set n [columns]} {$i < $n} {incr i} {
	pad $i left { }
    }
    return
}

# No borders, no header row
::report::defstyle table/plain/nohdr {} {
    for {set i 1 ; set n [columns]} {$i < $n} {incr i} {
	pad $i left { }
    }
    return
}

::report::defstyle table/html {} {
    data	set [split "<tr><td> [string repeat "</td><td> " [expr {[columns]-1}]]</td></tr>"]
    #top		set <table>
    #bottom	set </table>
    #top		enable
    #bottom	enable
    return
}

namespace eval ::cm::table {
    # Global style setting (plain yes/no)
    variable plain no

    # Global print setting (command prefix)
    variable showcmd puts

    namespace export do dict plain show
}

# # ## ### ##### ######## ############# #####################

proc ::cm::table::plain {v} {
    debug.table {}
    variable plain $v
    return
}

proc ::cm::table::show {args} {
    debug.table {}
    variable showcmd $args
    return
}

proc ::cm::table::do {v headings script} {
    debug.table {}

    variable plain
    upvar 1 $v t
    set t [uplevel 1 [list ::cm::table new {*}$headings]]
    if {$plain} { $t plain }
    uplevel 1 $script
    return $t
}

oo::class create ::cm::table {
    # # ## ### ##### ######## #############

    constructor {args} {
	debug.table {}
	namespace import ::cmdr::color
	# args = headings.

	struct::matrix [self namespace]::M
	M add columns [llength $args]

	set headings {}
	foreach w $args { lappend headings [color heading $w] }

	M add row $headings
	set myplain 0
	set myheader 1
	set mystyle {}
	return
    }

    destructor {}

    # # ## ### ##### ######## #############
    ## API

    # method names +, <<, => did not work ?!

    method add {args} {
	M add row $args
	return
    }

    method = {} {
	set result [my String]
	my destroy
	return $result
    } ; export =

    method show {{cmd {}}} {
	if {[llength [info level 0]] == 2} {
	    variable ::cm::table::showcmd
	    set cmd $::cm::table::showcmd
	}
	uplevel #0 [list {*}$cmd [my String]]
	my destroy
	return
    }

    method show* {{cmd {}}} {
	if {[llength [info level 0]] == 2} {
	    variable ::cm::table::showcmd
	    set cmd $::cm::table::showcmd
	}
	uplevel #0 [list {*}$cmd [my String]]
	return
    }

    method plain {} {
	debug.table {}
	set myplain 1
	return
    }

    method style {style} {
	debug.table {}
	set mystyle $style
	return
    }

    method noheader {} {
	debug.table {}
	if {!$myheader} return
	set myheader 0
	M delete row 0
	return
    }

    method String {} {
	debug.table {}
	# Choose style (user-specified, plain y/n, header y/n)

	if {$mystyle ne {}} {
	    set thestyle $mystyle
	} elseif {$myplain} {
	    if {$myheader} {
		set thestyle table/plain
	    } else {
		set thestyle table/plain/nohdr
	    }
	} else {
	    if {$myheader} {
		set thestyle table/borders
	    } else {
		set thestyle table/borders/nohdr
	    }
	}

	set r [report::report [self namespace]::R [M columns] style $thestyle]
	set str [M format 2string $r]
	$r destroy

	return [string trimright $str]
    }

    # # ## ### ##### ######## #############
    ## Internal commands.

    # # ## ### ##### ######## #############
    ## State

    variable myplain myheader mystyle

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################

proc ::cm::table::dict {v script} {
    debug.table {}

    upvar 1 $v t
    variable plain
    set t [uplevel 1 [list ::cm::table/dict new]]
    if {$plain} { $t plain }
    uplevel 1 $script
    return $t
}

oo::class create ::cm::table/dict {
    # # ## ### ##### ######## #############
    superclass ::cm::table

    constructor {} {
	debug.table {}
	next Key Value
	my noheader ;# suppress header row.
	# Keys are the headers (side ways table).
	return
    }

    destructor {}

    # # ## ### ##### ######## #############
    ## API

    # Specialized "add", applies colorization to keys.
    method add {key {value {}}} {
	# Note, we separate leading spaces and indentation from the
	# actual key.  The prefix will not be colored.  Note also that
	# key colorization done by the user will override the color
	# applied here.

	regexp {(^[- ]*)(.*)$} $key -> prefix thekey
	M add row [list $prefix[color heading $thekey] $value]
	return
    }

    # # ## ### ##### ######## #############
    ## Internal commands.

    # # ## ### ##### ######## #############
    ## State - None of its own.

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide cm::table 0
