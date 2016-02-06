## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::pvisible 0
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
    namespace export pvisible
    namespace ensemble create
}
namespace eval ::cm::validate::pvisible {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::pvisible::default  {p}   { return {} }
proc ::cm::validate::pvisible::release  {p x} { return }
proc ::cm::validate::pvisible::validate {p x} {
    set known   [conference known-pvisible]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p PVISIBLE "a visibility status" $x
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
	fail $p PVISIBLE "an unambigous visbility status" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::pvisible::complete {p x} {
    complete-enum [dict keys [conference known-pvisible]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::pvisible 0
return
