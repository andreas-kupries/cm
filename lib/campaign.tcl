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
package require cmdr::validate::date
package require cmdr::table
package require debug
package require debug::caller
package require dbutil
package require try
package require struct::set

package provide cm::campaign 0 ;# contact and campaign are circular

package require cm::conference
package require cm::contact
package require cm::db
package require cm::mailer
package require cm::mailgen
package require cm::template
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export campaign
    namespace ensemble create
}
namespace eval ::cm::campaign {
    namespace export cmd_setup cmd_close cmd_status cmd_mail \
	cmd_test cmd_reset cmd_drop \
	add-mail drop-mail get-for
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cmdr::validate::date

    namespace import ::cm::conference
    namespace import ::cm::contact
    namespace import ::cm::db
    namespace import ::cm::mailer
    namespace import ::cm::mailgen
    namespace import ::cm::template
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
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
	set campaign [db do last_insert_rowid]

	db do eval {
	    INSERT INTO campaign_destination
	      SELECT NULL, :campaign, E.id
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


proc ::cm::campaign::cmd_reset {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [get-for $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    if {![ask yn "Campaign \"[color name $clabel]\" [color bad RESET]" no]} {
	puts [color note Aborted]
	return
    }

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

    puts [color good OK]
    return
}

proc ::cm::campaign::cmd_status {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [get-for $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    puts "Campaign \"[color name $clabel]\" status"

    # 1. Mailings performed ... when, template, #destinations
    # 2. Destinations in campaign vs destinations in mailings.

    set destinations [db do eval {
	SELECT email
	FROM   campaign_destination
	WHERE  campaign = :campaign
    }]

    puts "Destinations: [llength $destinations]"
    debug.cm/campaign {destinations = ($destinations)}

    puts "Runs:"
    [table t {When Template Reached Unreached} {
	db do eval {
	    SELECT M.id   AS mailrun,
	           M.date AS date,
	           T.name AS name
	    FROM   campaign_mailrun M,
	           template         T
	    WHERE  M.campaign = :campaign
	    AND    M.template = T.id
	    ORDER BY date
	} {
	    #set when [date 2external $date] ;# -- No -- full timestamp! below
	    set date [clock format $date -format {%Y-%m-%d %H:%M:%S}]

	    set reached [db do eval {
		SELECT email
		FROM   campaign_received
		WHERE  mailrun = :mailrun
	    }]
	    debug.cm/campaign {run $mailrun reached   = ($reached)}

	    set unreached [struct::set difference \
			       $destinations $reached]

	    debug.cm/campaign {run $mailrun unreached = ($unreached)}

	    set unreached [llength $unreached]
	    set reached   [llength $reached]

	    debug.cm/campaign {run $mailrun $reached/$unreached}

	    if {$unreached} {
		set unreached [color bad $unreached]
	    }

	    debug.cm/campaign {run $mailrun $reached/$unreached}

	    $t add $date $name $reached $unreached
	}
    }] show

    return
}

proc ::cm::campaign::cmd_mail {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [get-for $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![isactive $campaign]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    set template [$config @template]
    set tname    [template get $template]


    puts "Campaign \"[color name $clabel]\" run with template \"[color name $tname]\" ..."

    set destinations [db do eval {
	SELECT email
	FROM   campaign_destination
	WHERE  campaign = :campaign
    }]

    puts "Destinations: [llength $destinations]"
    debug.cm/campaign {destinations = ($destinations)}

    # Check for preceding runs with the same template, take their receivers, and drop them from the set of destinations. No duplicate delivery!

    db do eval {
	SELECT date, id AS mailrun
	FROM   campaign_mailrun
	WHERE template = :template
	ORDER BY date
    } {
	set date [clock format $date -format {%Y-%m-%d %H:%M:%S}]

	set reached [db do eval {
	    SELECT email
	    FROM   campaign_received
	    WHERE  mailrun = :mailrun
	}]
	debug.cm/campaign {reached      = ($reached)}

	set destinations [struct::set difference \
			      $destinations $reached]
	debug.cm/campaign {not reached  = ($destinations)}

	puts "Run $date reached [llength $reached], leaving [llength $destinations]"
    }

    if {![llength $destinations]} {
	puts "[color note {No destinations left}]."
	return
    } else {
	puts "Addressing:   [llength $destinations]"
    }

    set text [template details $template]
    set now  [clock seconds]

    set issues [check-template $text]
    if {$issues ne {}} {
	puts $issues
	if {![ask yn "Continue with mail run ?" no]} {
	    puts [color note Aborted]
	    return
	}
    }

    # TODO: Check template for necessary/important placeholders.
    # TODO: Warn about any missing.
    set text [conference insert $conference $text]

    db do eval {
	INSERT INTO campaign_mailrun
	VALUES (NULL, :campaign, :template, :now)
    }
    set run [db do last_insert_rowid]

    set mconfig [mailer get-config]
    mailer batch receiver address name $destinations {
	# Insert address and name into the template

	puts "To: $name [color name $address]"

	if 1 {
	    #TODO: non-dry
	    mailer send $mconfig \
		[list $address] \
		[mailgen call $address $name $text] \
		0 ;# not verbose
	}

	db do eval {
	    INSERT INTO campaign_received
	    VALUES (NULL, :run, :receiver)
	}
    }
    return
}

proc ::cm::campaign::cmd_test {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [get-for $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![isactive $campaign]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    set template [$config @template]
    set tname    [template get $template]


    puts "Campaign \"[color name $clabel]\" run with template \"[color name $tname]\" ..."

    set text   [template details $template]
    set issues [check-template $text]

    set text [conference insert $conference $text]
    set text [mailgen call "test@example.com" Tester $text]

    puts $text

    if {$issues ne {}} {
	puts =======================
	puts $issues
    }
    return
}

proc ::cm::campaign::cmd_drop {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [get-for $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![isactive $campaign]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    puts "Campaign \"[color name $clabel]\" dropping ..."

    foreach email [$config @entry] {
	puts -nonewline "* [color name [contact get-email $email]] ... "
	flush stdout

	db do eval {
	    DELETE
	    FROM  campaign_destination
	    WHERE campaign = :campaign
	    AND   email = :email
	}
	puts "[color good OK]"
    }

    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::campaign::check-template {text} {
    debug.cm/campaign {}
    set issues {}
    foreach {rq placeholder} {
	0 mg:sender
	0 mg:name
	1 h:hotel
	1 h:city
	1 h:street
	1 c:name
	1 c:city
	1 c:year
	1 c:start
	1 c:end
	1 c:when
	1 c:talklength
	1 c:contact
	0 c:sponsors
	0 c:committee
	1 c:t:wipopen
	1 c:t:submitdead
	1 c:t:authornote
	1 c:t:writedead
	1 c:t:begin-t
	1 c:t:begin-s
    } {
	if {[string match *@${placeholder}@* $text]} continue
	if {$rq} {
	    set msg "  [color bad Required]  placeholder \"$placeholder\" [color bad missing]"
	} else {
	    set msg "  Suggested placeholder \"$placeholder\" missing"
	}
	lappend issues $msg
    }
    return [join $issues \n]
}

proc ::cm::campaign::drop-mail {email} {
    debug.cm/campaign {}
    Setup

    # Drop existing mail from all active campaigns.

    db do eval {
	DELETE
	FROM  campaign_destination
	WHERE email = :email
	AND   campaign IN (SELECT id
			   FROM   campaign
			   WHERE  active)
    }
    return
}

proc ::cm::campaign::add-mail {email} {
    debug.cm/campaign {}
    Setup

    # Add a new email id to all active campaigns.

    db do eval {
	INSERT
	INTO   campaign_destination
	  SELECT NULL, id, :email
	  FROM   campaign
	  WHERE  active
    }
    return
}

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
    proc ::cm::campaign::Setup {args} {}
    return
}


proc ::cm::campaign::Dump {conference} {
    debug.cm/campaign {}
    ::cm::conference::Setup
    ::cm::contact::Setup
    ::cm::template::Setup

    # campaign             (id, ^con,      active)
    # campaign_destination (id, ^campaign, ^email) -- contact.email
    # campaign_mailrun     (id, ^campaign, ^template, date)
    # campaign_received    (id, ^mailrun,  ^email) -- contact.email

    # -- cm has no bulk load commands. Only commands performing the
    #    campaign and auto-loading the tables.
    #
    # campaign setup -> (campaign + destination)
    #      ... mail  -> (mailrun + received)

    db do eval {
	SELECT id, active
	FROM   campaign
	WHERE  con = :conference
    } {
	cm dump step
	if {$active} {
	    cm dump save campaign setup --empty
	} else {
	    cm dump save campaign setup --empty --inactive
	}

	# Destinations for the campaign. Explicitly loaded.
	db do eval {
	    SELECT E.email AS email
	    FROM   campaign_destination D
	    ,      email                E
	    WHERE  D.campaign = :id
	    AND    D.email    = E.id
	    ORDER BY E.email
	} {
	    cm dump save \
		campaign destination $email
	}

	# Mail runs. Explicitly loaded.
	db do eval {
	    SELECT M.id   AS rid
	    ,      M.date AS date
	    ,      T.name AS tname
	    FROM   campaign_mailrun M
	    ,      template         T
	    WHERE  M.campaign = :id
	    AND    M.template = T.id
	    ORDER BY date
	} {
	    cm dump step
	    cm dump save \
		campaign mail $tname --at $date ;# implies empty!

	    # Mail run receivers
	    db do eval {
		SELECT E.email AS email
		FROM   campaign_received R
		,      email             E
		WHERE R.mailrun = :rid
		AND   R.email   = E.id
		ORDER BY E.email
	    } {
		cm dump save \
		    campaign received $date $email
	    }
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::campaign 0
return
