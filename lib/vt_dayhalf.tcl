## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::dayhalf 0
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
package require cm::db::dayhalf
package require cm::util
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export dayhalf
    namespace ensemble create
}
namespace eval ::cm::validate::dayhalf {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::db::dayhalf
    namespace import ::cm::util
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::dayhalf::default  {p}   { return {} }
proc ::cm::validate::dayhalf::release  {p x} { return }
proc ::cm::validate::dayhalf::validate {p x} {
    switch -exact -- [util match-substr id [dayhalf known] nocase $x] {
	ok        { return $id }
	fail      { fail $p DAYHALF "a dayhalf identifier"              $x }
	ambiguous { fail $p DAYHALF "an unambiguous dayhalf identifier" $x }
    }
}

proc ::cm::validate::dayhalf::complete {p x} {
    complete-enum [dict keys [dayhalf known]] nocase $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::dayhalf 0
return
