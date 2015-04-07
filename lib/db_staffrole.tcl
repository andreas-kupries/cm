## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::conference 0
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
package require try

package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export conference
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export staffrole
    namespace ensemble create
}
namespace eval ::cm::db::staffrole {
    namespace export 2name select known setup
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/staffrole
debug prefix cm/db/staffrole {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::staffrole::2name {role} {
    debug.cm/db/staffrole {}
    setup

    return [db do onecolumn {
	SELECT text
	FROM   staff_role
	WHERE  id = :role
    }]
}

proc ::cm::db::staffrole::known {} {
    debug.cm/db/staffrole {}
    setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   staff_role
    } {
	dict set known [string tolower $text] $id
    }

    debug.cm/db/staffrole {==> ($known)}
    return $known
}

proc ::cm::db::staffrole::select {p} {
    debug.cm/db/staffrole {}
    return [util select $p "staff role" Selection]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::staffrole::Selection {} {
    debug.cm/db/staffrole {}
    setup

    # dict: label -> id
    set selection {}

    db do eval {
	SELECT id, text
	FROM   staff_role
    } {
	dict set selection $text $id
    }

    debug.cm/db/staffrole {==> ($selection)}
    return $selection
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::staffrole::setup {} {
    debug.cm/db/staffrole {}

    if {![dbutil initialize-schema ::cm::db::do error staff_role {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    text	TEXT	NOT NULL UNIQUE	-- chair, facilities chair, program chair, program committee,
						-- web admin, proceedings editor, hotel liason, ...
	} {
	    {id		INTEGER 1 {} 1}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error staff_role $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO staff_role VALUES (1,'Chair');
	    INSERT OR IGNORE INTO staff_role VALUES (2,'Facilities chair');
	    INSERT OR IGNORE INTO staff_role VALUES (3,'Program chair');
	    INSERT OR IGNORE INTO staff_role VALUES (4,'Program committee');
	    INSERT OR IGNORE INTO staff_role VALUES (5,'Hotel liaison');
	    INSERT OR IGNORE INTO staff_role VALUES (6,'Web admin');
	    INSERT OR IGNORE INTO staff_role VALUES (7,'Proceedings editor');
	}
    }

    # Shortcircuit further calls
    proc ::cm::db::staffrole::setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::staffrole 0
return
