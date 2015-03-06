## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::mail-address 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::validate::common
package require cm::mailer

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::validate {
    namespace export mail-address
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration mail-addresss

namespace eval ::cm::validate::mail-address {
    namespace export release validate default complete \
	internal external all
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::cm::mailer
}

proc ::cm::validate::mail-address::release  {p x} { return }
proc ::cm::validate::mail-address::validate {p x} {
    if {[mailer good-address $x]} {
	return $x
    }
    fail $p MAIL-ADDRESS "email address" $x
}

proc ::cm::validate::mail-address::default  {p}   { return {} }
proc ::cm::validate::mail-address::complete {p x} { return {} }

# # ## ### ##### ######## ############# ######################
package provide cm::validate::mail-address 0
return
