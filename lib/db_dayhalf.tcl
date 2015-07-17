## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::dayhalf 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta db::dayhalf    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require cmdr::color
package require cmdr::ask
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export dayhalf
    namespace ensemble create
}
namespace eval ::cm::db::dayhalf {
    namespace export 2name known setup
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/dayhalf
debug prefix cm/db/dayhalf {[debug caller] | }

# # ## ### ##### ######## ############# ######################
##

proc ::cm::db::dayhalf::known {} {
    debug.cm/db/dayhalf {}
    setup

    set known {}

    db do eval {
	SELECT id, text
	FROM   dayhalf
    } {
	dict set known $text $id
    }

    debug.cm/db/dayhalf {==> ($known)}
    return $known
}

proc ::cm::db::dayhalf::2name {dayhalf} {
    debug.cm/db/dayhalf {}
    setup

    return [db do onecolumn {
	SELECT text
	FROM   dayhalf
	WHERE  id = :dayhalf
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::dayhalf::setup {} {
    debug.cm/db/dayhalf {}

    if {![dbutil initialize-schema ::cm::db::do error dayhalf {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error dayhalf $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO dayhalf VALUES (1,'morning');
	    INSERT OR IGNORE INTO dayhalf VALUES (2,'afternoon');
	    INSERT OR IGNORE INTO dayhalf VALUES (3,'evening');
	}
    }

    # Shortcircuit further calls
    proc ::cm::db::dayhalf::setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::dayhalf 0
return
