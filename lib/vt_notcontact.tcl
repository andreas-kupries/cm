## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::notcontact 0
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
package require cm::contact
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export notcontact
    namespace ensemble create
}
namespace eval ::cm::validate::notcontact {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::contact
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::notcontact::complete {p x} { return {} }
proc ::cm::validate::notcontact::default  {p}   { return {} }
proc ::cm::validate::notcontact::release  {p x} { return }
proc ::cm::validate::notcontact::validate {p x} {
    set known   [contact known validation]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} { return $x }

    fail $p NOTCONTACT "an unused contact name" $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::notcontact 0
return
