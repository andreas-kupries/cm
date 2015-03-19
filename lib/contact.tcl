## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::contact 0
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
package require struct::list

package provide cm::contact 0 ; # campaign and contact are circular

package require cm::campaign
package require cm::table
package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::contact {
    namespace export \
	cmd_create_person cmd_create_mlist cmd_create_company \
	cmd_add_mail cmd_add_link cmd_list cmd_show cmd_merge \
	cmd_set_tag cmd_set_bio cmd_disable cmd_enable liaisons \
	cmd_disable_mail cmd_squash_mail cmd_mail_fix cmd_retype cmd_rename \
	cmd_add_company cmd_add_liaison cmd_drop_company cmd_drop_liaison \
	select label get known known-email known-type details affiliated \
	get-name get-links get-email get-the-link related-formatted
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask

    namespace import ::cm::campaign
    namespace import ::cm::db
    namespace import ::cm::util

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/contact
debug prefix cm/contact {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::cmd_show {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [string trim [$config @name]]

    set w [util tspace [expr {[string length {Can Receive Mail}]+7}]]

    [table t {Property Value} {
	db do eval {
	    SELECT C.id           AS id,
                   C.tag          AS tag,
	           CT.text        AS type,
	           C.dname        AS name,
	    	   C.biography    AS bio,
	           C.can_recvmail AS crecv,
	    	   C.can_register AS creg,
	    	   C.can_book     AS cbook,
	    	   C.can_talk     AS ctalk,
	    	   C.can_submit   AS csubm
	    FROM  contact      C,
	          contact_type CT
	    WHERE C.id   = :contact
	    AND   C.type = CT.id
	} {
	    set flags {}
	    if {$crecv} { lappend flags Receive  }
	    if {$creg } { lappend flags Register }
	    if {$cbook} { lappend flags Book     }
	    if {$ctalk} { lappend flags Talk     }
	    if {$csubm} { lappend flags Submit   }

	    $t add Tag                $tag
	    $t add Name               $name
	    $t add Type               $type
	    $t add Flags              [join $flags {, }]
	    $t add Biography          [util adjust $w $bio]

	    # Coded left self-joins for various relations...

	    # Emails for the contact
	    set first 1
	    db do eval {
		SELECT email
		FROM   email
		WHERE  contact = :id
	    } {
		if {$first} { $t add Emails {} }
		set first 0
		$t add - $email
	    }

	    # Links for the contact
	    set first 1
	    db do eval {
		SELECT link
		FROM   link
		WHERE  contact = :id
	    } {
		if {$first} { $t add Links {} }
		set first 0
		$t add - $link
	    }

	    # Affiliations. Expected for persons, to list companies, their, well, affiliations
	    set first 1
	    db do eval {
		SELECT C.dname
		FROM   contact     C,
		       affiliation A
		WHERE  A.person  = :contact
		AND    A.company = C.id
	    } {
		if {$first} { $t add Affiliations {} }
		set first 0
		$t add - $dname
	    }

	    # Liaisons. Expected for companies, to list persons, their representatives
	    set first 1
	    db do eval {
		SELECT C.dname
		FROM   contact C,
		       liaison L
		WHERE  L.company = :contact
		AND    L.person = C.id
	    } {
		if {$first} { $t add Representatives {} }
		set first 0
		$t add - $dname
	    }

	    # Reverse affiliations. Expected for companies, to list persons, the affiliated
	    set first 1
	    db do eval {
		SELECT C.dname
		FROM   contact     C,
		       affiliation A
		WHERE  A.company = :contact
		AND    A.person  = C.id
	    } {
		if {$first} { $t add Affiliated {} }
		set first 0
		$t add - $dname
	    }

	    # Reverse liaisons. Expected for persons, to list the companies they represent
	    set first 1
	    db do eval {
		SELECT C.dname
		FROM   contact C,
		       liaison L
		WHERE  L.person  = :contact
		AND    L.company = C.id
	    } {
		if {$first} { $t add Representing {} }
		set first 0
		$t add - $dname
	    }
	}
    }] show
    return
}

proc ::cm::contact::cmd_list {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set pattern  [string trim [$config @pattern]]
    set withmail [$config @with-mails]

    set titles {\# Type Tag Name Mails Flags Relations}

    set counter 0
    [table t $titles {
	db do eval {
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
	} {
	    incr counter

	    set related [related-formatted $contact $typecode]

	    set    flags {}
	    append flags [expr {$crecv ? "M" :"-"}]
	    append flags [expr {$creg  ? "R" :"-"}]
	    append flags [expr {$cbook ? "B" :"-"}]
	    append flags [expr {$ctalk ? "T" :"-"}]
	    append flags [expr {$csubm ? "S" :"-"}]

	    if {$withmail} {
		set mails {}
		db do eval {
		    SELECT email, inactive
		    FROM   email
		    WHERE  contact = :contact
		    ORDER BY email
		} {
		    lappend mails "[expr {$inactive ? "-":" "}] $email"
		}
		set mails [join $mails \n]
		$t add $counter $type $tag $name $mails $flags $related
	    } else {
		set mails [db do eval {
		    SELECT count(email)
		    FROM   email
		    WHERE  contact = :contact
		}]
		if {!$mails} { set mails [color bad None] }
		$t add $counter $type $tag $name $mails $flags $related
	    }
	}
    }] show
    return
}

proc ::cm::contact::cmd_create_mlist {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set name [string trim [$config @name]]
    set mail [string trim [$config @mail]]

    # TODO: FIXME: Existing contact -> replace the mailing address - only one email allowed for lists.

    db do transaction {
	if {![has-mlist $name]} {
	    # Unknown contact. Create it, then add mail
	    puts -nonewline "Create list \"[color name $name]\" with mail \"[color name $mail]\" ... "
	    flush stdout

	    set id [new-mlist $name]
	} else {
	    # Contact exists. Find it, then add mail

	    puts -nonewline "Extend list \"[color name $name]\" with mail \"[color name $mail]\" ... "
	    flush stdout

	    set id [get-mlist $name]
	}

	new-mail  $id $mail
	add-links $id $config
    }
    # TODO: handle conflict with non list contacts

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_create_company {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set name [string trim [$config @name]]

    db do transaction {
	if {![has-company $name]} {
	    # Unknown contact. Create it, then add mails and links
	    puts -nonewline "Create company \"[color name $name]\" ... "
	    flush stdout

	    set id [new-company $name]
	} else {
	    # Contact exists. Find it, then add mails and links

	    puts -nonewline "Extend company \"[color name $name]\" ... "
	    flush stdout

	    set id [get-company $name]
	}

	add-mails $id $config
	add-links $id $config
    }

    # TODO: Handle conflict with non company contacts

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_create_person {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set name [string trim [$config @name]]

    db do transaction {
	if {![has-person $name]} {
	    # Unknown contact. Create it, then add mail
	    puts -nonewline "Create person \"[color name $name]\" ... "
	    flush stdout

	    set id [new-person $name]
	} else {
	    # Contact exists. Find it, then add mail

	    puts -nonewline "Extend person \"[color name $name]\" ... "
	    flush stdout

	    set id [get-person $name]
	}

	add-mails $id $config
	add-links $id $config

	if {[$config @tag set?]} {
	    update-tag $id [string trim [$config @tag]]
	}
    }

    # TODO: Handle conflict with non person contacts

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_add_mail {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]

    puts -nonewline "Add mails to \"[color name [get $contact]]\" ... "
    flush stdout

    add-mails $contact $config

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_add_link {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]

    puts -nonewline "Add links to \"[color name [get $contact]]\" ... "
    flush stdout

    add-links $contact $config

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_disable {config} {
    debug.cm/contact {}
    Setup
    db show-location

    foreach contact [$config @name] {
	puts -nonewline "Disabling contact \"[color name [get $contact]]\" ... "
	flush stdout

	db do transaction {
	    # unset receiver flag ...
	    update-recv $contact 0
	    # ... and drop its mail from all active campaigns.
	    db do eval {
		SELECT id AS email
		FROM   email
		WHERE  contact = :contact
	    } {
		campaign drop-mail $email
	    }
	}

	puts [color good OK]
    }
    return
}

proc ::cm::contact::cmd_enable {config} {
    debug.cm/contact {}
    Setup
    db show-location

    foreach contact [$config @name] {
	puts -nonewline "Enabling contact \"[color name [get $contact]]\" ... "
	flush stdout

	db do transaction {
	    # set receiver flag ...
	    update-recv $contact 1
	    # ... and add its active mails to all active campaigns.
	    db do eval {
		SELECT id AS email
		FROM   email
		WHERE  contact = :contact
		AND    NOT inactive
	    } {
		campaign add-mail $email
	    }
	}

	puts [color good OK]
    }
    return
}

proc ::cm::contact::cmd_disable_mail {config} {
    debug.cm/contact {}
    Setup
    db show-location

    foreach email [$config @email] {
	puts -nonewline "Disabling email \"[color name [get-email $email]]\" ... "
	flush stdout

	db do transaction {
	    # set inactive
	    db do eval {
		UPDATE email
		SET inactive = 1
		WHERE id = :email
	    } 
	    # ... and drop the mail from all active campaigns.
	    campaign drop-mail $email
	}

	puts [color good OK]
    }
    return
}

proc ::cm::contact::cmd_squash_mail {config} {
    debug.cm/contact {}
    Setup
    db show-location

    foreach email [$config @email] {
	puts -nonewline "Deleting email \"[color name [get-email $email]]\" ... "
	flush stdout

	db do transaction {
	    # Drop all references, i.e. campaigns.
	    db do eval {
		DELETE
		FROM campaign_destination
		WHERE email = :email
		;
		DELETE
		FROM campaign_received
		WHERE email = :email
		;
		DELETE
		FROM  email
		WHERE id = :email
		;
	    } 
	}

	puts [color good OK]
    }
    return
}

proc ::cm::contact::cmd_retype {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set type   [$config @type]
    set tlabel [get-type $type]

    foreach contact [$config @name] {
	puts -nonewline "Changing contact \"[color name [get $contact]]\" to \"$tlabel\" ... "
	flush stdout

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

	puts [color good OK]
    }
    return
}

proc ::cm::contact::cmd_rename {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]
    set dnew    [$config @newname]
    set new     [string tolower $dnew]

    puts -nonewline "Renaming contact \"[color name [get $contact]]\" to \"[color name $new]\" ... "
    flush stdout

    db do eval {
	UPDATE contact
	SET    name  = :new,
	       dname = :dnew
	WHERE  id    = :contact
    }

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_merge {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set primary [$config @primary]

    foreach secondary [$config @secondary] {
	puts -nonewline "Merging contact \"[color name [get $primary]]\" with \"[color name [get $secondary]]\" ... "
	flush stdout

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
	puts [color good OK]
    }

    return
}

proc ::cm::contact::cmd_set_tag {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]
    set tag     [$config @tag]

    puts -nonewline "Set tag of \"[color name [get $contact]]\" to \"$tag\" ... "
    flush stdout

    update-tag $contact $tag

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_set_bio {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]
    set bio     [read stdin]

    puts -nonewline "Set biography of \"[color name [get $contact]]\" ... "
    flush stdout

    update-bio $contact $bio

    puts [color good OK]
    return
}

proc ::cm::contact::cmd_add_company {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]

    db do transaction {
	puts "Extend affiliations of \"[color name [get $contact]]\" ... "

	foreach company [$config @company] {
	    puts -nonewline "+ \"[color name [get $company]]\" ... "
	    flush stdout

	    add-affiliation $contact $company

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::cmd_drop_company {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set contact [$config @name]

    db do transaction {
	puts "Reduce affiliations of \"[color name [get $contact]]\" ... "

	foreach company [$config @company] {
	    puts -nonewline "- \"[color name [get $company]]\" ... "
	    flush stdout

	    drop-affiliation $contact $company

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::cmd_add_liaison {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set company [$config @company]

    db do transaction {
	puts "Extend representatives of \"[color name [get $company]]\" ..."

	foreach contact [$config @name] {
	    puts -nonewline "+ \"[color name [get $contact]]\" ..."
	    flush stdout

	    add-liaison $company $contact

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::cmd_drop_liaison {config} {
    debug.cm/contact {}
    Setup
    db show-location

    set company [$config @company]

    db do transaction {
	puts "Reduce representatives of \"[color name [get $company]]\" ..."

	foreach contact [$config @name] {
	    puts -nonewline "- \"[color name [get $contact]]\" ..."
	    flush stdout

	    drop-liaison $company $contact

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::cmd_mail_fix {config} {
    debug.cm/contact {}
    Setup
    db show-location

    puts -nonewline "Fixing mails, forcing lowercase ... "
    flush stdout

    db do eval {
	SELECT id, email
	FROM email
    } {
	set down [string tolower $email]
	db do eval {
	    UPDATE email
	    SET    email = :down
	    WHERE  id = :id
	}
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::contact::affiliated {contact} {
    debug.cm/contact {}
    Setup
    return [db do eval {
	SELECT C.id, C.dname
	FROM   contact     C,
	       affiliation A
	WHERE  A.person  = :contact
	AND    A.company = C.id
	ORDER BY C.dname
    }]
}

proc ::cm::contact::liaisons {contact} {
    debug.cm/contact {}
    Setup
    return [db do eval {
	SELECT C.id, C.dname
	FROM   contact C,
	       liaison L
	WHERE  L.company = :contact
	AND    L.person = C.id
	ORDER BY C.dname
    }]
}

proc ::cm::contact::related-formatted {contact type} {
    debug.cm/contact {}
    if {$type != 1} {
	# liaisons aka representatives
	set related [dict values [liaisons $contact]]
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
	set related [dict values [affiliated $contact]]
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

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::add-mails {id config} {
    debug.cm/contact {}
    foreach mail [$config @email] {
	new-mail $id [string trim $mail]
    }
    return
}

proc ::cm::contact::add-links {id config} {
    debug.cm/contact {}
    foreach link [$config @link] {
	new-link $id [string trim $link]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::new-mlist {dname} {
    debug.cm/contact {}
    Setup

    set name [string tolower $dname]
    db do eval {
	INSERT INTO contact
	VALUES (NULL, NULL,
		3, :name, :dname,	-- mailing list
		NULL,			-- no initial bio
		NULL,			-- un-affiliated
		1,0,0,0,0)
    }
    return [db do last_insert_rowid]
}

proc ::cm::contact::new-company {dname} {
    debug.cm/contact {}
    Setup

    set name [string tolower $dname]
    db do eval {
	INSERT INTO contact
	VALUES (NULL, NULL,
		2, :name, :dname,	-- company
		NULL,			-- no initial bio
		NULL,			-- un-affiliated
		1,0,0,0,1)
	-- TODO/Note: talker for a company submission should have company affiliation.
	-- TODO/Note: Not forbidden to not have affiliation, but worth a warning.
    }
    return [db do last_insert_rowid]
}

proc ::cm::contact::new-person {dname} {
    debug.cm/contact {}
    Setup

    set name [string tolower $dname]
    db do eval {
	INSERT INTO contact
	VALUES (NULL, NULL,
		1, :name, :dname,	-- person
		NULL,			-- no initial bio
		NULL,			-- un-affiliated
		1,1,1,1,1)
    }
    return [db do last_insert_rowid]
}

proc ::cm::contact::new-mail {contact mail} {
    debug.cm/contact {}
    Setup

    # Mail addresses are handled -nocase by the mail system. Store
    # them in a canonical form to have a sensible uniqueness.
    set mail [string tolower $mail]

    db do eval {
	INSERT INTO email
	VALUES (NULL, :mail, :contact, 0)
    }
    set id [db do last_insert_rowid]

    campaign add-mail $id

    return $id
}

proc ::cm::contact::new-link {contact link} {
    debug.cm/contact {}
    Setup

    db do eval {
	INSERT INTO link
	VALUES (NULL, :contact, :link, '')
    }
    return [db do last_insert_rowid]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::update-recv {contact enable} {
    debug.cm/contact {}
    Setup

    db do eval {
	UPDATE contact
	SET    can_recvmail = :enable
	WHERE  id           = :contact
    }
    return
}

proc ::cm::contact::update-tag {contact tag} {
    debug.cm/contact {}
    Setup

    db do eval {
	UPDATE contact
	SET    tag = :tag
	WHERE  id  = :contact
    }
    return
}

proc ::cm::contact::update-bio {contact bio} {
    debug.cm/contact {}
    Setup

    db do eval {
	UPDATE contact
	SET    biography = :bio
	WHERE  id        = :contact
    }
    return
}

proc ::cm::contact::add-affiliation {contact affiliation} {
    debug.cm/contact {}
    Setup

    db do eval {
	INSERT
	INTO affiliation
	VALUES (NULL, :contact, :affiliation)
    }
    return
}

proc ::cm::contact::add-liaison {contact liaison} {
    debug.cm/contact {}
    Setup

    db do eval {
	INSERT
	INTO liaison
	VALUES (NULL, :contact, :liaison)
    }
    return
}

proc ::cm::contact::drop-affiliation {contact affiliation} {
    debug.cm/contact {}
    Setup

    db do eval {
	DELETE
	FROM affiliation
	WHERE person  = :contact
	AND   company = :affiliation
    }
    return
}

proc ::cm::contact::drop-liaison {contact liaison} {
    debug.cm/contact {}
    Setup

    db do eval {
	DELETE
	FROM liaison
	WHERE company = :contact
	AND   person  = :liaison
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::has-mlist {name} {
    debug.cm/contact {}
    Setup

    set name [string tolower $name]
    return [db do exists {
	SELECT id
	FROM   contact
	WHERE  type = 3		-- mailing list
	AND    name = :name
    }]
}

proc ::cm::contact::has-company {name} {
    debug.cm/contact {}
    Setup

    set name [string tolower $name]
    return [db do exists {
	SELECT id
	FROM   contact
	WHERE  type = 2		-- company
	AND    name = :name
    }]
}

proc ::cm::contact::has-person {name} {
    debug.cm/contact {}
    Setup

    set name [string tolower $name]
    return [db do exists {
	SELECT id
	FROM   contact
	WHERE  type = 1		-- person
	AND    name = :name
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::get-mlist {name} {
    debug.cm/contact {}
    Setup

    set name [string tolower $name]
    return [db do onecolumn {
	SELECT id
	FROM   contact
	WHERE  type = 3		-- mailing list
	AND    name = :name
    }]
}

proc ::cm::contact::get-company {name} {
    debug.cm/contact {}
    Setup

    set name [string tolower $name]
    return [db do onecolumn {
	SELECT id
	FROM   contact
	WHERE  type = 2		-- company
	AND    name = :name
    }]
}

proc ::cm::contact::get-person {name} {
    debug.cm/contact {}
    Setup

    set name [string tolower $name]
    return [db do onecolumn {
	SELECT id
	FROM   contact
	WHERE  type = 1		-- person
	AND    name = :name
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::get-email {id} {
    debug.cm/contact {}
    Setup

    return [db do onecolumn {
	SELECT email
	FROM   email
	WHERE  id = :id
    }]
}

proc ::cm::contact::get-type {id} {
    debug.cm/contact {}
    Setup

    return [db do onecolumn {
	SELECT text
	FROM   contact_type
	WHERE  id = :id
    }]
}

proc ::cm::contact::get {id} {
    debug.cm/contact {}
    Setup

    lassign [db do eval {
	SELECT tag, dname
	FROM   contact
	WHERE  id = :id
    }] tag name

    return [label $tag $name]
}

proc ::cm::contact::get-name {id} {
    debug.cm/contact {}
    Setup

    return [db do onecolumn {
	SELECT dname
	FROM   contact
	WHERE  id = :id
    }]
}

proc ::cm::contact::get-the-link {id} {
    debug.cm/contact {}
    set links [lsort -dict [get-links $id]]
    if {![llength $links]} return
    return [lindex $links 0]
}

proc ::cm::contact::get-links {id} {
    debug.cm/contact {}
    Setup
    return [db do eval {
	SELECT link
	FROM   link
	WHERE  contact = :id
    }]
}

proc ::cm::contact::details {id} {
    debug.cm/contact {}
    Setup

    return [db do eval {
	SELECT "xid",           id,
               "xtag",          tag,
               "xtype",         type,
	       "xname",         name,
	       "xdname",        dname,
	       "xbiography",    biography,
	       "xcan_recvmail", can_recvmail,
	       "xcan_register", can_register,
	       "xcan_book",     can_book,
	       "xcan_talk",     can_talk,
	       "xcan_submit",   can_submit
	FROM  contact
	WHERE id = :id
    }]
}

proc ::cm::contact::label {tag name} {
    debug.cm/contact {}

    if {$tag ne {}} { append label "(\#" $tag ") " }
    append label $name
    return $label
}

proc ::cm::contact::KnownSelect {} {
    debug.cm/contact {}

    # dict: label -> id
    set known [KnownSelectLimited {}]

    # Cache result
    proc ::cm::contact::KnownSelect {} [list return $known]
    return $known
}

proc ::cm::contact::KnownSelectLimited {limit} {
    debug.cm/contact {}
    Setup

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

proc ::cm::contact::Initials {text} {
    debug.cm/contact {}

    set r {}
    foreach w [split $text] {
	append r [string toupper [string index $w 0]]
    }
    return $r
}

proc ::cm::contact::Invert {dict} {
    debug.cm/contact {}

    set r {}
    # Invert
    dict for {k vlist} $dict {
	foreach v $vlist {
	    dict lappend r $v $k
	}
    }
    # Drop duplicates
    dict for {k list} $r {
	dict set r $k [lsort -unique $list]
    }
    return $r
}

proc ::cm::contact::DropAmbiguous {dict} {
    debug.cm/contact {}

    dict for {k vlist} $dict {
	if {[llength $vlist] == 1} {
	    dict set dict $k [lindex $vlist 0]
	    continue
	}
	dict unset dict $k
    }
    return $dict
}

proc ::cm::contact::KnownValidate {} {
    debug.cm/contact {}

    set known [KnownLimited {}]

    # Cache result
    proc ::cm::contact::KnownValidate {} [list return $known]
    return $known
}

proc ::cm::contact::KnownLimited {limit} {
    debug.cm/contact {}
    Setup

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
	    dict lappend map $id $tag \#$tag
	}
	set in [Initials $name]
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
    set map [Invert $map]

    # Extend with key permutations which do not clash
    dict for {k vlist} $map {
	foreach p [struct::list permutations [split $k]] {
	    set p [join $p]
	    if {[dict exists $map $p]} continue
	    dict set map $p $vlist
	}
    }

    set known [DropAmbiguous $map]

    #array set _ $known
    #parray _
    return $known
}

proc ::cm::contact::known {{mode select}} {
    debug.cm/contact {}
    Setup

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

proc ::cm::contact::known-email {} {
    debug.cm/contact {}
    Setup

    set r {}
    db do eval {
	SELECT id, email
	FROM   email
    } {
	dict set r $email $id
    }
    return $r
}

proc ::cm::contact::known-type {} {
    debug.cm/contact {}
    Setup

    set r {}
    db do eval {
	SELECT id, text
	FROM   contact_type
    } {
	dict set r $text                  $id
	dict set r [string tolower $text] $id
    }
    return $r
}

proc ::cm::contact::select {p} {
    debug.cm/contact {}

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

proc ::cm::contact::Setup {} {
    debug.cm/contact {}

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
    proc ::cm::contact::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::contact 0
return
