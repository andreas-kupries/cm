## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::contact 0
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
package require cm::db::campaign
package require cm::db::contact-type
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::db::contact {
    namespace export \
	relations-formatted \
	email= emails email-count email-addrs email-addrs+state links \
	affiliation representatives affiliated represents merge \
	all disable-email squash-email type= name= recv= tag= bio= \
        add-mails add-links new-mail new-link \
	new-mlist new-company new-person \
	has-mlist has-company has-person \
	find-mlist find-company find-person \
	add-affiliation add-representative \
	drop-affiliation drop-representative \
	2name 2name-plain 2name-email get the-link label \
	\
	select label known known-email 
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::db::campaign
    namespace import ::cm::db::contact-type
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/contact
debug prefix cm/db/contact {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::relations-formatted {contact type} {
    debug.cm/db/contact {}

    if {$type != 1} {
	# representatives/liaisons
	set related [dict values [representatives $contact]]
	if {[llength $related]} {
	    # Hanging indent, TODO utility command
	    set other [lassign $related primary]
	    set related "Rep: $primary"
	    if {[llength $other]} {
		append related \n [util indent [join $other \n] "   : "]
	    }
	}
    } else {
	# affiliations
	set related [dict values [affiliations $contact]]
	if {[llength $related]} {
	    # Hanging indent, TODO utility command
	    set other [lassign $related primary]
	    set related "Of: $primary"
	    if {[llength $other]} {
		append related \n [util indent [join $other \n] "  : "]
	    }
	}
    }

    return $related
}

proc ::cm::db::contact::emails {} {
    debug.cm/db/contact {}
    setup

    return [db do eval {
	SELECT id, email
	FROM   email
    }]
}

proc ::cm::db::contact::email-count {contact} {
    debug.cm/db/contact {}
    setup

    return [db do onecolumn {
	SELECT count(id)
	FROM   email
	WHERE  contact = :contact
    }]
}

proc ::cm::db::contact::email-addrs {contact} {
    debug.cm/db/contact {}
    setup

    return [db do eval {
	SELECT email
	FROM   email
	WHERE  contact = :contact
	ORDER BY email
    }]
}

proc ::cm::db::contact::email-addrs+state {contact} {
    debug.cm/db/contact {}
    setup

    return [db do eval {
	SELECT email, inactive
	FROM   email
	WHERE  contact = :contact
	ODER BY email
    }]
}

proc ::cm::db::contact::links {contact} {
    debug.cm/db/contact {}
    setup

    return [db do eval {
	SELECT link
	FROM   link
	WHERE  contact = :contact
	ORDER BY link
    }]
}

proc ::cm::db::contact::affiliations {contact} {
    debug.cm/db/contact {}
    setup

    # Affiliations. Expected for persons, to list companies, their,
    # well, affiliations
    return [db do eval {
	SELECT C.id, C.dname
	FROM   contact     C,
	       affiliation A
	WHERE  A.person  = :contact
	AND    A.company = C.id
	ORDER BY C.dname
    }]
}

proc ::cm::db::contact::representatives {contact} {
    debug.cm/db/contact {}
    setup

    # Liaisons. Expected for companies, to list persons, their
    # representatives
    return [db do eval {
	SELECT C.id, C.dname
	FROM   contact C,
	       liaison L
	WHERE  L.company = :contact
	AND    L.person = C.id
	ORDER BY C.dname
    }]
}

proc ::cm::db::contact::affiliated {contact} {
    debug.cm/db/contact {}
    setup

    # Reverse affiliations. Expected for companies, to list persons,
    # the affiliated
    return [db do eval {
	SELECT C.id, C.dname
	FROM   contact     C,
	       affiliation A
	WHERE  A.company = :contact
	AND    A.person  = C.id
	ORDER BY C.dname
    }]
}

proc ::cm::db::contact::represents {contact} {
    debug.cm/db/contact {}
    setup

    # Reverse liaisons. Expected for persons, to list the companies
    # they represent
    return [db do eval {
	SELECT C.id, C.dname
	FROM   contact C,
	       liaison L
	WHERE  L.person  = :contact
	AND    L.company = C.id
	ORDER BY C.dname
    }]
}

proc ::cm::db::contact::all {pattern} {
    debug.cm/db/contact {}
    setup

    return [db do eval {
	    SELECT C.id           AS contact,
	           C.tag          AS tag,
	           C.dname        AS name,
	           C.type         AS typecode,
	           CT.text        AS type,
	           C.can_recvmail AS crecv,
	    	   C.can_register AS creg,
	    	   C.can_book     AS cbook,
	    	   C.can_talk     AS ctalk,
	    	   C.can_submit   AS csubm
	    FROM  contact      C,
	          contact_type CT
	    WHERE (C.name  GLOB :pattern
	     OR    C.dname GLOB :pattern)
	    AND   CT.id = C.type
	    ORDER BY name
    }]
}

proc ::cm::db::contact::email= {email addr} {
    debug.cm/db/contact {}
    setup

    db do eval {
	UPDATE email
	SET    email = :addr
	WHERE  id    = :email
    }
    return
}

proc ::cm::db::contact::disable-email {email} {
    debug.cm/db/contact {}
    setup

    db do transaction {
	# set inactive
	db do eval {
	    UPDATE email
	    SET inactive = 1
	    WHERE id = :email
	    ;

	    -- See also recv=
	    DELETE
	    FROM  campaign_destination
	    WHERE email    = :email
	    AND   campaign IN (SELECT id
			       FROM   campaign
			       WHERE  active)
	} 
    }
    return
}

proc ::cm::db::contact::squash-email {email} {
    debug.cm/db/contact {}
    setup

    db do transaction {
	# Drop all references, i.e. campaigns.
	db do eval {
	    DELETE
	    FROM   campaign_destination
	    WHERE  email = :email
	    ;
	    DELETE
	    FROM   campaign_received
	    WHERE  email = :email
	    ;
	    DELETE
	    FROM   email
	    WHERE  id = :email
	    ;
	} 
    }
    return
}

proc ::cm::db::contact::type= {contact type} {
    debug.cm/db/contact {}
    setup

    db do transaction {
	db do eval {
	    UPDATE contact
	    SET    type = :type
	    WHERE  id   = :contact
	}

	# wish for more dynamic behaviour here
	switch -exact -- $type {
	    1 { # Person
		db do eval {
		    UPDATE contact
		    SET    can_register = 1,
		    can_book     = 1,
		    can_talk     = 1,
		    can_submit   = 1
		    WHERE id = :contact
		}
	    }
	    2 { # Company
		db do eval {
		    UPDATE contact
		    SET    can_register = 0,
		    can_book     = 0,
		    can_talk     = 0,
		    can_submit   = 1
		    WHERE id = :contact
		}
	    }
	    3 { # Mailing list
		db do eval {
		    UPDATE contact
		    SET    can_register = 0,
		    can_book     = 0,
		    can_talk     = 0,
		    can_submit   = 0
		    WHERE id = :contact
		}
	    }
	}
    }
    return
}

proc ::cm::db::contact::name= {contact name} {
    debug.cm/db/contact {}
    setup

    set lower [string tolower $name]
    db do eval {
	UPDATE contact
	SET    name  = :lower,
	       dname = :name
	WHERE  id    = :contact
    }
    return
}

proc ::cm::db::contact::merge {primary secondary} {
    debug.cm/db/contact {}
    setup

    # Redirect all references to the secondary contact to the
    # primary, namely:
    #
    # - email.contact
    # - link.contact
    # - affiliation.person
    # - affiliation.company
    # - liaison.person
    # - liaison.company
    #
    # Note: There is no need to update campaigns as emails are
    # neither added/enabled nor removed/disabled.
    #
    # Note 2: All status flags, and other data from the secondary
    # are voided, and not transfered to the primary.

    db do transaction {
	db do eval {
	    UPDATE email
	    SET    contact = :primary
	    WHERE  contact = :secondary
	    ;
	    UPDATE link
	    SET    contact = :primary
	    WHERE  contact = :secondary
	    ;
	    UPDATE affiliation
	    SET    person = :primary
	    WHERE  person = :secondary
	    ;
	    UPDATE affiliation
	    SET    company = :primary
	    WHERE  company = :secondary
	    ;
	    UPDATE liaison
	    SET    person = :primary
	    WHERE  person = :secondary
	    ;
	    UPDATE liaison
	    SET    company = :primary
	    WHERE  company = :secondary
	    ;
	    DELETE
	    FROM   contact
	    WHERE  id = :secondary
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::issues {details} {
    debug.cm/db/contact {}
    dict with details {}

    #XXX
    # tutorial setup

    set issues {}

    set tutorials [db do eval {
	SELECT count(*)
	FROM   tutorial
	WHERE  speaker = :xid
    }]

    if {$tutorials} {
	if {$xbiography eq {}} {
	    +issue "Biography missing, used by tutorials"
	}
	if {$xtag eq {}} {
	    +issue "Tag missing, used by tutorials"
	}
    }

    if {![llength $issues]} return
    return [join $issues \n]
}

proc ::cm::db::contact::+issue {text} {
    debug.cm/db/contact {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::add-mails {contact addrlist} {
    debug.cm/db/contact {}
    foreach emailaddr $addrlist {
	new-mail $contact [string trim $emailaddr]
    }
    return
}

proc ::cm::db::contact::add-links {contact linklist} {
    debug.cm/db/contact {}
    foreach link $linklist {
	new-link $contact [string trim $link]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::new-mlist {dname} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $dname]
    db do eval {
	INSERT INTO contact
	VALUES (NULL, NULL,             -- id, tag
		3, :name, :dname,	-- mailing list, name, dname
		NULL,			-- no initial bio
		1,0,0,0,0)              -- can flags
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::contact::new-company {dname} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $dname]
    db do eval {
	INSERT INTO contact
	VALUES (NULL, NULL,             -- id, tag
		2, :name, :dname,	-- company, name, dname
		NULL,			-- no initial bio
		1,0,0,0,1)              -- can flags

	-- TODO/Note: talker for a company submission should have company affiliation.
	-- TODO/Note: Not forbidden to not have affiliation, but worth a warning.
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::contact::new-person {dname} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $dname]
    db do eval {
	INSERT INTO contact
	VALUES (NULL, NULL,             -- id, tag
		1, :name, :dname,	-- type (person), name, dname
		NULL,			-- no initial bio
		1,1,1,1,1)              -- can flags
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::contact::new-mail {contact mailaddr} {
    debug.cm/db/contact {}
    setup

    # Mail addresses are handled -nocase by the mail system. Store
    # them in a canonical form to have a sensible uniqueness.
    set mailaddr [string tolower $mailaddr]

    db do transaction {
	db do eval {
	    INSERT INTO email
	    VALUES (NULL, :mailaddr, :contact, 0)
	}
	set email [db do last_insert_rowid]

	# See also recv=
	db do eval {
	    INSERT
	    INTO   campaign_destination
	    SELECT NULL, id, :email
	    FROM   campaign
	    WHERE  active
	}
    }
    return $email
}

proc ::cm::db::contact::new-link {contact link} {
    debug.cm/db/contact {}
    setup

    db do eval {
	INSERT INTO link
	VALUES (NULL, :contact, :link, '')
    }
    return [db do last_insert_rowid]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::recv= {contact enable} {
    debug.cm/db/contact {}
    setup

    db do transaction {
	db do eval {
	    UPDATE contact
	    SET    can_recvmail = :enable
	    WHERE  id           = :contact
	}

	if {$enable} {
	    # Add the active mails of the contact to all active campaigns.

	    db do eval {
		SELECT id AS email
		FROM   email
		WHERE  contact = :contact
		AND    NOT inactive
	    } {
		db do eval {
		    INSERT
		    INTO   campaign_destination
		    SELECT NULL, id, :email
		    FROM   campaign
		    WHERE  active
		}
	    }
	} else {
	    # Remove all emails of the contact from all active campaigns.
	    db do eval {
		DELETE
		FROM  campaign_destination
		WHERE email    IN (SELECT id
				   FROM   email
				   WHERE  contact = :contact)
		AND   campaign IN (SELECT id
				   FROM   campaign
				   WHERE  active)
	    }
	}
    }
    return
}

proc ::cm::db::contact::tag= {contact tag} {
    debug.cm/db/contact {}
    setup

    db do eval {
	UPDATE contact
	SET    tag = :tag
	WHERE  id  = :contact
    }
    return
}

proc ::cm::db::contact::bio= {contact bio} {
    debug.cm/db/contact {}
    setup

    db do eval {
	UPDATE contact
	SET    biography = :bio
	WHERE  id        = :contact
    }
    return
}

proc ::cm::db::contact::add-affiliation {contact affiliation} {
    debug.cm/db/contact {}
    setup

    db do eval {
	INSERT
	INTO affiliation
	VALUES (NULL, :contact, :affiliation)
    }
    return
}

proc ::cm::db::contact::add-representative {contact liaison} {
    debug.cm/db/contact {}
    setup

    db do eval {
	INSERT
	INTO liaison
	VALUES (NULL, :contact, :liaison)
    }
    return
}

proc ::cm::db::contact::drop-affiliation {contact affiliation} {
    debug.cm/db/contact {}
    setup

    db do eval {
	DELETE
	FROM affiliation
	WHERE person  = :contact
	AND   company = :affiliation
    }
    return
}

proc ::cm::db::contact::drop-representative {contact liaison} {
    debug.cm/db/contact {}
    setup

    db do eval {
	DELETE
	FROM liaison
	WHERE company = :contact
	AND   person  = :liaison
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::has-mlist {name} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $name]
    return [db do exists {
	SELECT id
	FROM   contact
	WHERE  type = 3		-- mailing list
	AND    name = :name
    }]
}

proc ::cm::db::contact::has-company {name} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $name]
    return [db do exists {
	SELECT id
	FROM   contact
	WHERE  type = 2		-- company
	AND    name = :name
    }]
}

proc ::cm::db::contact::has-person {name} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $name]
    return [db do exists {
	SELECT id
	FROM   contact
	WHERE  type = 1		-- person
	AND    name = :name
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::find-mlist {name} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $name]
    return [db do onecolumn {
	SELECT id
	FROM   contact
	WHERE  type = 3		-- mailing list
	AND    name = :name
    }]
}

proc ::cm::db::contact::find-company {name} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $name]
    return [db do onecolumn {
	SELECT id
	FROM   contact
	WHERE  type = 2		-- company
	AND    name = :name
    }]
}

proc ::cm::db::contact::find-person {name} {
    debug.cm/db/contact {}
    setup

    set name [string tolower $name]
    return [db do onecolumn {
	SELECT id
	FROM   contact
	WHERE  type = 1		-- person
	AND    name = :name
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::contact::2name-email {id} {
    debug.cm/db/contact {}
    setup

    return [db do onecolumn {
	SELECT email
	FROM   email
	WHERE  id = :id
    }]
}

proc ::cm::db::contact::2name {id} {
    debug.cm/db/contact {}
    setup

    lassign [db do eval {
	SELECT tag, dname
	FROM   contact
	WHERE  id = :id
    }] tag name

    return [label $tag $name]
}

proc ::cm::db::contact::2name-plain {id} {
    debug.cm/db/contact {}
    setup

    return [db do onecolumn {
	SELECT dname
	FROM   contact
	WHERE  id = :id
    }]
}

proc ::cm::db::contact::the-link {id} {
    debug.cm/db/contact {}
    set links [lsort -dict [links $id]]
    if {![llength $links]} return
    return [lindex $links 0]
}

proc ::cm::db::contact::get {id} {
    debug.cm/db/contact {}
    setup

    return [db do eval {
	SELECT 'xid',           id,
               'xtag',          tag,
               'xtype',         type,
	       'xname',         name,
	       'xdname',        dname,
	       'xbiography',    biography,
	       'xcan_recvmail', can_recvmail,
	       'xcan_register', can_register,
	       'xcan_book',     can_book,
	       'xcan_talk',     can_talk,
	       'xcan_submit',   can_submit
	FROM  contact
	WHERE id = :id
    }]
}

proc ::cm::db::contact::label {tag name} {
    debug.cm/db/contact {}

    if {$tag ne {}} { append label "(@" $tag ") " }
    append label $name
    return $label
}


XXXXXXXXXXXXXXXXXXXXX

proc ::cm::db::contact::KnownSelect {} {
    debug.cm/db/contact {}

    # dict: label -> id
    set known [KnownSelectLimited {}]

    # Cache result
    proc ::cm::db::contact::KnownSelect {} [list return $known]
    return $known
}

proc ::cm::db::contact::KnownSelectLimited {limit} {
    debug.cm/db/contact {}
    setup

    # dict: label -> id
    set known {}

    set sql {
	SELECT id, tag, dname
	FROM   contact
    }
    if {[llength $limit]} {
	set slimit [join $limit ,]
	append sql " WHERE id IN ($slimit)"
    }

    db do eval $sql {
	dict set known $dname $id
    }

    return $known
}

proc ::cm::db::contact::KnownValidate {} {
    debug.cm/db/contact {}

    set known [KnownLimited {}]

    # Cache result
    proc ::cm::db::contact::KnownValidate {} [list return $known]
    return $known
}

proc ::cm::db::contact::KnownLimited {limit} {
    debug.cm/db/contact {}
    setup

    # dict: label -> id
    set known {}

    # Pull basics into an 'id'-indexed map.

    # id + name/dname + list of links, emails
    # we know that 'name' is unique
    # it follows that 'dname' is unique as well
    # (Because 2 non-unique dnames would map to the same 'name' and thus violate its uniqueness.
    #
    # emails are unique, and have unique contacts.
    # links are possibly not unique.

    set map {}

    # Identification by name, tag
    set sql {SELECT id, tag, name, dname FROM contact}
    if {[llength $limit]} {
	set slimit [join $limit ,]
	append sql " WHERE id IN ($slimit)"
    }
    db do eval $sql {
	if {$tag ne {}} {
	    dict lappend map $id $tag @$tag
	}
	set in [util initials $name]
	set il [string tolower $in]

	#puts "|$id -- $tag|$name|$dname|$in|"

	dict lappend map $id $name
	dict lappend map $id $dname
	dict lappend map $id "$il $name"
	dict lappend map $id "$in $dname"
    }

    # Identification by email
    set sql {SELECT contact, email FROM email}
    if {[llength $limit]} {
	append sql " WHERE contact IN ($slimit)"
    }
    db do eval $sql {
	dict lappend map $contact $email
	dict lappend map $contact [string tolower $email]
    }

    # Identification by link (TODO: title?)
    set sql {SELECT contact, link FROM link}
    if {[llength $limit]} {
	append sql " WHERE contact IN ($slimit)"
    }
    db do eval $sql {
	dict lappend map $contact $link
	dict lappend map $contact [string tolower $link]
    }

    # Rekey by names
    set map [util dict-invert $map]
    set map [util dict-fill-permute $map]

    set known [util dict-drop-ambiguous $map]

    #array set _ $known
    #parray _
    return $known
}

proc ::cm::db::contact::known {{mode select}} {
    debug.cm/db/contact {}
    setup

    # modes for "select"ion
    #       and "validation".
    #
    # select:     each contact once,
    #             with tag in the label.
    #
    # validation: each contact in multiple variants,
    #             with ambiguous data dropped.
    # => completion, and accepting multiple forms.
    # => Should go for unique prefixes as well ?

    if {$mode eq "select"} {
	return [KnownSelect]
    } else {
	return [KnownValidate]
    }
}

proc ::cm::db::contact::known-email {} {
    debug.cm/db/contact {}
    setup

    set r {}
    db do eval {
	SELECT id, email
	FROM   email
    } {
	dict set r $email $id
    }
    return $r
}

proc ::cm::db::contact::select {p} {
    debug.cm/db/contact {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set contacts [known]
    set choices  [lsort -dict [dict keys $contacts]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $contacts 1]
	}
    }

    set choice [ask menu "" "Which contact: " $choices]

    # Map back to id
    return [dict get $contacts $choice]
}

proc ::cm::db::contact::setup {} {
    debug.cm/db/contact {}

    campaign     setup ; # See: disable-email, squash-email, new-mail, recv=
    contact-type setup ; # See: all

    if {![dbutil initialize-schema ::cm::db::do error contact {
	{
	    -- General data for any type of contact:
	    -- actual person, mailing list, company
	    -- The flags determine what we can do with a contact.

	    id		 INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    tag		 TEXT	 	  UNIQUE,	-- for html anchors, and quick identification
	    type	 INTEGER NOT NULL REFERENCES contact_type,
	    name	 TEXT	 NOT NULL UNIQUE,	-- identification NOCASE -- lower(dname)
	    dname	 TEXT	 NOT NULL,		-- display name
	    biography	 TEXT,

	    can_recvmail INTEGER NOT NULL,	-- valid recipient of conference mail (call for papers)
	    can_register INTEGER NOT NULL,	-- actual person can register for attendance
	    can_book	 INTEGER NOT NULL,	-- actual person can book hotels
	    can_talk	 INTEGER NOT NULL,	-- actual person can do presentation
	    can_submit	 INTEGER NOT NULL	-- actual person, or company can submit talks
	} {
	    {id			INTEGER 1 {} 1}
	    {tag		TEXT    0 {} 0}
	    {type		INTEGER 1 {} 0}
	    {name		TEXT    1 {} 0}
	    {dname		TEXT    1 {} 0}
	    {biography		TEXT    0 {} 0}
	    {can_recvmail	INTEGER 1 {} 0}
	    {can_register	INTEGER 1 {} 0}
	    {can_book		INTEGER 1 {} 0}
	    {can_talk		INTEGER 1 {} 0}
	    {can_submit		INTEGER 1 {} 0}
	} {
	    type
	}
    }]} {
	db setup-error contact $error
    }

    if {![dbutil initialize-schema ::cm::db::do error email {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    email	TEXT	NOT NULL UNIQUE,
	    contact	INTEGER	NOT NULL REFERENCES contact,
	    inactive	INTEGER	NOT NULL	-- mark outdated addresses
	} {
	    {id		INTEGER 1 {} 1}
	    {email	TEXT    1 {} 0}
	    {contact	INTEGER 1 {} 0}
	    {inactive	INTEGER 1 {} 0}
	} {contact}
    }]} {
	db setup-error email $error
    }

    if {![dbutil initialize-schema ::cm::db::do error link {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    contact	INTEGER	NOT NULL REFERENCES contact,
	    link	TEXT	NOT NULL, -- same link text can be used by multiple contacts
	    title	TEXT,
	    UNIQUE (contact, link)
	} {
	    {id		INTEGER 1 {} 1}
	    {contact	INTEGER 1 {} 0}
	    {link	TEXT    1 {} 0}
	    {title	TEXT    0 {} 0}
	} {
	    contact link
	}
    }]} {
	db setup-error link $error
    }

    if {![dbutil initialize-schema ::cm::db::do error affiliation {
	{
	    -- Relationship between contacts.
	    -- People may be affiliated with an organization, like their employer
	    -- A table is used as a person may be affiliated with several orgs.

	    id		INTEGER NOT NULL PRIMARY KEY,
	    person	INTEGER NOT NULL REFERENCES contact,
	    company	INTEGER NOT NULL REFERENCES contact,
	    UNIQUE (person, company)
	} {
	    {id		INTEGER 1 {} 1}
	    {person	INTEGER 1 {} 0}
	    {company	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error affiliation $error
    }

    if {![dbutil initialize-schema ::cm::db::do error liaison {
	{
	    -- Relationship between contacts.
	    -- Company/orgs have people serving as their point of contact
	    -- A table is used as an org may have several representatives

	    id		INTEGER NOT NULL PRIMARY KEY,
	    company	INTEGER NOT NULL REFERENCES contact,
	    person	INTEGER NOT NULL REFERENCES contact,
	} {
	    {id		INTEGER 1 {} 1}
	    {company	INTEGER 1 {} 0}
	    {person	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error liaison $error
    }

    # Shortcircuit further calls
    proc ::cm::db::contact::setup {args} {}
    return
}

proc ::cm::db::contact::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/contact {}

    # Step I. Core contact information.
    db do eval {
	SELECT id, tag, type, dname, biography, can_recvmail
	FROM   contact
	ORDER BY dname
    } {
	set links [db do eval {
	    SELECT link
	    FROM   link
	    WHERE contact = :id
	    ORDER BY link
	}]
	set mail [db do eval {
	    SELECT email, inactive
	    FROM   email
	    WHERE contact = :id
	    ORDER BY email
	}]

	switch $type {
	    1 {	cm dump save  contact create-person  $dname }
	    2 {	cm dump save  contact create-company $dname }
	    3 {	cm dump save  contact create-list    $dname [lindex $mail 0] }
	}

	if {!$can_recvmail} {
	    cm dump save  contact disable $dname
	}
	if {$tag ne {}} {
	    cm dump save  contact set-tag $dname $tag
	}

	if {$type != 3} {
	    foreach {mail inactive} $mail {
		cm dump save  contact add-mail $dname -E $mail
		if {!$inactive} continue
		cm dump save  contact disable-mail $mail
	    }
	}

	foreach link $links {
	    cm dump save \
		contact add-link $dname -L $link
	}

	if {$biography ne {}} {
	    cm dump save \
		contact set-bio $dname \
		< [cm dump write contact$id $biography]
	}

	cm dump step
    }

    # Step II. Relationships (Affiliations & Liaisons)
    db do eval {
	SELECT C.dname AS ncompany,
	       P.dname AS nperson
	FROM   affiliation A,
	       contact     C,
	       contact     P
	WHERE  A.company = C.id
	AND    A.person  = P.id
	ORDER BY nperson, ncompany
    } {
	cm dump save \
	    contact add-affiliation $nperson $ncompany
    }

    cm dump step

    db do eval {
	SELECT C.dname AS ncompany,
	       P.dname AS nperson
	FROM   liaison L,
	       contact C,
	       contact P
	WHERE  L.company = C.id
	AND    L.person  = P.id
	ORDER BY ncompany, nperson
    } {
	cm dump save \
	    contact add-representative $ncompany $nperson
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::contact 0
return
