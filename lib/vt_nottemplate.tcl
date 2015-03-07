## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::nottemplate 0
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
package require cm::template
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export template
    namespace ensemble create
}
namespace eval ::cm::validate::nottemplate {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::template
    namespace import ::cmdr::validate::common::fail-known-thing
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::nottemplate::default  {p}   { return {} }
proc ::cm::validate::nottemplate::complete {p x} { return {} }
proc ::cm::validate::nottemplate::release  {p x} { return }
proc ::cm::validate::nottemplate::validate {p x} {
    set known [template known]
    if {![dict exists $known $x]} {
	return $x
    }
    fail-known-thing $p NOT-TEMPLATE "template name" $x
}


# # ## ### ##### ######## ############# ######################
package provide cm::validate::nottemplate 0
return
