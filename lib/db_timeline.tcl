## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::timeline 0
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
    namespace export timeline
    namespace ensemble create
}
namespace eval ::cm::db::timeline {
    namespace export 2name 2key known select setup
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/timeline
debug prefix cm/db/timeline {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::timeline::2name {event} {
    debug.cm/db/timeline {}
    setup

    return [db do onecolumn {
	SELECT text
	FROM   timeline_type
	WHERE  id = :event
    }]
}

proc ::cm::db::timeline::2key {event} {
    debug.cm/db/timeline {}
    setup

    return [db do onecolumn {
	SELECT key
	FROM   timeline_type
	WHERE  id = :event
    }]
}

proc ::cm::db::timeline::known {} {
    debug.cm/db/timeline {}
    setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   timeline_type
    } {
	# nocase, assumes lower-case strings in "key".
	dict set known $key                   $id
	dict set known [string tolower $text] $id
    }

    debug.cm/db/timeline {==> ($known)}
    return $known
}

proc ::cm::db::timeline::select {p} {
    debug.cm/db/timeline {}
    return [util select $p event Selection]
}

proc ::cm::db::timeline::Selection {} {
    debug.cm/db/timeline {}
    setup

    # dict: label -> id
    set selection {}

    db do eval {
	SELECT id, text
	FROM   timeline_type
    } {
	dict set selection $text $id
    }

    debug.cm/db/timeline {==> ($selection)}
    return $selection
}

# # ## ### ##### ######## ############# ######################

cm db setup ::cm::db::timeline {
    debug.cm/db/timeline {}

    if {![dbutil initialize-schema ::cm::db::do error timeline_type {
	{
	    -- The possible types of action items in the conference timeline
	    -- public items are for use within mailings, the website, etc.
	    -- internal items are for the mgmt only.
	    -- the offset [in days] is used to compute the initial proposal
	    -- of a timeline for the conference. 

	    id		INTEGER NOT NULL PRIMARY KEY,
	    ispublic	INTEGER NOT NULL,
	    offset	INTEGER NOT NULL,	-- >0 => days after conference start
	    					-- <0 => days before start
	    key		TEXT    NOT NULL UNIQUE,	-- internal key for the type
	    text	TEXT    NOT NULL UNIQUE		-- human-readable
	} {
	    {id		INTEGER 1 {} 1}
	    {ispublic	INTEGER 1 {} 0}
	    {offset	INTEGER 1 {} 0}
	    {key	TEXT    1 {} 0}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error timeline_type $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO timeline_type VALUES ( 1,0,-196,'cfp1',      '1st Call for papers');         --  -28w (--)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 2,0,-140,'cfp2',      '2nd Call for papers');         --  -20w (8w) (~2m)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 3,0, -84,'cfp3',      '3rd Call for papers');         --  -12w (8w) (~2m)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 4,1, -84,'wipopen',   'WIP & BOF Reservations open'); --  -12w
	    INSERT OR IGNORE INTO timeline_type VALUES ( 5,1, -56,'submitdead','Submissions due');             --   -8w (4w) (~1m)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 6,1, -56,'regopen',   'Registration opens');          --   -8w same
	    INSERT OR IGNORE INTO timeline_type VALUES ( 7,1, -49,'authornote','Notifications to Authors');    --   -7w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 8,1, -21,'writedead', 'Author Materials due');        --   -3w (4w)+1w grace
	    INSERT OR IGNORE INTO timeline_type VALUES ( 9,0, -14,'procedit',  'Edit proceedings');            --   -2w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES (10,0,  -7,'procship',  'Ship proceedings');            --   -1w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES (11,1,   0,'begin-t',   'Tutorial Start');              --  <=>
	    INSERT OR IGNORE INTO timeline_type VALUES (12,1,   2,'begin-s',   'Session Start');               --  +2d
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::timeline 0
return
