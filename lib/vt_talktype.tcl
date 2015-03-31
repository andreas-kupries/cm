## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::talk-type 0
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
package require cm::conference
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export talk-type
    namespace ensemble create
}
namespace eval ::cm::validate::talk-type {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::talk-type::default  {p}   { return {} }
proc ::cm::validate::talk-type::release  {p x} { return }
proc ::cm::validate::talk-type::validate {p x} {
    set known   [conference known-talk-type]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p TALK-TYPE "a talk type" $x
    }

    # Multiple matches may map to the same id. Conversion required to
    # distinguish between unique/ambiguous.
    set idmatches {}
    foreach m $matches {
	lappend idmatches [dict get $known $m]
    }
    set idmatches [lsort -unique $idmatches]
    set n [llength $idmatches]

    if {$n > 1} {
	fail $p TALK-TYPE "an unambigous talk type" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::talk-type::complete {p x} {
    complete-enum [dict keys [conference known-talk-type]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::talk-type 0
return
