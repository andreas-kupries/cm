## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::rstatus 0
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
package require dbutil
package require debug
package require debug::caller
package require try

package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export rstatus
    namespace ensemble create
}
namespace eval ::cm::db::rstatus {
    namespace export 2name known
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/rstatus
debug prefix cm/db/rstatus {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::rstatus::2name {type} {
    debug.cm/db/rstatus {}
    setup

    return [db do onecolumn {
	SELECT text
	FROM   rstatus
	WHERE  id = :type
    }]
}

proc ::cm::db::rstatus::known {} {
    debug.cm/db/rstatus {}
    setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   rstatus
    } {
	# nocase, assumes lower-case strings in "text".
	dict set known $text $id
    }

    debug.cm/db/rstatus {==> ($known)}
    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::rstatus::setup {} {
    debug.cm/db/rstatus {}

    # Shortcircuit further calls
    proc ::cm::db::rstatus::setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::rstatus 0
return
