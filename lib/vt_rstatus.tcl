## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::rstatus 0
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
package require cm::db::rstatus
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export rstatus
    namespace ensemble create
}
namespace eval ::cm::validate::rstatus {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::rstatus
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::rstatus::default  {p}   { return {} }
proc ::cm::validate::rstatus::release  {p x} { return }
proc ::cm::validate::rstatus::validate {p x} {
    switch -exact -- [util match-substr id [rstatus known] nocase $x] {
	ok        { return $id }
	fail      { fail $p RSTATUS "a registration status"              $x }
	ambiguous { fail $p RSTATUS "an unambiguous registration status" $x }
    }
}

proc ::cm::validate::rstatus::complete {p x} {
    complete-enum [dict keys [rstatus known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::rstatus 0
return
