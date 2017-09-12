## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::conference 0
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
package require cm::conference
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export conference
    namespace ensemble create
}
namespace eval ::cm::validate::conference {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::conference::default  {p}   { return {} }
proc ::cm::validate::conference::release  {p x} { return }
proc ::cm::validate::conference::validate {p x} {
    set known [conference known] ;# [validation]

    set lx $x ;#[string tolower $x]
    if {[dict exists $known $lx]} {
	# An exact match is prefered over partials.
	# This resolves where a name is a prefix of something else.
	return [dict get $known $lx]
    }
    
    set matches [complete-enum [dict keys $known] 0 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p CONFERENCE "a conference identifier" $x
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
	fail $p CONFERENCE "an unambigous conference identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::conference::complete {p x} {
    complete-enum [dict keys [conference known]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::conference 0
return
