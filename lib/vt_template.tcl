## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::template 0
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
namespace eval ::cm::validate::template {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::template
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::template::release  {p x} { return }
proc ::cm::validate::template::default  {p} { return {} }

proc ::cm::validate::template::validate {p x} {
    set known [template known]
    if {[dict exists $known $x]} {
	return [dict get $known $x]
    }
    fail $p TEMPLATE "a template name" $x
}

proc ::cm::validate::template::complete {p} {
    complete-enum [dict keys [template known]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::template 0
return
