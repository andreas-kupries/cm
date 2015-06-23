## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::pschedule 0
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
package require dbutil
package require try
package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export pschedule
    namespace ensemble create
}
namespace eval ::cm::db::pschedule {
    namespace export \
        validate known start_set start_get \
	new remove rename

    # new_track remove_track rename_track
    # select select_track select_day select_item
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/pschedule
debug prefix cm/db/pschedule {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::validate {} {
    debug.cm/db/pschedule {}
    setup

    # I. pschedules - All constraints are enforced by the database.
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::known {} {
    debug.cm/db/pschedule {}
    setup

    # dict: label -> id
    set known {}

    # Validation uses the case-insensitive name for matching
    db do eval {
        SELECT id
	,      name
        FROM   pschedule
    } {
        dict set known $name $id
    }

    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::start_set {minutes} {
    debug.cm/db/pschedule {}
    setup

    db do eval {
	INSERT OR REPLACE
	INTO pschedule_global
	VALUES (NULL, 'start', :minutes)
    }
    return
}

proc ::cm::db::pschedule::start_get {} {
    debug.cm/db/pschedule {}
    setup

    return [db do onecolumn {
	SELECT value
	FROM pschedule_global
	WHERE key = 'start'
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::new {dname} {
    debug.cm/db/pschedule {}
    setup

    # Uniqueness is case-insensitive
    set name [string tolower $dname]

    do db eval {
	INSERT
	INTO pschedule
	VALUES (NULL,
		:dname,
		:name,
		NULL, -- current_day
		NULL, --     ..._track
		NULL, --     ..._item
		NULL) --     ..._open
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::pschedule::remove {pschedule} {
    debug.cm/db/pschedule {}
    setup

    db do eval {
	-- Drop current schedule, if referencing the deleted one.
	-- Ignored if referencing a different schedule.
	DELETE
	FROM pschedule_global
	WHERE key   = 'current'
	AND   value = :pschedule
	;
	-- Drop dependent information (items, tracks) first ...
	DELETE
	FROM pschedule_item
	WHERE pschedule = :pschedule
	;
	DELETE
	FROM pschedule_track
	WHERE pschedule = :pschedule
	;
	-- Drop main information
	DELETE
	FROM pschedule
	WHERE id = :pschedule
    }
    return
}

proc ::cm::db::pschedule::rename {pschedule dname} {
    debug.cm/db/pschedule {}
    setup

    # Uniqueness is case-insensitive
    set name [string tolower $dname]

    db do eval {
	UPDATE pschedule
	SET    dname = :dname
	,      name  = :name
	WHERE  id    = :pschedule
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::setup {} {
    debug.cm/db/pschedule {}

    # pschedule_global
    # pschedule
    # pschedule_track
    # pschedule_item

    if {![dbutil initialize-schema ::cm::db::do error pschedule {
	{
	    -- Common information for physical schedules:
	    -- - Names.
	    -- - The main scheduling information is found in the
	    --   "pschedule_item"s instead.
	    -- - State information for interactive editing.
	    --
	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
	    ,   dname		TEXT	NOT NULL
	    ,   name		TEXT	NOT NULL UNIQUE	-- normalized to lowercase
	    ,   current_day	INTEGER					-- Ignore if current_item
	    ,   current_track	INTEGER REFERENCES pschedule_track	-- is NOT NULL.
	    ,   current_item	INTEGER REFERENCES pschedule_item
	    ,   current_open	INTEGER
	    --
	    -- Notes
	    -- * Each schedule has a unique __name__.
	    -- * Each schedule has zero or more __tracks__.
	    -- * Each schedule has zero or more __items__.
	    -- * At most one of all existing schedules is __current__, i.e. the focus
	    --   of interactive operations.
	    -- * At most one item in the schedule is __current__ making it the focus
	    --   of interactive operations, if the schedule itself is current.
	    -- * The current item, if specified, can __closed__ or __open__,
	    --   influencing how new items are added during interactive editing of
	    --   the schedule.
	    -- * Each schedule has one or more days. This has to match the length of
	    --   the conferences using the schedule.
	    -- * At most one of the days in a schedule is the __current day__ of that
	    --   schedule, making it the focus of interactive operations, if the
	    --   schedule itself is current.
	    --   This day is implied by the __current item__, except when no item is
	    --   current.
	    -- * At most one of all existing tracks in a schedule is __current__,
	    --   i.e. the focus of interactive operations if that schedule is current.
	    --   This day is implied by the __current item__, except when no item is
	    --   current, or the item belongs to the NULL track.
	} {
	    {id            INTEGER 1 {} 1}
	    {dname         TEXT    1 {} 0}
	    {name          TEXT    1 {} 0}
	    {current_day   INTEGER 0 {} 0}
	    {current_track INTEGER 0 {} 0}
	    {current_item  INTEGER 0 {} 0}
	    {current_open  INTEGER 0 {} 0}
	} {}
    }]} {
	db setup-error pschedule $error
    }

    if {![dbutil initialize-schema ::cm::db::do error pschedule_track {
	{
	    -- Information for the tracks of a physical schedule: Names.
	    --
	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT	-- track identifier
	    ,	pschedule	INTEGER	NOT NULL REFERENCES pschedule		-- schedule the track belongs to.
	    ,	dname		TEXT	NOT NULL
	    ,	name		TEXT	NOT NULL				-- track name, unique within schedule.
	    ,	UNIQUE (pschedule, name)					-- normalized to lower-case
	    --
	    -- Notes
	    -- * Tracks are timelines running in parallel, consisting of __items__.
	    -- * Each track belongs to a __schedule__.
	    -- * Each track has a __name__, unique within the schedule it belongs to.
	    -- * The tracks of a schedule belong to all days of a conference.
	    -- * The NULL track is implicit within each schedule, i.e. it does not
	    --   exist physically, but can be selected as the current track.
	} {
	    {id            INTEGER 1 {} 1}
	    {pschedule     INTEGER 1 {} 0}
	    {name          TEXT    1 {} 0}
	    {dname         TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error pschedule_track $error
    }

    if {![dbutil initialize-schema ::cm::db::do error pschedule_item {
	{
	    -- A physical schedule consists of a set of items describing
	    -- the events of the schedule. They are called "physical"
	    -- because they specify exact timing of events, i.e. start/length,
	    -- plus track information. Items can be fixed events, or placeholders.
	    -- The logical schedule of a specific conference will then reference
	    -- and fill the placeholders with the missing information.
	    --
	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT	-- item identifier
	    ,	pschedule	INTEGER	NOT NULL REFERENCES pschedule		-- schedule the item is part of
	    ,	day		INTEGER NOT NULL				-- day of the event (0-based)
	    ,	track		INTEGER		 REFERENCES pschedule_track	-- track the item belongs to. NULL is for items spanning tracks.
	    ,	start		INTEGER NOT NULL				-- start of the item, offset in minutes from midnight
	    ,	length		INTEGER NOT NULL				-- length of the event in minutes - length==0 is allowed.
	    ,	parent		INTEGER		 REFERENCES pschedule_item	-- Optional parent item - Must have matching day, track, schedule.
	    ,	label		TEXT						-- label for placeholder.     NULL implies item is fixed _event_.
	    ,	desc_major	TEXT						-- main item description.     NULL implies item is _placeholder_.
	    ,	desc_minor	TEXT						-- secondary item description for events.
	    ,	UNIQUE (pschedule, day, track, start, length, parent)
	    ,	UNIQUE (pschedule, label)
	    --
	    -- Notes
	    -- * Items are the fundamental parts of a schedule, organized as a table
	    --   by day, track, and starting time.
	    -- * Implied in the above, each item belongs to a __schedule__.
	    -- * Implied in the above, each item belongs to a __track__.  This may be
	    --   the NULL track.  The latter indicates an item which exists across /
	    --   belongs to __all__ tracks of the schedule.
	    -- * Items can be __events__ or __placeholders__.
	    -- * Events have a fixed major description and possibly a minor
	    --   description (like speaker, or other notes).
	    -- * Placeholders have no descriptions, but a __label__ instead, which
	    --   identifies them uniquely, within the schedule they belong to.
	    -- * Items can be nested in each other, but only one level deep. IOW an
	    --   item may have a parent item, but only if that parent has no parent
	    --   of its own.
	    -- * A parent item may have multiple children.
	    -- * An item without a parent is called __toplevel__.
	    -- * All items have a starting time.
	    --   * This starting time identifies the item within its track and parent
	    --     (if any).
	    --   * For the children of a parent exactly one child must have the same
	    --     starting time as the parent.
	    -- * All items have a length (in minutes).
	    --   * The __range__ of an item is the start time (inclusive) to the end
	    --     time (exclusive), where end time is starting time plus length.
	    --   * The ranges of all items within a track and parent (if any) must
	    --     not overlap.
	    --     __Reminder__: items with the NULL track are part of __all__ tracks.
	    --   * The length of a parent to a set of children must be the sum of the
	    --     length of all its children.
	    --     This implies that there must be __no gaps__ between the children
	    --     of a parent.
	    --     Toplevel items on the other hand may have gaps between them.
	    -- * Toplevel items can be __pinned__, i.e. locked against movement in
	    --   time. This becomes important during interactive editing, as it
	    --   determines how items move as their environment changes and/or they
	    --  may block changes to said environment.
	} {
	    {id            INTEGER 1 {} 1}
	    {pschedule     INTEGER 1 {} 0}
	    {day           INTEGER 0 {} 0}
	    {track         INTEGER 0 {} 0}
	    {start         INTEGER 1 {} 0}
	    {length        INTEGER 1 {} 0}
	    {parent        INTEGER 0 {} 0}
	    {label         TEXT    0 {} 0}
	    {desc_major    TEXT    0 {} 0}
	    {desc_minor    TEXT    0 {} 0}
	} {}
    }]} {
	db setup-error pschedule_item $error
    }

    if {![dbutil initialize-schema ::cm::db::do error pschedule_global {
	{
	    -- Configuration information, global across all schedules.
	    --
	        id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
	    ,	key	TEXT    NOT NULL UNIQUE		-- configuration variable, name
	    ,	value	TEXT	NOT NULL		-- configuration variable, data

	    --
	    -- key == "current" : value INTEGER REFERENCES pschedule "current schedule"
	    -- key == "start"   : value INTEGER "start time, offset from midnight [min]"
	} {
	    {id    INTEGER 1 {} 1}
	    {key   TEXT    1 {} 0}
	    {vale  TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error pschedule_global $error
    } else {
	db do eval {
	    -- Default start at 09:00 = 9*60 = 540
	    INSERT INTO pschedule_global VALUES (NULL, 'start', 540)
	}
    }

    # Shortcircuit further calls
    proc ::cm::db::pschedule::setup {args} {}
    return
}

proc ::cm::db::pschedule::Dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/pschedule {}

    error NYI/pschedule
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::pschedule 0
return
