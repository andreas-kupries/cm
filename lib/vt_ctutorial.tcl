## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::ctutorial 0
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
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export ctutorial
    namespace ensemble create
}
namespace eval ::cm::validate::ctutorial {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::tutorial
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::ctutorial::default  {p}   { return {} }
proc ::cm::validate::ctutorial::release  {p x} { return }
proc ::cm::validate::ctutorial::validate {p x} {
    switch -exact -- [util match-substr id [tutorial known-scheduled [cm::conference::current]] 0 $x] {
	ok        { return $id }
	fail      { fail $p TUTORIAL "a tutorial identifier"              $x }
	ambiguous { fail $p TUTORIAL "an unambiguous tutorial identifier" $x }
    }
}

proc ::cm::validate::ctutorial::complete {p x} {
    complete-enum [dict keys [tutorial known-scheduled [cm::conference::current]]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::ctutorial 0
return
