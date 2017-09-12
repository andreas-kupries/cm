## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::notseries 0
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
package require cm::series
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export notseries
    namespace ensemble create
}
namespace eval ::cm::validate::notseries {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::series
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::notseries::complete {p x} { return {} }
proc ::cm::validate::notseries::default  {p}   { return {} }
proc ::cm::validate::notseries::release  {p x} { return }
proc ::cm::validate::notseries::validate {p x} {
    set known   [series known]
    set matches [complete-enum [dict keys $known] 0 $x]

    set n [llength $matches]
    if {!$n} { return $x }

    fail $p NOTSERIES "an unused series name" $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::notseries 0
return
