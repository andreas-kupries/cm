## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::schedule-slot 0
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
package require cm::db::schedule
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export schedule-slot
    namespace ensemble create
}
namespace eval ::cm::validate::schedule-slot {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::schedule
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::schedule-slot::default  {p}   { return {} }
proc ::cm::validate::schedule-slot::release  {p x} { return }
proc ::cm::validate::schedule-slot::validate {p x} {
    # Reach into the cmd line and pull relevant context
    set conference [cm::conference::current]
    switch -exact -- [util match-substr id [schedule known $conference] 0 $x] {
	ok        { return $id }
	fail      { fail $p SCHEDULE-SLOT "a slot name"              $x }
	ambiguous { fail $p SCHEDULE-SLOT "an unambiguous slot name" $x }
    }
}

proc ::cm::validate::schedule-slot::complete {p x} {
    # Reach into the cmd line and pull relevant context
    set pschedule [$p config @schedule]
    complete-enum [dict keys [pschedule track-known $pschedule]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::schedule-slot 0
return
