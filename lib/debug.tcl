## -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package cm::debug 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require debug

package require cm::table

# # ## ### ##### ######## #############

namespace eval ::cm {
    namespace export debug
    namespace ensemble create
}
namespace eval ::cm::debug {
    namespace export levels
    namespace ensemble create

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## #############

proc ::cm::debug::levels {config} {
    # First ensure that all possible cm packages are loaded, so that
    # all possible debug levels are declared and known.

    #package require cm::
    package require cm::table
    package require cm::validate::colormode

    package require cmdr::tty
    package require cmdr::color
    package require cmdr::ask

    [table t {Level} {
	foreach level [lsort -dict [debug names]]  {
	    $t add $level
	}
    }] show
    return
}

# # ## ### ##### ######## #############
package provide cm::debug 0
