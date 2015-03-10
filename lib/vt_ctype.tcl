## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::contact-type 0
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
    namespace export contact-type
    namespace ensemble create
}
namespace eval ::cm::validate::contact-type {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::contact
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::contact-type::default  {p}   { return {} }
proc ::cm::validate::contact-type::release  {p x} { return }
proc ::cm::validate::contact-type::validate {p x} {
    set known   [contact known-type]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p CONTACT-TYPE "a contact-type" $x
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
	fail $p CONTACT-TYPE "an unambigous contact-type" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::contact-type::complete {p x} {
    complete-enum [dict keys [contact known-type]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::contact-type 0
return
