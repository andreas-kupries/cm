## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::enum 0
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
package require debug
package require debug::caller
package require dbutil

package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export enum
    namespace ensemble create
}
namespace eval ::cm::enum {
    namespace export
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/enum
debug prefix cm/enum {[debug caller] | }

# # ## ### ##### ######## ############# ######################

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::enum::Setup {} {
    debug.cm/enum {}

    # Shortcircuit further calls
    proc ::cm::enum::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::enum 0
return
