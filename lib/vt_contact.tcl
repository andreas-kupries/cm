## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::contact 0
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
package require cm::db::contact
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::validate::contact {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::contact
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::contact::default  {p}   { return {} }
proc ::cm::validate::contact::release  {p x} { return }
proc ::cm::validate::contact::validate {p x} {
    switch -exact -- [util match-substr id [contact known] nocase $x] {
	ok        { return $id }
	fail      { fail $p CONTACT "a contact identifier"              $x }
	ambiguous { fail $p CONTACT "an unambiguous contact identifier" $x }
    }
}

proc ::cm::validate::contact::complete {p x} {
    complete-enum [dict keys [contact known]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::contact 0
return
