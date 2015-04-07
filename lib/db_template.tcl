## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::template 0
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

package require cm::util
package require cm::table
package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export template
    namespace ensemble create
}
namespace eval ::cm::db::template {
    namespace export new delete update all 2name value \
	find find-p use known select setup dump
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/template
debug prefix cm/db/template {[debug caller] | }

# # ## ### ##### ######## ############# ######################
##

proc ::cm::db::template::new {name value} {
    debug.cm/db/template {}
    setup

    db do transaction {
	db do eval {
	    INSERT INTO template
	    VALUES (NULL, :name, :value)
	}
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::template::delete {template} {
    debug.cm/db/template {}
    setup

    db do eval {
	DELETE
	FROM   template
	WHERE  id = :template
    }
    return
}

proc ::cm::db::template::update {template value} {
    debug.cm/db/template {}
    setup

    db do eval {
	UPDATE template
	SET    value = :value
	WHERE  id    = :template
    }
    return
}

proc ::cm::db::template::all {} {
    debug.cm/db/template {}
    setup

    return [db do eval {
	SELECT id, name
	FROM   template
	ORDER BY name
    }]
}

proc ::cm::db::template::use {name} {
    debug.cm/db/template {}
    # use - TODO: could do with caching ?!
    return [value [find $name]]
}

proc ::cm::db::template::2name {template} {
    debug.cm/db/template {}
    setup

    return [db do onecolumn {
	SELECT name
	FROM   template
	WHERE  id = :template
    }]
}

proc ::cm::db::template::value {template} {
    debug.cm/db/template {}
    setup

    return [db do onecolumn {
	SELECT value
	FROM   template
	WHERE  id = :template
    }]
}

proc ::cm::db::template::known {} {
    debug.cm/db/template {}
    setup

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

proc ::cm::db::template::find {name} {
    debug.cm/db/template {}

    # dict: label -> id
    set templates [known]

    if {![dict exists $templates $name]} {
	util user-error "Template \"$name\" not found"
	#$p undefined!
    }

    # Map to id
    return [dict get $templates $name]
}

proc ::cm::db::template::find-p {name p} {
    debug.cm/db/template {}
    return [find $name]
}

proc ::cm::db::template::select {p} {
    debug.cm/db/template {}
    return [util select $p template known]
}

proc ::cm::db::template::setup {} {
    debug.cm/db/template {}

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
    proc ::cm::db::template::setup {args} {}
    return
}

proc ::cm::db::template::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/template {}

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
package provide cm::db::template 0
return
