## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::contact 0
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
package require cm::contact
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::validate::contact {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::contact
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::contact::default  {p}   { return {} }
proc ::cm::validate::contact::release  {p x} { return }
proc ::cm::validate::contact::validate {p x} {
    set known   [contact known validation]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p CONTACT "a contact identifier" $x
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
	fail $p CONTACT "an unambigous contact identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::contact::complete {p x} {
    complete-enum [dict keys [contact known validation]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::contact 0
return
