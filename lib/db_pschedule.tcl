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
        setup validate \
	start_set start_get active_set active_get \
	new remove rename all known selection details \
	track-new track-remove track-rename track-all \
	track-names track-known track-selection track-details \
	item-add-event item-add-placeholder \
	day-max

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
    Vstart

    # <S1> enforced by database (pschedule.name UNIQUE)
    # <S2> ditto                (pschedule_track.pschedule)
    # <S3> ditto                (pschedule_item.pschedule)
    # <S4> ditto                (pschedule_global.key UNIQUE)
    V-S5-schedule-active-exists

    # II.  ..._track - Most constraints are enforced by the database.
    # II.a. Assert ("Active track is not dangling")
    # II.b. Assert ("No tracks are dangling")

    # III. ..._item - Most constraints require separate checks.
    # III.a. Assert ("Active item is not dangling")
    # III.b. Assert ("No items are dangling")
    # III.c. Assert ("item.pschedule == item.track.pschedule f.a item: item.track != NULL")
    # III.d. Assert ("item.label  != NULL => item.desc_* == NULL f.a item")
    # III.e. Assert ("item.desc_* != NULL => item.label  == NULL f.a item")
    # III.f. Assert ("item.parent.parent = NULL f.a [0] item: item.parent != NULL")
    # III.g. Assert ("item1.start != item2.start f.a [1] item1, item2: item1 !== item2 && item1.{schedule,track,day,parent} == item2.{schedule,track,day,parent}, Note: include items with track == NULL (part of all tracks)")
    # III.h. Assert ("item.length == sum(child.length) f.a. item: f.a. child: child.parent == item")
    # III.i. Assert ("nil = intersect(range(item1),range(item2)) f.a [1]") - no overlaps
    # III.j. Assert ("ranges of children in a parent have no gaps")
    # III.k. Assert ("item.parent.track     == item.track     f.a [0]")
    # III.l. Assert ("item.parent.day       == item.day       f.a [0]")
    # III.m. Assert ("item.parent.pschedule == item.pschedule f.a [0]")
    # III.n. Assert ("item.pinned         => item.parent == NULL f.a item")
    # III.o. Assert ("item.parent != NULL => !item.pinned        f.a item")
    # III.p. Assert ("covered days of schedule have no gaps f.a schedule")

    Vreport
    return
}

proc ::cm::db::pschedule::Vstart {} {
    variable vissues {}
    return
}

proc ::cm::db::pschedule::Vfail {args} {
    variable vissues
    lappend vissues [join $args]
    return
}

proc ::cm::db::pschedule::Vreport {args} {
    variable vissues
    if {![llength $vissues]} return
    return -code error \
	-errorcode {CM SCHEDULE VALIDATION} \
	":: [join $vissues "\n:: "]"
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::V-S5-schedule-active-exists {} {
    debug.cm/db/pschedule {}
    # Assert ("S5: Active schedule X is NOT NULL => Schedule X exists")

    if {[db do onecolumn {
	SELECT count(*)
	FROM            pschedule_global G --
	LEFT OUTER JOIN pschedule        S --
	ON              G.value = S.id     -- G-->S reference
	WHERE G.key = 'schedule/active'            -- limit to active schedules
	AND   S.id IS NULL                 -- and keep only deref failures
    }]} { Vfail "The active schedule does not exist." }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::known {} {
    debug.cm/db/pschedule {}
    setup

    # dict: label -> id
    set known {}

    # Validation uses the case-insensitive name for matching.
    db do eval {
        SELECT id
	,      name
        FROM   pschedule
    } {
        dict set known $name $id
    }

    return $known
}

proc ::cm::db::pschedule::selection {} {
    debug.cm/db/pschedule {}
    setup

    # dict: label -> id
    set known {}

    # Selection uses the display name.
    db do eval {
        SELECT dname
	,      id
        FROM   pschedule
	ORDER BY dname
    } {
        lappend known $dname $id
    }

    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::details {pschedule} {
    debug.cm/db/pschedule {}
    setup

    return [db do eval {
	SELECT 'xid',          id
	,      'xdname',       dname
	,      'xname',        name
	,      'xactiveitem',  active_item
	,      'xactiveday',   active_day
	,      'xactivetrack', active_track
	,      'xactivetime',  active_time
	FROM   pschedule
	WHERE id = :pschedule
    }]
}

proc ::cm::db::pschedule::all {} {
    debug.cm/db/pschedule {}
    setup

    return [db do eval {
	SELECT id
	,      dname
	,      name
	,      active_item
	,      active_day
	,      active_track
	,      active_time
	FROM   pschedule
	ORDER BY name
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::new {dname} {
    debug.cm/db/pschedule {}
    setup

    # Uniqueness is case-insensitive
    set name [string tolower $dname]

    db do eval {
	INSERT
	INTO pschedule
	VALUES (NULL,   -- id
		:dname, -- dname
		:name,  -- name
		NULL,   -- active_day
		NULL,   --     ..._track
		NULL,   --     ..._item
		NULL)   --     ..._open
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::pschedule::remove {pschedule} {
    debug.cm/db/pschedule {}
    setup

    db do eval {
	-- Drop active schedule, if referencing the deleted one.
	-- Ignored if referencing a different schedule.
	DELETE
	FROM pschedule_global
	WHERE key   = 'schedule/active'
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

proc ::cm::db::pschedule::day-max {pschedule} {
    debug.cm/db/pschedule {}
    setup

    # Determine stored max day for the schedule.
    set max [db do onecolumn {
        SELECT MAX (day)
        FROM   pschedule_item
	WHERE  pschedule = :pschedule
    }]

    # And derive the max day the user is able to enter, one more than
    # stored.
    if {$max eq {}} {
	set max 0
    } else {
	incr max
    }

    return $max
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::track-known {pschedule} {
    debug.cm/db/pschedule {}
    setup

    # dict: label -> id
    set known {}

    # Validation uses the case-insensitive name for matching.
    db do eval {
        SELECT id
	,      name
        FROM   pschedule_track
	WHERE  pschedule = :pschedule
    } {
        dict set known $name $id
    }

    return $known
}

proc ::cm::db::pschedule::track-selection {pschedule} {
    debug.cm/db/pschedule {}
    setup

    # dict: label -> id
    set known {}

    # Selection uses the display name.
    db do eval {
        SELECT dname
	,      id
        FROM   pschedule_track
	WHERE  pschedule = :pschedule
	ORDER BY dname
    } {
        lappend known $dname $id
    }

    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::track-details {track} {
    debug.cm/db/pschedule {}
    setup

    return [db do eval {
	SELECT 'xid',    id
	,      'xdname', dname
	,      'xname',  name
	FROM   pschedule_track
	WHERE  id = :track
    }]
}

proc ::cm::db::pschedule::track-all {pschedule} {
    debug.cm/db/pschedule {}
    setup

    return [db do eval {
	SELECT id
	,      dname
	,      name
	FROM   pschedule_track
	WHERE  pschedule = :pschedule
	ORDER BY name
    }]
}

proc ::cm::db::pschedule::track-names {pschedule} {
    debug.cm/db/pschedule {}
    setup

    return [db do eval {
	SELECT dname
	FROM   pschedule_track
	WHERE  pschedule = :pschedule
	ORDER BY name
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::track-new {pschedule dname} {
    debug.cm/db/pschedule {}
    setup

    # Uniqueness is case-insensitive
    set name [string tolower $dname]

    db do eval {
	INSERT
	INTO pschedule_track
	VALUES (NULL,       -- id
		:pschedule, -- pschedule
		:dname,     -- dname
		:name)      -- name

    }
    return [db do last_insert_rowid]
}

proc ::cm::db::pschedule::track-remove {track} {
    debug.cm/db/pschedule {}
    setup

    db do eval {
	-- Drop items referencing the track.
	-- The affect schedule is implied in the track.
	DELETE
	FROM   pschedule_item
	WHERE  track = :track
	;
	-- Drop active track in the schedule, if it is the removed track
	UPDATE pschedule
	SET    active_track = NULL
	WHERE  active_track = :track
	;
	-- Drop track itself.
	DELETE
	FROM   pschedule_track
	WHERE  id = :track
    }
    return
}

proc ::cm::db::pschedule::track-rename {track dname} {
    debug.cm/db/pschedule {}
    setup

    # Uniqueness is case-insensitive
    set name [string tolower $dname]

    db do eval {
	UPDATE pschedule_track
	SET    dname = :dname
	,      name  = :name
	WHERE  id    = :track
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::start_set {minutes} {
    debug.cm/db/pschedule {}
    setup

    db do eval {
	INSERT OR REPLACE
	INTO   pschedule_global
	VALUES (NULL, 'start', :minutes)
    }
    return
}

proc ::cm::db::pschedule::start_get {} {
    debug.cm/db/pschedule {}
    setup

    return [db do onecolumn {
	SELECT value
	FROM   pschedule_global
	WHERE  key = 'start'
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::pschedule::active_set {pschedule} {
    debug.cm/db/pschedule {}
    setup

    db do eval {
	INSERT OR REPLACE
	INTO   pschedule_global
	VALUES (NULL, 'schedule/active', :pschedule)
    }
    return
}

proc ::cm::db::pschedule::active_get {} {
    debug.cm/db/pschedule {}
    setup

    return [db do onecolumn {
	SELECT value
	FROM   pschedule_global
	WHERE  key = 'schedule/active'
    }]
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
	    -- % Name
	    -- % Focus point for interactive editing.
	    --
	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
	    ,   dname		TEXT	NOT NULL
	    ,   name		TEXT	NOT NULL UNIQUE	-- <S1> normalized to
	                                                -- lowercase for case-
	                                                -- insensitive matching
	    ,   active_item	INTEGER REFERENCES pschedule_item
	    ,   active_day	INTEGER
	    ,   active_track	INTEGER REFERENCES pschedule_track
	    ,   active_time	INTEGER
	    --
	    -- Notes, Constraints, Assertions, and Invariants.
	    --
	    -- [S1] Each schedule has a unique __name__ under case-insensitive comparison.
	    -- [S2] Each schedule has zero or more __tracks__.
	    -- [S3] Each schedule has zero or more __items__.
	    -- [S4] At most one schedule is __active__, i.e. the focus of
	    --      interactive operations.
	    -- [S5] An active schedule exists.
	    --
	    -- * At most one item in the schedule is __active__ making it the focus
	    --   of interactive operations, if the schedule itself is active.
	    -- * The active item, if specified, can __closed__ or __open__,
	    --   influencing how new items are added during interactive editing of
	    --   the schedule.
	    -- * Each schedule has one or more days. This has to match the length of
	    --   the conferences using the schedule.
	    -- * At most one of the days in a schedule is the __active day__ of that
	    --   schedule, making it the focus of interactive operations, if the
	    --   schedule itself is active.
	    --   This day is implied by the __active item__, except when no item is
	    --   active.
	    -- * At most one of all existing tracks in a schedule is __active__,
	    --   i.e. the focus of interactive operations if that schedule is active.
	    --   This day is implied by the __active item__, except when no item is
	    --   active, or the item belongs to the NULL track.
	} {
	    {id           INTEGER 1 {} 1}
	    {dname        TEXT    1 {} 0}
	    {name         TEXT    1 {} 0}
	    {active_item  INTEGER 0 {} 0}
	    {active_day   INTEGER 0 {} 0}
	    {active_track INTEGER 0 {} 0}
	    {active_time  INTEGER 0 {} 0}
	} {}
    }]} {
	db setup-error pschedule $error
    }

    if {![dbutil initialize-schema ::cm::db::do error pschedule_track {
	{
	    -- Information for the tracks of a physical schedule:
	    -- % Name
	    -- These are timelines which run in parallel during a day.
	    --
	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
	    ,	pschedule	INTEGER	NOT NULL REFERENCES pschedule	-- <T1><S2> owning schedule
	    ,	dname		TEXT	NOT NULL
	    ,	name		TEXT	NOT NULL			-- <T2> normalized to  
	    ,	UNIQUE (pschedule, name)				-- lowercase for case- 
	                                                                -- insensitive matching
	    --
	    -- Notes, constraints, Assertions, and Invariants.
	    --
	    -- [T1] Each track belongs to a __schedule__. (<==> [S2])
	    -- [T2] Each track has a unique __name__ under case-insensitive comparison, within the owning schedule.
	    -- [T3] Each track has zero or more __items__.
	    --
	    -- % The tracks of a schedule form an axis orthogonal to the days of the schedule.
	    -- % The tracks of a schedule form an axis orthogonal to the item times of the schedule.
	    -- % The NULL track is implicit within each schedule
	    --   While it does not exist physically, it can be chosen as the active track.
	} {
	    {id            INTEGER 1 {} 1}
	    {pschedule     INTEGER 1 {} 0}
	    {dname         TEXT    1 {} 0}
	    {name          TEXT    1 {} 0}
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
	        id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
	    ,	pschedule	INTEGER	NOT NULL REFERENCES pschedule		-- <I1><S3> owning schedule
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
	    -- Notes, constraints, Assertions, and Invariants.
	    --
	    -- [I1] Each item belongs to a __schedule__. (<==> [S3])
	    --
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
	    {day           INTEGER 1 {} 0}
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
	    -- <S4> key == "schedule/active" : value INTEGER REFERENCES pschedule "active schedule"
	    --      key == "start"           : value INTEGER "start time, offset from midnight [min]"
	} {
	    {id    INTEGER 1 {} 1}
	    {key   TEXT    1 {} 0}
	    {value TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error pschedule_global $error
    } else {
	db do eval {
	    -- Default start at 09:00 = 9*60 = 540
	    INSERT OR IGNORE INTO pschedule_global VALUES (NULL, 'start', 540)
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
