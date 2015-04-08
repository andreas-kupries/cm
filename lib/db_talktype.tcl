## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::talk-type 0
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
    namespace export talk-type
    namespace ensemble create
}
namespace eval ::cm::db::talk-type {
    namespace export 2name known
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/talk-type
debug prefix cm/db/talk-type {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::talk-type::2name {type} {
    debug.cm/db/talk-type {}
    Setup

    return [db do onecolumn {
	SELECT text
	FROM   talk_type
	WHERE  id = :type
    }]
}

proc ::cm::db::talk-type::known {} {
    debug.cm/db/talk-type {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   talk_type
    } {
	dict set known $text $id
    }

    debug.cm/db/talk-type {==> ($known)}
    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::talk-type::setup {} {
    debug.cm/db/talk-type {}

    if {![dbutil initialize-schema ::cm::db::do error talk_type {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error talk_type $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO talk_type VALUES (1,'invited');
	    INSERT OR IGNORE INTO talk_type VALUES (2,'submitted');
	    INSERT OR IGNORE INTO talk_type VALUES (3,'keynote');
	    INSERT OR IGNORE INTO talk_type VALUES (4,'panel');
	}
    }

    # Shortcircuit further calls
    proc ::cm::db::talk-type::setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::talk-type 0
return
