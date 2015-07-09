## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::pschedule 0
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
    namespace export pschedule
    namespace ensemble create
}
namespace eval ::cm::validate::pschedule {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::pschedule
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::pschedule::default  {p}   { return {} }
proc ::cm::validate::pschedule::release  {p x} { return }
proc ::cm::validate::pschedule::validate {p x} {
    switch -exact -- [util match-substr id [pschedule known] nocase $x] {
	ok        { return $id }
	fail      { fail $p PSCHEDULE "a schedule name"              $x }
	ambiguous { fail $p PSCHEDULE "an unambiguous schedule name" $x }
    }
}

proc ::cm::validate::pschedule::complete {p x} {
    complete-enum [dict keys [pschedule known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::pschedule 0
return
