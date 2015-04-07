## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::staff-role 0
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
package require cm::db::staffrole
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export staff-role
    namespace ensemble create
}
namespace eval ::cm::validate::staff-role {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::staffrole
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::staff-role::default  {p}   { return {} }
proc ::cm::validate::staff-role::release  {p x} { return }
proc ::cm::validate::staff-role::validate {p x} {
    switch -exact -- [util match-substr id [staffrole known] nocase $x] {
	ok        { return $id }
	fail      { fail $p STAFF-ROLE "a staff role"              $x }
	ambiguous { fail $p STAFF-ROLE "an unambiguous staff role" $x }
    }
}

proc ::cm::validate::staff-role::complete {p x} {
    complete-enum [dict keys [staffrole known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::staff-role 0
return
