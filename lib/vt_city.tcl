## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::city 0
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
package require cm::db::city
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export city
    namespace ensemble create
}
namespace eval ::cm::validate::city {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::city
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::city::default  {p}   { return {} }
proc ::cm::validate::city::release  {p x} { return }
proc ::cm::validate::city::validate {p x} {
    switch -exact -- [util match-substr id [city known] nocase $x] {
	ok        { return $id }
	fail      { fail $p CITY "a city name"              $x }
	ambiguous { fail $p CITY "an unambiguous city name" $x }
    }
}

proc ::cm::validate::city::complete {p x} {
    complete-enum [dict keys [city known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::city 0
return
