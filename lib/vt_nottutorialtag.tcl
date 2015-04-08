## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::nottutorialtag 0
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
namespace eval ::cm::validate::nottutorialtag {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::tutorial
    namespace import ::cmdr::validate::common::fail-known-thing
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::nottutorialtag::default  {p}   { return {} }
proc ::cm::validate::nottutorialtag::complete {p x} { return {} }
proc ::cm::validate::nottutorialtag::release  {p x} { return }
proc ::cm::validate::nottutorialtag::validate {p x} {
    set known [tutorial known-tag [$p config @speaker]]
    if {![dict exists $known $x]} {
	return $x
    }
    fail-known-thing $p NOT-TUTORIAL-TAG "tutorial tag" $x
}


# # ## ### ##### ######## ############# ######################
package provide cm::validate::nottutorialtag 0
return
