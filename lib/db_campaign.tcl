## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::campaign 0
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
package require cm::db::template
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export campaign
    namespace ensemble create
}
namespace eval ::cm::db::campaign {
    namespace export \
	new close reset isactive destinations \
	runs runs-of run-create run-reach run-extend \
	drop-email \
	exists for-conference setup
    namespace ensemble create


    namespace import ::cm::db
    namespace import ::cm::db::template
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/campaign
debug prefix cm/db/campaign {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::campaign::new {conference} {
    debug.cm/db/campaign {}
    setup

    db do transaction {
	db do eval {
	    INSERT
	    INTO   campaign
	    VALUES (NULL, :conference, 1)
	}
	set campaign [db do last_insert_rowid]

	db do eval {
	    INSERT
	    INTO   campaign_destination
	    SELECT NULL, :campaign, E.id
	    FROM   email   E,
	           contact C
	    WHERE  E.contact = C.id	-- join
	    AND    C.can_recvmail	-- contact must allow mails
	    AND    NOT E.inactive	-- and mail address must be active too.
	}	

	set new [db do changes]
    }
    return [list $campaign $new]
}

proc ::cm::db::campaign::close {campaign} {
    debug.cm/db/campaign {}
    setup

    db do eval {
	UPDATE campaign
	SET    active = 0
	WHERE  id     = :campaign
    }
    return
}

proc ::cm::db::campaign::reset {campaign} {
    debug.cm/db/campaign {}
    setup

    db do transaction {
	db do eval {
	    DELETE 
	    FROM   campaign_received
	    WHERE  mailrun IN (SELECT mailrun
			       FROM   campaign_mailrun
			       WHERE  campaign = :campaign)
	    ;
	    DELETE 
	    FROM   campaign_mailrun
	    WHERE  campaign = :campaign
	    ;
	    DELETE 
	    FROM   campaign_destination
	    WHERE  campaign = :campaign
	    ;
	    DELETE
	    FROM   campaign
	    WHERE  id = :campaign
	}
    }
    return
}

proc ::cm::db::campaign::destinations {campaign} {
    debug.cm/db/campaign {}
    setup

    return [db do eval {
	SELECT email
	FROM   campaign_destination
	WHERE  campaign = :campaign
    }]
}

proc ::cm::db::campaign::runs {campaign} {
    debug.cm/db/campaign {}
    setup

    return [db do eval {
	SELECT M.id   AS mailrun,
	       M.date AS date,
	       T.name AS name
	FROM   campaign_mailrun M,
	       template         T
	WHERE  M.campaign = :campaign
	AND    M.template = T.id
	ORDER BY date
    }]
}

proc ::cm::db::campaign::runs-of {template} {
    debug.cm/db/campaign {}
    setup

    return [db do eval {
	SELECT date, id AS mailrun
	FROM   campaign_mailrun
	WHERE template = :template
	ORDER BY date
    }]
}

proc ::cm::db::campaign::run-create {campaign template} {
    debug.cm/db/campaign {}
    setup

    set now  [clock seconds]
    db do eval {
	INSERT INTO campaign_mailrun
	VALUES (NULL, :campaign, :template, :now)
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::campaign::run-reach {run} {
    debug.cm/db/campaign {}
    setup

    return [db do eval {
	SELECT email
	FROM   campaign_received
	WHERE  mailrun = :run
    }]
}

proc ::cm::db::campaign::run-extend {run email} {
    debug.cm/db/campaign {}
    setup

    db do eval {
	INSERT
	INTO   campaign_received
	VALUES (NULL, :run, :email)
    }
    return
}

proc ::cm::db::campaign::drop-email {campaign email} {
    debug.cm/db/campaign {}
    setup

    db do eval {
	DELETE
	FROM  campaign_destination
	WHERE campaign = :campaign
	AND   email    = :email
    }
    return
}

proc ::cm::db::campaign::exists {conference} {
    debug.cm/db/campaign {}
    setup

    return [db do exists {
	SELECT id
	FROM campaign
	WHERE con = :conference
    }]
}

proc ::cm::db::campaign::for-conference {conference} {
    debug.cm/db/campaign {}
    setup

    return [db do onecolumn {
	SELECT id
	FROM   campaign
	WHERE  con = :conference
    }]
}

proc ::cm::db::campaign::isactive {campaign} {
    debug.cm/db/campaign {}
    setup

    return [db do onecolumn {
	SELECT active
	FROM   campaign
	WHERE  id = :campaign
    }]
}

proc ::cm::db::campaign::setup {} {
    debug.cm/db/campaign {}

    #::cm::contact::Setup -- contact calls on campaign -- kill cycle
    template setup

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
	db setup-error campaign $error
    }

    if {![dbutil initialize-schema ::cm::db::do error campaign_destination {
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
	db setup-error campaign_destination $error
    }

    if {![dbutil initialize-schema ::cm::db::do error campaign_mailrun {
	{
	    -- Mailings executed so far

	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    campaign	INTEGER	NOT NULL REFERENCES campaign,
	    template	INTEGER NOT NULL REFERENCES template,	-- mail text template
	    date	INTEGER NOT NULL			-- timestamp [epoch]
	} {
	    {id		INTEGER 1 {} 1}
	    {campaign	INTEGER 1 {} 0}
	    {template	INTEGER 1 {} 0}
	    {date	INTEGER 1 {} 0}
	} {campaign template}
    }]} {
	db setup-error campaign_mailrun $error
    }

    if {![dbutil initialize-schema ::cm::db::do error campaign_received {
	{
	    -- The addresses which received mailings. In case of a repeat mailing
	    -- for a template this information is used to prevent sending mail to
	    -- destinations which already got it.

	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    mailrun	INTEGER	NOT NULL REFERENCES campaign_mailrun,
	    email	INTEGER	NOT NULL REFERENCES email	-- under contact
	} {
	    {id		INTEGER 1 {} 1}
	    {mailrun	INTEGER 1 {} 0}
	    {email	INTEGER 1 {} 0}
	} {mailrun}
    }]} {
	db setup-error campaign_received $error
    }

    # Shortcircuit further calls
    proc ::cm::db::campaign::setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::campaign 0
return
