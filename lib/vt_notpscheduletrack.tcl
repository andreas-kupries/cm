## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::notpschedule-track 0
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
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export schedule
    namespace ensemble create
}
namespace eval ::cm::validate::notpschedule-track {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::pschedule
    namespace import ::cmdr::validate::common::fail-known-thing
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::notpschedule-track::default  {p}   { return {} }
proc ::cm::validate::notpschedule-track::complete {p x} { return {} }
proc ::cm::validate::notpschedule-track::release  {p x} { return }
proc ::cm::validate::notpschedule-track::validate {p x} {
    # Reach into the cmd line and pull relevant context
    set pschedule [$p config @schedule]

    set known [pschedule track-known $pschedule]
    set xnorm [string tolower $x]
    if {![dict exists $known $xnorm]} {
	# Note: Returning input as is. Normalization for
	# case-insensitivity happens on storage.
	return $x
    }
    fail-known-thing $p NOT-PSCHEDULE-TRACK "track" $x
}


# # ## ### ##### ######## ############# ######################
package provide cm::validate::notpschedule-track 0
return
