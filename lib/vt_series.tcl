## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::series 0
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
package require cm::series
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export series
    namespace ensemble create
}
namespace eval ::cm::validate::series {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::series
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::series::default  {p}   { return {} }
proc ::cm::validate::series::release  {p x} { return }
proc ::cm::validate::series::validate {p x} {
    set known [series known] ;# [validation]

    set lx $x ;#[string tolower $x]
    if {[dict exists $known $lx]} {
	# An exact match is prefered over partials.
	# This resolves where a name is a prefix of something else.
	return [dict get $known $lx]
    }
    
    set matches [complete-enum [dict keys $known] 0 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p SERIES "a series identifier" $x
    }

    # Multiple matches may map to the same id. Conversion required to
    # distinguish between unique/ambiguous.
    set idmatches {}
    foreach m $matches {
	lappend idmatches [dict get $known $m]
    }
    set idmatches [lsort -unique $idmatches]
    set n [llength $idmatches]

    if {$n > 1} {
	fail $p SERIES "an unambigous series identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::series::complete {p x} {
    complete-enum [dict keys [series known]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::series 0
return
