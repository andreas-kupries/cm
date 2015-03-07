## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::template 0
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
package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export template
    namespace ensemble create
}
namespace eval ::cm::template {
    namespace export \
	cmd_create cmd_remove cmd_list cmd_show \
	details known select
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::db

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/template
debug prefix cm/template {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::template::cmd_show {config} {
    debug.cm/template {}
    Setup
    db show-location

    set id [$config @name]
    puts "Template [color name [$config @name string]]:"
    puts [details $id]
    return
}

proc ::cm::template::cmd_list {config} {
    debug.cm/template {}
    Setup
    db show-location

    # TODO: compute and show issues with templates (missing place holders)

    [table t {Name} {
	db do eval {
	    SELECT name
	    FROM   template
	    ORDER BY name
	} {
	    $t add $name
	}
    }] show
    return
}

proc ::cm::template::cmd_create {config} {
    debug.cm/template {}
    Setup
    db show-location

    # try to insert, report failure as user error

    set name [$config @name]
    set text [read stdin]

    # TODO: compute and show issues with templates (missing place holders)
    # Warn, ask for progress...

    puts -nonewline "Creating template \"[color name $name]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO template
		VALUES (NULL, :name, :text)
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

proc ::cm::template::cmd_remove {config} {
    debug.cm/template {}
    Setup
    db show-location

    set id [$config @name]

    puts -nonewline "Remove [color name [$config @name string]] ... "
    flush stdout

    # TODO: prevent removal if used in campaigns

    db do eval {
	DELETE FROM template
	WHERE id = :id
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::template::details {id} {
    debug.cm/template {}
    Setup
    return [db do onecolumn {
	SELECT value
	FROM  template
	WHERE id = :id
    }]
}

proc ::cm::template::known {} {
    debug.cm/template {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, name
	FROM template
    } {
	dict set known $name $id
    }

    return $known
}

proc ::cm::template::select {p} {
    debug.cm/template {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set templates [known]
    set choices   [lsort -dict [dict keys $templates]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note
	    return [lindex $templates 1]
	}
    }

    set choice [ask menu "" "Which template: " $choices]

    # Map back to id
    return [dict get $templates $choice]
}

proc ::cm::template::Setup {} {
    debug.cm/template {}

    if {![dbutil initialize-schema ::cm::db::do error template {
	{
	    -- Text templates for mail campaigns

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name	TEXT    NOT NULL UNIQUE,
	    value	TEXT	NOT NULL
	} {
	    {id     INTEGER 1 {} 1}
	    {name   TEXT    1 {} 0}
	    {value  TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error $error TEMPLATE
    }

    # Shortcircuit further calls
    proc ::cm::template::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::template 0
return
