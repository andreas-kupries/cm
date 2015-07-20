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
    namespace export 2name known setup
    namespace ensemble create

    namespace import ::cm::db
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

cm db setup cm::db::rstatus {
    debug.cm/db/rstatus {}

    if {![dbutil initialize-schema ::cm::db::do error rstatus {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    text	TEXT	NOT NULL UNIQUE
	} {
	    {id		INTEGER 1 {} 1}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error rstatus $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO rstatus VALUES (1,'pending');
	    INSERT OR IGNORE INTO rstatus VALUES (2,'open');
	    INSERT OR IGNORE INTO rstatus VALUES (3,'closed');
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::rstatus 0
return
