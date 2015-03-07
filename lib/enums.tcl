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

    if {![dbutil initialize-schema ::cm::db::do error dayhalf {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error dayhalf $error DAYHALF
    } else {
	db do eval {
	    INSERT OR IGNORE INTO dayhalf VALUES (1,'morning');
	    INSERT OR IGNORE INTO dayhalf VALUES (2,'afternoon');
	    INSERT OR IGNORE INTO dayhalf VALUES (3,'evening');
	}
    }

    if {![dbutil initialize-schema ::cm::db::do error talk_type {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error talk_type $error TALK_TYPE
    } else {
	db do eval {
	    INSERT OR IGNORE INTO talk_type VALUES (1,'invited');
	    INSERT OR IGNORE INTO talk_type VALUES (2,'submitted');
	    INSERT OR IGNORE INTO talk_type VALUES (3,'keynote');
	    INSERT OR IGNORE INTO talk_type VALUES (4,'panel');
	}
    }

    if {![dbutil initialize-schema ::cm::db::do error talk_state {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error talk_state $error TALK_STATE
    } else {
	db do eval {
	    INSERT OR IGNORE INTO talk_state VALUES (1,'pending');
	    INSERT OR IGNORE INTO talk_state VALUES (2,'received');
	}
    }

    if {![dbutil initialize-schema ::cm::db::do error staff_role {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error staff_role $error STAFF_ROLE
    } else {
	db do eval {
	    INSERT OR IGNORE INTO staff_role VALUES (1,'chair');
	    INSERT OR IGNORE INTO staff_role VALUES (2,'facilities chair');
	    INSERT OR IGNORE INTO staff_role VALUES (3,'program chair');
	    INSERT OR IGNORE INTO staff_role VALUES (4,'program committee');
	    INSERT OR IGNORE INTO staff_role VALUES (5,'hotel liaison');
	    INSERT OR IGNORE INTO staff_role VALUES (6,'web admin');
	    INSERT OR IGNORE INTO staff_role VALUES (7,'proceedings editor');
	}
    }

    # Shortcircuit further calls
    proc ::cm::enum::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::enum 0
return
