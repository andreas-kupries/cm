## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::attachment 0
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
    namespace export attachment
    namespace ensemble create
}
namespace eval ::cm::validate::attachment {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cm::conference
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

# # ## ### ##### ######## ############# ######################

proc ::cm::validate::attachment::default  {p}   { return {} }
proc ::cm::validate::attachment::release  {p x} { return }
proc ::cm::validate::attachment::validate {p x} {
    set known   [conference known-attachment $p]
    set matches [complete-enum [dict keys $known] 0 $x]

    set n [llength $matches]
    if {!$n} {
	fail $p ATTACHMENT "an attachment identifier" $x
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
	fail $p ATTACHMENT "an unambigous attachment identifier" $x
    }

    # Uniquely identified
    return [lindex $idmatches 0]
}

proc ::cm::validate::attachment::complete {p x} {
    complete-enum [dict keys [conference known-attachment $p]] 1 $x
}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::attachment 0
return
