## -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package cm::atexit 0
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

debug level  cm/atexit
debug prefix cm/atexit {[debug caller] | }

# # ## ### ##### ######## #############

namespace eval ::cm {
    namespace export atexit
    namespace ensemble create
}
namespace eval ::cm::atexit {
    namespace export add
    namespace ensemble create
}

# # ## ### ##### ######## #############

proc ::cm::atexit::add {cmdprefix} {
    debug.cm/atexit {}
    variable handlers
    lappend  handlers $cmdprefix
    return
}

proc ::cm::atexit::Exit {args} {
    debug.cm/atexit {}
    variable ::cm::atexit::handlers
    foreach cmd $handlers {
	debug.cm/atexit {=> $cmd}
	catch {
	    uplevel #0 $cmd
	}
    }
    set handlers {}
    ::cm::atexit::Exit.orig {*}$args
}

# # ## ### ##### ######## #############
## Hook into process exit.

namespace eval ::cm::atexit {
    variable handlers {}
}

rename ::exit             ::cm::atexit::Exit.orig
rename ::cm::atexit::Exit ::exit

# # ## ### ##### ######## #############

package provide cm::atexit 0
