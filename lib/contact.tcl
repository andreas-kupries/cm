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

package require cm::table
#package require cm::util
package require cm::db
#package require cm::validate::contact

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::contact {
    namespace export cmd_create cmd_list \
	select label get
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    #namespace import ::cm::util
    namespace import ::cm::db

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/contact
debug prefix cm/contact {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::cmd_list {config} {
    debug.cm/contact {}
    Setup
    db show-location

    [table t {Tag Name Flags Affiliation} {
	db do eval {
	} {
	}
    }] show
    return
}

proc ::cm::contact::cmd_create {config} {
    debug.cm/contact {}
    Setup
    db show-location

    # try to insert, report failure as user error

    set name   [$config @name]
    set state  [$config @state]
    set nation [$config @nation]
    set label  [label $name $state $nation]

    puts -nonewline "Creating contact \"[color note $label]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO contact
		VALUES (NULL, :name, :state, :nation)
	    }
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::contact::get {id} {
    debug.cm/contact {}
    Setup

    lassign [db do eval {
	SELECT tag, familyname, firstname
	FROM contact
	WHERE id = :id
    }] name tag family first

    return  [label $tag $family $first]
}

proc ::cm::contact::label {tag family first} {
    debug.cm/contact {}

    set label {}
    if {$tag   ne {}} { append label "(\#" $tag ") " }
    append label $family
    if {$first ne {}} { append label {, } $first }
    return $label
}

proc ::cm::contact::known {p} {
    debug.cm/contact {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, tag, familyname, firstname
	FROM contact
    } {
	dict set known [label $tag $familyname $firstname] $id
    }

    return $known
}

proc ::cm::contact::select {p} {
    debug.cm/contact {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set contacts [known $p]
    set choices  [lsort -dict [dict keys $contacts]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note
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
	    tag		 TEXT	 UNIQUE,	-- for html anchors
	    familyname	 TEXT	 NOT NULL,	-- company or list name here   
	    firstname	 TEXT,		  	-- NULL for lists and companies
	    biography	 TEXT,

	    affiliation	 INTEGER REFERENCES contact,	-- company, if any

	    can_recvmail INTEGER NOT NULL,	-- valid recipient of conference mail (call for papers)
	    can_register INTEGER NOT NULL,	-- actual person can register for attendance
	    can_book	 INTEGER NOT NULL,	-- actual person can book hotels
	    can_talk	 INTEGER NOT NULL,	-- actual person can do presentation
	    can_submit	 INTEGER NOT NULL,	-- actual person, or company can submit talks
	} {
	    {id			INTEGER 1 {} 1}
	    {tag		TEXT    0 {} 0}
	    {familyname		TEXT    1 {} 0}
	    {firstname		TEXT    0 {} 0}
	    {biography		TEXT    0 {} 0}
	    {affiliation	INTEGER 0 {} 0}
	    {can_recvmail	INTEGER 1 {} 0}
	    {can_register	INTEGER 1 {} 0}
	    {can_book		INTEGER 1 {} 0}
	    {can_talk		INTEGER 1 {} 0}
	    {can_submit		INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error $error CONTACT
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
	} {}
    }]} {
	db setup-error $error EMAIL
    }

    if {![dbutil initialize-schema ::cm::db::do error email {
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
	} {}
    }]} {
	db setup-error $error LINK
    }

    # Shortcircuit further calls
    proc ::cm::contact::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::contact 0
return
