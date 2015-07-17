## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::location-staff 0
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
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export location-staff
    namespace ensemble create
}
namespace eval ::cm::validate::location-staff {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::location
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::location-staff::default  {p}   { return {} }
proc ::cm::validate::location-staff::release  {p x} { return }
proc ::cm::validate::location-staff::validate {p x} {
    switch -exact -- [util match-substr id [location known-staff] 0 $x] {
	ok        { return $id }
	fail      { fail $p LOCATION-STAFF "a staff name"              $x }
	ambiguous { fail $p LOCATION-STAFF "an unambiguous staff name" $x }
    }
}

proc ::cm::validate::location-staff::complete {p x} {
    complete-enum [dict keys [location known-staff]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::location-staff 0
return
