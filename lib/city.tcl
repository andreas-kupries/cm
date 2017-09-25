## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::city 0
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
package require cmdr::table
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::util
package require cm::db
#package require cm::validate::city

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export city
    namespace ensemble create
}
namespace eval ::cm::city {
    namespace export cmd_create cmd_list cmd_show test-known \
	select label get known-validation
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::util
    namespace import ::cm::db

    namespace import ::cmdr::table::general ; rename general table
    namespace import ::cmdr::table::dict    ; rename dict    table/d
}

# # ## ### ##### ######## ############# ######################

debug level  cm/city
debug prefix cm/city {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::city::test-known {config} {
    debug.cm/city {}
    Setup
    db show-location
    util pdict [known-validation]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::city::cmd_list {config} {
    debug.cm/city {}
    Setup
    db show-location

    [table t {Name State Nation} {
	db do eval {
	    SELECT name, state, nation
	    FROM city
	    ORDER BY name, state, nation
	} {
	    $t add $name $state $nation
	}
    }] show
    return
}

proc ::cm::city::cmd_show {config} {
    debug.cm/city {}
    Setup
    db show-location

    set city [$config @city]
    lassign [details $city] name state nation
   
    [table/d t {
	$t add Name   $name
	$t add State  $state
	$t add Nation $nation
    }] show
    return
}

proc ::cm::city::cmd_create {config} {
    debug.cm/city {}
    Setup
    db show-location

    # try to insert, report failure as user error

    set name   [$config @name]
    set state  [$config @state]
    set nation [$config @nation]
    set label  [label $name $state $nation]

    puts -nonewline "Creating city \"[color name $label]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO city
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

proc ::cm::city::get {id} {
    debug.cm/city {}
    Setup

    lassign [db do eval {
	SELECT name, state, nation
	FROM  city
	WHERE id = :id
    }] name state nation

    return [label $name $state $nation]
}

proc ::cm::city::details {id} {
    debug.cm/city {}
    Setup

    lassign [db do eval {
	SELECT name, state, nation
	FROM  city
	WHERE id = :id
    }] name state nation

    return [list $name $state $nation]
}

proc ::cm::city::label {name state nation} {
    debug.cm/city {}

    set label $name
    if {$state ne {}} {append label ", $state"}
    append label ", $nation"
    return $label
}

proc ::cm::city::known-validation {} {
    set map {}

    db do eval {
	SELECT id, name AS city, state, nation
	FROM   city
    } {
	dict lappend map $id [string tolower [label $city $state $nation]]

	if {$state ne {}} {
	    set label "$city $state $nation"
	} else {
	    set label "$city $nation"
	}
	set initials  [util initials $label]
	set llabel    [string tolower $label]
	set linitials [string tolower $initials]

	#dict lappend map $id $label  "$initials $label"
	dict lappend map $id $llabel "$linitials $llabel"
    }

    # Rekey by names, then extend with key permutations which do not
    # clash, lastly drop all keys with multiple outcomes.
    set map   [util dict-invert         $map]
    # Long names for hotels, longer with location ... Too slow at the moment.
    set map   [util dict-fill-permute   $map]
    set known [util dict-drop-ambiguous $map]

    debug.cm/city {==> ($known)}
    return $known
}

proc ::cm::city::known {} {
    debug.cm/city {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, name, state, nation
	FROM city
    } {
	dict set known [label $name $state $nation] $id
    }

    return $known
}

proc ::cm::city::select {p} {
    debug.cm/city {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set cities  [known]
    set choices [lsort -dict [dict keys $cities]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $cities 1]
	}
    }

    set choice [ask menu "" "Which city: " $choices]

    # Map back to id
    return [dict get $cities $choice]
}

proc ::cm::city::Setup {} {
    debug.cm/city {}

    if {![dbutil initialize-schema ::cm::db::do error city {
	{
	    -- Base data for hotels, resorts, and other locations:
	    -- The city they are in.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name	TEXT    NOT NULL,
	    state	TEXT,
	    nation	TEXT    NOT NULL,
	    UNIQUE (name, state, nation)
	} {
	    {id     INTEGER 1 {} 1}
	    {name   TEXT    1 {} 0}
	    {state  TEXT    0 {} 0}
	    {nation TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error city $error
    }

    # Shortcircuit further calls
    proc ::cm::city::Setup {args} {}
    return
}

proc ::cm::city::Dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/city {}

    db do eval {
	SELECT name, state, nation
	FROM   city
	ORDER BY nation, state, name
    } {
	cm dump save \
	    city create $name $state $nation
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::city 0
return
