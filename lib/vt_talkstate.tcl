## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::talk-state 0
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
package require cm::db::talk-state
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export talk-state
    namespace ensemble create
}
namespace eval ::cm::validate::talk-state {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::talk-state
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::talk-state::default  {p}   { return {} }
proc ::cm::validate::talk-state::release  {p x} { return }
proc ::cm::validate::talk-state::validate {p x} {
    switch -exact -- [util match-substr id [talk-state known] nocase $x] {
	ok        { return $id }
	fail      { fail $p TALK-STATE "a talk-state"              $x }
	ambiguous { fail $p TALK-STATE "an unambiguous talk-state" $x }
    }
}

proc ::cm::validate::talk-state::complete {p x} {
    complete-enum [dict keys [talk-state known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::talk-state 0
return
