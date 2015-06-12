## -*- tcl -*-
# # ## ### ##### ######## ############# ######################
## CM - Validation Type - Paper and other submissions.

# @@ Meta Begin
# Package cm::validate::submission 0
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
## Requisites

package require Tcl 8.5
package require cm::conference
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################
## Definition

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export submission
    namespace ensemble create
}
namespace eval ::cm::validate::submission {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::submission::default  {p}   { return {} }
proc ::cm::validate::submission::release  {p x} { return }
proc ::cm::validate::submission::validate {p x} {
    set known   [conference known-submissions-vt]
    set matches [complete-enum [dict keys $known] 0 $x]
    # TODO: use a "complete-substring" match

    set n [llength $matches]
    if {!$n} {
	fail $p SUBMISSION "a submission identifier" $x
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
	fail $p SUBMISSION "an unambigous submission identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::submission::complete {p x} {
    complete-enum [dict keys [conference known-submissions-vt]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::submission 0
return
