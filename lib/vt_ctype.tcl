## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::contact-type 0
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
package require cm::db::contact-type
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export contact-type
    namespace ensemble create
}
namespace eval ::cm::validate::contact-type {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::contact-type
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::contact-type::default  {p}   { return {} }
proc ::cm::validate::contact-type::release  {p x} { return }
proc ::cm::validate::contact-type::validate {p x} {
    switch -exact -- [util match-substr id [contact-type known] nocase $x] {
	ok        { return $id }
	fail      { fail $p CONTACT-TYPE "a contact-type"              $x }
	ambiguous { fail $p CONTACT-TYPE "an unambiguous contact-type" $x }
    }
}

proc ::cm::validate::contact-type::complete {p x} {
    complete-enum [dict keys [contact-type known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::contact-type 0
return
