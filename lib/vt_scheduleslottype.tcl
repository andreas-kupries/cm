## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## CM - Validation Type - Slot types for schedules.

# @@ Meta Begin
# Package cm::validate::schedule-slot-type 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate

debug level  validate/schedule-slot-type
debug prefix validate/schedule-slot-type {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export schedule-slot-type
    namespace ensemble create
}
namespace eval ::cm::validate::schedule-slot-type {
    namespace export default validate complete release
    namespace ensemble create

    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::cmdr::validate::common::fail-unknown-thing

    variable legalvalues {talk tutorial fixed}
}

proc ::cm::validate::schedule-slot-type::default  {p}   { return {} }
proc ::cm::validate::schedule-slot-type::release  {p x} { return }
proc ::cm::validate::schedule-slot-type::complete {p x} {
    variable legalvalues
    complete-enum $legalvalues 0 $x
}

proc ::cm::validate::schedule-slot-type::validate {p x} {
variable legalvalues
    debug.validate/schedule-slot-type {}

    if {$x in $legalvalues} {
	debug.validate/schedule-slot-type {OK}
	return $x
    }
    debug.validate/schedule-slot-type {FAIL}
    fail-unknown-thing $p SCHEDULE-SLOT-TYPE "slot type" $x
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide cm::validate::schedule-slot-type 0
