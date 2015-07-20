## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::talk-state 0
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

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export talk-state
    namespace ensemble create
}
namespace eval ::cm::db::talk-state {
    namespace export 2name known setup
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/talk-state
debug prefix cm/db/talk-state {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::talk-state::2name {state} {
    debug.cm/db/talk-state {}
    setup

    return [db do onecolumn {
	SELECT text
	FROM   talk_state
	WHERE  id = :state
    }]
}

proc ::cm::db::talk-state::known {} {
    debug.cm/db/talk-state {}
    setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   talk_state
    } {
	# nocase, assumes lower-case strings in "text".
	dict set known $text $id
    }

    debug.cm/db/talk-state {==> ($known)}
    return $known
}

# # ## ### ##### ######## ############# ######################

cm db setup cm::db::talk-state {
    debug.cm/db/talk-state {}

    if {![dbutil initialize-schema ::cm::db::do error talk_state {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error talk_state $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO talk_state VALUES (1,'pending');
	    INSERT OR IGNORE INTO talk_state VALUES (2,'received');
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::talk-state 0
return
