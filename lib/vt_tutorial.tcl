## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::tutorial 0
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
package require cm::db::tutorial
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export tutorial
    namespace ensemble create
}
namespace eval ::cm::validate::tutorial {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::tutorial
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::tutorial::default  {p}   { return {} }
proc ::cm::validate::tutorial::release  {p x} { return }
proc ::cm::validate::tutorial::validate {p x} {
    switch -exact -- [util match-substr id [tutorial known] 0 $x] {
	ok        { return $id }
	fail      { fail $p TUTORIAL "a tutorial identifier"              $x }
	ambiguous { fail $p TUTORIAL "an unambiguous tutorial identifier" $x }
    }
}

proc ::cm::validate::tutorial::complete {p x} {
    complete-enum [dict keys [tutorial known]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::tutorial 0
return
