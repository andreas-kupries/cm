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
package require struct::matrix
package require report

::report::defstyle table/table {} {
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

::report::defstyle table/noheader {} {
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

::report::defstyle table/html {} {
    data	set [split "<tr><td> [string repeat "</td><td> " [expr {[columns]-1}]]</td></tr>"]
    #top		set <table>
    #bottom	set </table>
    #top		enable
    #bottom	enable
    return
}

namespace eval ::cm::table {
    namespace export do
}

# # ## ### ##### ######## ############# #####################

proc ::cm::table::do {v headings script} {
    upvar 1 $v t
    set t [uplevel 1 [list ::cm::table new {*}$headings]]
    uplevel 1 $script
    return $t
}

oo::class create ::cm::table {
    # # ## ### ##### ######## #############

    constructor {args} {
	struct::matrix [self namespace]::M
	M add columns [llength $args]
	M add row $args
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

    method show {{cmd puts}} {
	uplevel 1 [list {*}$cmd [my String]]
	my destroy
	return
    }

    method show* {{cmd puts}} {
	uplevel 1 [list {*}$cmd [my String]]
	return
    }

    method plain {} {
	set myplain 1
	return
    }

    method style {style} {
	set mystyle $style
	return
    }

    method noheader {} {
	if {!$myheader} return
	set myheader 0
	M delete row 0
	return
    }

    method String {} {
	if {$mystyle ne {}} {
	    set r [report::report [self namespace]::R [M columns] style $mystyle]
	    set str [M format 2string $r]
	    $r destroy
	} elseif {$myplain} {
	    set str [M format 2string]
	} elseif {$myheader} {
	    set r [report::report [self namespace]::R [M columns] style table/table]
	    set str [M format 2string $r]
	    $r destroy
	} else {
	    set r [report::report [self namespace]::R [M columns] style table/noheader]
	    set str [M format 2string $r]
	    $r destroy
	}
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
## Ready
package provide cm::table 0
