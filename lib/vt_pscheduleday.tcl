## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::pschedule-day 0
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
package require cm::db::pschedule
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export pschedule-day
    namespace ensemble create
}
namespace eval ::cm::validate::pschedule-day {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::pschedule
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::pschedule-day::default  {p}   { return {} }
proc ::cm::validate::pschedule-day::release  {p x} { return }
proc ::cm::validate::pschedule-day::validate {p x} {
    # Reach into the cmd line and pull relevant context
    set pschedule [$p config @schedule]

    set max [pschedule day-max $pschedule]

    if {![string is integer -strict $x] || ($x < 0) || ($x > $max)} {
	set label [expr { !$max
			  ? "a day (== 0)"
			  : "a day (in 0..$max)" }]
	fail $p PSCHEDULE-DAY $label $x
    }
    return $x
}

proc ::cm::validate::pschedule-day::complete {p x} {
    # No completion
    return {}
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::pschedule-day 0
return
