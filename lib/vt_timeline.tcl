## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::timeline 0
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
package require cm::db::timeline
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export timeline
    namespace ensemble create
}
namespace eval ::cm::validate::timeline {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::timeline
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::timeline::default  {p}   { return {} }
proc ::cm::validate::timeline::release  {p x} { return }
proc ::cm::validate::timeline::validate {p x} {
    switch -exact -- [util match-substr id [timeline known] nocase $x] {
	ok        { return $id }
	fail      { fail $p TIMELINE "an event name"             $x }
	ambiguous { fail $p TIMELINE "an unambiguous event name" $x }
    }
}

proc ::cm::validate::timeline::complete {p x} {
    complete-enum [dict keys [timeline known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::timeline 0
return
