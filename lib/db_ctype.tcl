## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::contact-type 0
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
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::db::contact-type {
    namespace export 2name known
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/contact-type
debug prefix cm/db/contact-type {[debug caller] | }

# # ## ### ##### ######## ############# ######################

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::db::contact-type::2name {ctype} {
    debug.cm/db/contact-type {}
    setup

    return [db do onecolumn {
	SELECT text
	FROM   contact_type
	WHERE  id = :ctype
    }]
}

proc ::cm::db::contact-type::known {} {
    debug.cm/db/contact-type {}
    setup

    set known {}

    db do eval {
	SELECT id, text
	FROM   contact_type
    } {
	dict set known [string tolower $text] $id
    }

    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact-type::setup {} {
    debug.cm/db/contact-type {}

    if {![dbutil initialize-schema ::cm::db::do error contact_type {
	{
	    id	 INTEGER NOT NULL PRIMARY KEY,
	    text TEXT    NOT NULL UNIQUE
	} {
	    {id   INTEGER 1 {} 1}
	    {text TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error contact_type $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO contact_type VALUES (1,'Person');
	    INSERT OR IGNORE INTO contact_type VALUES (2,'Company');
	    INSERT OR IGNORE INTO contact_type VALUES (3,'Mailinglist');
	}
    }

    # Shortcircuit further calls
    proc ::cm::db::contact-type::setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::contact-type 0
return
