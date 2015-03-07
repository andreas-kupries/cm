## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::campaign 0
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
package require cmdr::color
package require cmdr::ask
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::conference
package require cm::contact
package require cm::template
package require cm::db
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export campaign
    namespace ensemble create
}
namespace eval ::cm::campaign {
    namespace export cmd_setup cmd_close cmd_status cmd_mail cmd_drop
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::util
    namespace import ::cm::db
    namespace import ::cm::conference
    namespace import ::cm::contact
    namespace import ::cm::template

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/campaign
debug prefix cm/campaign {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::campaign::cmd_setup {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set id [get-for $conference]
    if {$id ne {}} {
	if {[isactive $id]} {
	    util user-error "Conference \"$clabel\" already has an active campaign" \
		CAMPAIGN ALREADY ACTIVE
	} else {
	    util user-error "Conference \"$clabel\" has a closed campaign" \
		CAMPAIGN ALREADY CLOSED
	}
    }

    # No campaign for the conference, set it up now.

    db do transaction {
	puts -nonewline "Creating campaign \"[color name $clabel]\" ... "
	flush stdout

	db do eval {
	    INSERT INTO campaign
	    VALUES (NULL, :conference, 1)
	}
	set id [db do last_insert_rowid]

	db do eval {
	    INSERT INTO campaign_item
	      SELECT NULL, :id, E.id
	      FROM   email   E,
	             contact C
	      WHERE  E.contact = C.id	-- join
	      AND    C.can_recvmail	-- contact must allow mails
	      AND    NOT E.inactive	-- and mail address must be active too.
	}	

	set new [db do changes]
	if {!$new} {
	    util user-error "Failed, empty" CAMPAIGN EMPTY
	}

	puts "[color good OK] ($new entries)"
    }
    return
}

proc ::cm::campaign::cmd_close {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set id [get-for $conference]
    if {$id eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    puts -nonewline "Closing campaign \"[color name $clabel]\" ... "
    flush stdout

    if {[isactive $id]} {
	db do eval {
	    UPDATE campaign
	    SET    active = 0
	    WHERE  id = :id
	}
    }

    puts "[color good OK]"
    return
}

proc ::cm::campaign::cmd_status {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set id [get-for $conference]
    if {$id eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    puts "Campaign \"[color name $clabel]\" status"

    TODO ... Table ...

    return
}


proc ::cm::campaign::cmd_mail {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set id [get-for $conference]
    if {$id eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![isactive $id]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    puts "Campaign \"[color name $clabel]\" mailing ..."

    TODO ... get template ... run mailer ...

    return
}


proc ::cm::campaign::cmd_drop {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set id [get-for $conference]
    if {$id eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![isactive $id]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    puts "Campaign \"[color name $clabel]\" dropping ..."

    TODO: map addresses to entries, remove, save

    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::campaign::has-for {conference} {
    debug.cm/campaign {}
    Setup

    return [db do exists {
	SELECT id
	FROM campaign
	WHERE con = :conference
    }]
}

proc ::cm::campaign::get-for {conference} {
    debug.cm/campaign {}
    Setup

    return [db do onecolumn {
	SELECT id
	FROM   campaign
	WHERE  con = :conference
    }]
}

proc ::cm::campaign::isactive {id} {
    debug.cm/campaign {}
    Setup

    return [db do onecolumn {
	SELECT active
	FROM   campaign
	WHERE  id = :id
    }]
}

proc ::cm::campaign::Setup {} {
    debug.cm/campaign {}
    ::cm::conference::Setup
    ::cm::contact::Setup
    ::cm::template::Setup

    if {![dbutil initialize-schema ::cm::db::do error campaign {
	{
	    -- Email campaign for a conference.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    con	 	INTEGER NOT NULL UNIQUE	REFERENCES conference,	-- one campaign per conference only
	    active	INTEGER NOT NULL				-- flag
	} {
	    {id		INTEGER 1 {} 1}
	    {con	INTEGER 1 {} 0}
	    {active	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error campaign $error CAMPAIGN
    }

    if {![dbutil initialize-schema ::cm::db::do error campaign_item {
	{
	    -- Destination addresses for the campaign

	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    campaign	INTEGER	NOT NULL REFERENCES campaign,
	    email	INTEGER NOT NULL REFERENCES email,	-- contact is indirect
	    UNIQUE (campaign,email)
	} {
	    {id		INTEGER 1 {} 1}
	    {campaign	INTEGER 1 {} 0}
	    {email	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error campaign_item $error CAMPAIGN_ITEM
    }

    if {![dbutil initialize-schema ::cm::db::do error campaign_mail {
	{
	    -- Mailings executed so far

	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    campaign	INTEGER	NOT NULL REFERENCES campaign,
	    template	INTEGER NOT NULL REFERENCES template	-- mail text template
	} {
	    {id		INTEGER 1 {} 1}
	    {campaign	INTEGER 1 {} 0}
	    {template	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error campaign_mail $error CAMPAIGN_MAIL
    }

    # Shortcircuit further calls
    proc ::cm::campaign::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::campaign 0
return
