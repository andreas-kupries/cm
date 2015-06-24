## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::pschedule-track 0
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
    namespace export pschedule-track
    namespace ensemble create
}
namespace eval ::cm::validate::pschedule-track {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::pschedule
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::pschedule-track::default  {p}   { return {} }
proc ::cm::validate::pschedule-track::release  {p x} { return }
proc ::cm::validate::pschedule-track::validate {p x} {
    # Reach into the cmd line and pull relevant context
    set pschedule [$p config @schedule]
    switch -exact -- [util match-substr id [pschedule track-known $pschedule] nocase $x] {
	ok        { return $id }
	fail      { fail $p PSCHEDULE-TRACK "a track name"              $x }
	ambiguous { fail $p PSCHEDULE-TRACK "an unambiguous track name" $x }
    }
}

proc ::cm::validate::pschedule-track::complete {p x} {
    # Reach into the cmd line and pull relevant context
    set pschedule [$p config @schedule]
    complete-enum [dict keys [pschedule track-known $pschedule]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::pschedule-track 0
return
