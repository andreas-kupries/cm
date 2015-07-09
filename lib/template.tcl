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
package require cmdr::table
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::util
package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export template
    namespace ensemble create
}
namespace eval ::cm::template {
    namespace export \
	cmd_create cmd_remove cmd_set cmd_list cmd_show \
	get details known select find find-by-name use
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::db
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
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

proc ::cm::template::cmd_set {config} {
    debug.cm/template {}
    Setup
    db show-location

    set template [$config @name]
    set text     [read stdin]

    puts -nonewline "Update [color name [$config @name string]] ... "
    flush stdout

    db do eval {
	UPDATE template
	SET    value = :text
	WHERE  id = :template
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::template::use {name} {
    # use - TODO: could do with caching ?!
    return [details [find-by-name $name]]
}

proc ::cm::template::get {id} {
    debug.cm/template {}
    Setup
    return [db do onecolumn {
	SELECT name
	FROM   template
	WHERE  id = :id
    }]
}

proc ::cm::template::details {id} {
    debug.cm/template {}
    Setup
    return [db do onecolumn {
	SELECT value
	FROM   template
	WHERE  id = :id
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

proc ::cm::template::find-by-name {name} {
    debug.cm/template {}

    # dict: label -> id
    set templates [known]

    if {![dict exists $templates $name]} {
	util user-error "Template \"$name\" not found"
	#$p undefined!
    }

    # Map to id
    return [dict get $templates $name]
}

proc ::cm::template::find {name p} {
    debug.cm/template {}
    return [find-by-name $name]
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
	db setup-error template $error
    }

    # Shortcircuit further calls
    proc ::cm::template::Setup {args} {}
    return
}

proc ::cm::template::Dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/template {}

    db do eval {
	SELECT id, name, value
	FROM   template
	ORDER BY name
    } {
	cm dump save \
	    template create $name \
	    < [cm dump write template$id $value]
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::template 0
return
