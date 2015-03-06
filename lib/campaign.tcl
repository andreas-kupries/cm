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

package require cm::table
#package require cm::util
package require cm::db
#package require cm::validate::campaign

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export campaign
    namespace ensemble create
}
namespace eval ::cm::campaign {
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

debug level  cm/campaign
debug prefix cm/campaign {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::campaign::cmd_list {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    [table t {Tag Name Flags Affiliation} {
	db do eval {
	} {
	}
    }] show
    return
}

proc ::cm::campaign::cmd_create {config} {
    debug.cm/campaign {}
    Setup
    db show-location

    # try to insert, report failure as user error

    set name   [$config @name]
    set state  [$config @state]
    set nation [$config @nation]
    set label  [label $name $state $nation]

    puts -nonewline "Creating campaign \"[color note $label]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO campaign
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

proc ::cm::campaign::get {id} {
    debug.cm/campaign {}
    Setup

    lassign [db do eval {
	SELECT tag, familyname, firstname
	FROM campaign
	WHERE id = :id
    }] name tag family first

    return  [label $tag $family $first]
}

proc ::cm::campaign::label {tag family first} {
    debug.cm/campaign {}

    set label {}
    if {$tag   ne {}} { append label "(\#" $tag ") " }
    append label $family
    if {$first ne {}} { append label {, } $first }
    return $label
}

proc ::cm::campaign::known {p} {
    debug.cm/campaign {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, tag, familyname, firstname
	FROM campaign
    } {
	dict set known [label $tag $familyname $firstname] $id
    }

    return $known
}

proc ::cm::campaign::select {p} {
    debug.cm/campaign {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set campaigns [known $p]
    set choices   [lsort -dict [dict keys $campaigns]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note
	    return [lindex $campaigns 1]
	}
    }

    set choice [ask menu "" "Which campaign: " $choices]

    # Map back to id
    return [dict get $campaigns $choice]
}

proc ::cm::campaign::Setup {} {
    debug.cm/campaign {}

    if {![dbutil initialize-schema ::cm::db::do error campaign {
	{
	    -- Email campaign for a conference.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    con	 	INTEGER NOT NULL UNIQUE	REFERENCES conference,	-- one campaign per conference only
	    template	INTEGER NOT NULL 	REFERENCES config,	-- mail text template
	} {
	    {id		INTEGER 1 {} 1}
	    {con	INTEGER 1 {} 0}
	    {template	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error $error CAMPAIGN
    }

    if {![dbutil initialize-schema ::cm::db::do error campaign_item {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    email	INTEGER NOT NULL REFERENCES email,	-- contact is indirect
	    campaign	INTEGER	NOT NULL REFERENCES campaign
	} {
	    {id		INTEGER 1 {} 1}
	    {email	INTEGER 1 {} 0}
	    {campaign	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error $error EMAIL
    }

    # Shortcircuit further calls
    proc ::cm::campaign::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::campaign 0
return
