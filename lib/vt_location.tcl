## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::location 0
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
package require cm::db::location
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export location
    namespace ensemble create
}
namespace eval ::cm::validate::location {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::location
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::location::default  {p}   { return {} }
proc ::cm::validate::location::release  {p x} { return }
proc ::cm::validate::location::validate {p x} {
    switch -exact -- [util match-substr id [location known] 0 $x] {
	ok        { return $id }
	fail      { fail $p LOCATION "a location name"              $x }
	ambiguous { fail $p LOCATION "an unambiguous location name" $x }
    }
}

proc ::cm::validate::location::complete {p x} {
    complete-enum [dict keys [location known]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::location 0
return
