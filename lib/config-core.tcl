## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::config 0
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

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export config
    namespace ensemble create
}
namespace eval ::cm::db::config {
    namespace export \
	assign drop drop-glob get-list get get* \
	has has-glob names setup dump
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/config
debug prefix cm/db/config {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::config::assign {key value} {
    debug.cm/db/config {}
    setup

    # Tricky code handling setting a value for a non-existing key, or
    # overwriting the value of an existing one.
    # 
    # (1) We have an entry for 'name'.
    #     => INSERT fails, and IGNOREs that, making it a no-op.
    #     => UPDATE finds the entry and modifies it.
    # (2) There is no entry for 'name'.
    #     => INSERT creates the entry.
    #     => UPDATE changes the entry to the same value, a no-op.

    # INSERT OR REPLACE could work here ?

    db do transaction {
	db do eval {
	    INSERT OR IGNORE INTO config
	    VALUES (:key, :value);

	    UPDATE config
	    SET   value = :value
	    WHERE key = :key
	}
    }
    return

    # Might this work, due to PK (key) instead of an id ?
    db do eval {
	INSERT OR REPLACE
	INTO config
	VALUES (:key, :value)
    }
    return
}

proc ::cm::db::config::drop {key} {
    debug.cm/db/config {}
    setup

    db do transaction {
	db do eval {
	    DELETE
	    FROM config
	    WHERE key = :key
	}
    }
    return [db do changes]
}

proc ::cm::db::config::drop-glob {pattern} {
    debug.cm/db/config {}
    setup

    db do transaction {
	db do eval {
	    DELETE
	    FROM config
	    WHERE key GLOB :pattern
	}
    }
    return [db do changes]
}

proc ::cm::db::config::get-list {} {
    debug.cm/db/config {}
    setup

    return [db do eval {
	SELECT key, value FROM config
    }]
}

proc ::cm::db::config::get {key} {
    debug.cm/db/config {}
    setup

    if {![has $key]} {
	return -code error \
	    -errorcode {CM CONFIG GET UNKNOWN} \
	    "Unknown configuration key $key"
    }
    return [db do onecolumn {
	SELECT value
	FROM   config
	WHERE  key = :key
    }]
}

proc ::cm::db::config::get* {key default} {
    debug.cm/db/config {}
    setup

    if {![has $key]} {
	return $default
    }
    return [db do onecolumn {
	SELECT value
	FROM   config
	WHERE key = :key
    }]
}

proc ::cm::db::config::has {key} {
    debug.cm/db/config {}
    setup

    return [db do exists {
	SELECT value
	FROM   config
	WHERE key = :key
    }]
}

proc ::cm::db::config::has-glob {pattern} {
    debug.cm/db/config {}
    setup

    return [db do exists {
	SELECT value
	FROM   config
	WHERE key GLOB :pattern
    }]
}

proc ::cm::db::config::names {pattern} {
    debug.cm/db/config {}
    setup

    return [db do eval {
	SELECT name
	FROM   config
	WHERE key GLOB :pattern
    }]
}

proc ::cm::db::config::setup {} {
    debug.cm/db/config {}

    if {![dbutil initialize-schema ::cm::db::do error config {
	{
	    -- Configuration data of the application itself.
	    -- No relations to the conference tables.

	    key   TEXT NOT NULL PRIMARY KEY,
	    value TEXT NOT NULL
	} {
	    {key   TEXT 1 {} 1}
	    {value TEXT 1 {} 0}
	} {}
    }]} {
	db setup-error config $error
    }

    # Shortcircuit further calls
    proc ::cm::db::config::setup {args} {}
    return
}

proc ::cm::db::config::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/config {}

    db do eval {
	SELECT key, value
	FROM   config
	ORDER BY key
    } {
	# Ignore internal state recorded as config
	if {[string match @* $key]} continue

	cm dump save \
	    config set $key $value
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::config 0
return
