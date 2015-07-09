## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::schedule-slot-value 0
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

# Talk, Tutorial validation
package require cm::validate::talk
package require cm::validate::ctutorial

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export schedule-slot-value
    namespace ensemble create
}
namespace eval ::cm::validate::schedule-slot-value {
    namespace export release validate default complete
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::schedule-slot-value::default  {p}   { return {} }
proc ::cm::validate::schedule-slot-value::release  {p x} { return }
proc ::cm::validate::schedule-slot-value::validate {p x} {

    set type [$p config @type]
    switch -exact -- $type {
	talk     { return [cm::validate::talk      validate $p $x] }
	tutorial { return [cm::validate::ctutorial validate $p $x] }
	fixed    { return $x }
    }
}

proc ::cm::validate::schedule-slot-value::complete {p x} { return {} }
# FUTURE: complete by type.

# # ## ### ##### ######## ############# ######################
package provide cm::validate::schedule-slot-value 0
return
