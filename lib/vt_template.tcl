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
package require cm::db::template
package require cm::util
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

    namespace import ::cm::db::template
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::template::default  {p}   { return {} }
proc ::cm::validate::template::release  {p x} { return }
proc ::cm::validate::template::validate {p x} {
    switch -exact -- [util match-substr id [template known] 0 $x] {
	ok        { return $id }
	fail      { fail $p TEMPLATE "a template name"              $x }
	ambiguous { fail $p TEMPLATE "an unambiguous template name" $x }
    }
}

proc ::cm::validate::template::complete {p x} {
    complete-enum [dict keys [template known]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::template 0
return
