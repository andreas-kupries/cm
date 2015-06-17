## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::ctutorial 0
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
package require cm::tutorial
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export ctutorial
    namespace ensemble create
}
namespace eval ::cm::validate::ctutorial {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::tutorial
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::ctutorial::default  {p}   { return {} }
proc ::cm::validate::ctutorial::release  {p x} { return }
proc ::cm::validate::ctutorial::validate {p x} {
    set known   [tutorial scheduled [cm::conference::current]]
    set matches [complete-enum [dict keys $known] 0 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p TUTORIAL "a tutorial identifier" $x
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
	fail $p TUTORIAL "an unambigous tutorial identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::ctutorial::complete {p x} {
    complete-enum [dict keys [tutorial scheduled [cm::conference::current]]] 0 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::ctutorial 0
return
