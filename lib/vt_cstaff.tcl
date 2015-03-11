## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::conference-staff 0
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
    namespace export conference-staff
    namespace ensemble create
}
namespace eval ::cm::validate::conference-staff {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::conference-staff::default  {p}   { return {} }
proc ::cm::validate::conference-staff::release  {p x} { return }
proc ::cm::validate::conference-staff::validate {p x} {
    set known   [conference known-staff]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p CONFERENCE-STAFF "a staff name" $x
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
	fail $p CONFERENCE-STAFF "an unambigous staff name" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::conference-staff::complete {p x} {
    complete-enum [dict keys [conference known-staff]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::conference-staff 0
return
