## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::talk 0
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
    namespace export talk
    namespace ensemble create
}
namespace eval ::cm::validate::talk {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::talk::default  {p}   { return {} }
proc ::cm::validate::talk::release  {p x} { return }
proc ::cm::validate::talk::validate {p x} {
    set known   [conference known-talks-vt]
    set matches [complete-enum [dict keys $known] 0 $x]
    # TODO: use a "complete-substring" match

    set n [llength $matches]
    if {!$n} {
	fail $p TALK "an accepted submission identifier" $x
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
	fail $p TALK "an unambigous talk identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::talk::complete {p x} {
    complete-enum [dict keys [conference known-talks-vt]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::talk 0
return
