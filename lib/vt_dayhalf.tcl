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
package require cm::tutorial
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

    namespace import ::cm::tutorial
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::dayhalf::default  {p}   { return {} }
proc ::cm::validate::dayhalf::release  {p x} { return }
proc ::cm::validate::dayhalf::validate {p x} {
    set known   [tutorial known-half]
    set matches [complete-enum [dict keys $known] 1 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p DAYHALF "a dayhalf identifier" $x
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
	fail $p DAYHALF "an unambigous dayhalf identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::dayhalf::complete {p x} {
    complete-enum [dict keys [tutorial known-half]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::dayhalf 0
return
