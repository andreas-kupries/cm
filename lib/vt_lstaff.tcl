## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::location-staff 0
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
package require cm::location
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export location-staff
    namespace ensemble create
}
namespace eval ::cm::validate::location-staff {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::location
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::location-staff::default  {p}   { return {} }
proc ::cm::validate::location-staff::release  {p x} { return }
proc ::cm::validate::location-staff::validate {p x} {
    set known   [location known-staff]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p LOCATION-STAFF "a staff name" $x
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
	fail $p LOCATION-STAFF "an unambigous staff name" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::location-staff::complete {p x} {
    complete-enum [dict keys [location known-staff]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::location-staff 0
return
