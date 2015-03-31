## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::city 0
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
package require cm::city
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export city
    namespace ensemble create
}
namespace eval ::cm::validate::city {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::city
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::city::default  {p}   { return {} }
proc ::cm::validate::city::release  {p x} { return }
proc ::cm::validate::city::validate {p x} {
    set known   [city known-validation]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p CITY "a city identifier" $x
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
	fail $p CITY "an unambigous city identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::city::complete {p x} {
    complete-enum [dict keys [city known-validation]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::city 0
return
