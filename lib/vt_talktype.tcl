## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::talk-type 0
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
package require cm::db::talk-type
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export talk-type
    namespace ensemble create
}
namespace eval ::cm::validate::talk-type {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::talk-type
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::talk-type::default  {p}   { return {} }
proc ::cm::validate::talk-type::release  {p x} { return }
proc ::cm::validate::talk-type::validate {p x} {
    switch -exact -- [util match-substr id [talk-type known] nocase $x] {
	ok        { return $id }
	fail      { fail $p TALK-TYPE "a talk-type"              $x }
	ambiguous { fail $p TALK-TYPE "an unambiguous talk-type" $x }
    }
}

proc ::cm::validate::talk-type::complete {p x} {
    complete-enum [dict keys [talk-type known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::talk-type 0
return
