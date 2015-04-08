## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::location 0
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
package require cm::db::city
package require cm::db::config
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export location
    namespace ensemble create
}
namespace eval ::cm::db::location {
    namespace export \
	all new delete 2name 2name* label select known get update \
	new-staff delete-staff select-staff known-staff \
	issues current current* current= setup dump
    namespace ensemble create

    namespace import ::cm::db
    namespace import ::cm::db::city
    namespace import ::cm::db::config
    namespace import ::cm::util
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/location
debug prefix cm/db/location {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::location::all {} {
    debug.cm/db/location {}
    setup

    return [db do eval {
	    SELECT L.id                   AS id,
                   L.name                 AS name,
	           L.streetaddress        AS street,
	           L.zipcode              AS zip,
	           C.name                 AS city,
	           C.state                AS state,
	           C.nation               AS nation
	    FROM  location L,
	          city     C
	    WHERE C.id = L.city
	    ORDER BY L.name, city
    }]
}

proc ::cm::db::location::new {name city street zip} {
    debug.cm/db/location {}
    setup

    db do transaction {
	db do eval {
	    INSERT INTO location
	    VALUES (NULL, :name, :city, :street, :zip,
		    NULL, NULL, NULL, -- booking contact (fax, link, phone)
		    NULL, NULL, NULL, -- local   contact (ditto)
		    NULL)             -- transportation text block
	}
    }

    return [db do last_insert_rowid]
}

proc ::cm::db::location::delete {location} {
    debug.cm/db/location {}
    setup

    db do transaction {
	db do eval {
	    -- First remove dependent information - staff
	    DELETE
	    FROM   location_staff
	    WHERE  location = :location
	    ;
	    -- Followed by the primary record
	    DELETE
	    FROM   location
	    WHERE  id = :location
	}
    }
    return
}

proc ::cm::db::location::2name {location} {
    debug.cm/db/location {}
    setup

    lassign [db do eval {
	SELECT L.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  location L,
	      city     C
	WHERE C.id = L.city
	AND   L.id = :location
    }] name city state nation

    return [label $name [city label $city $state $nation]]
}

proc ::cm::db::location::2name* {location} {
    debug.cm/db/location {}
    setup

    lassign [db do eval {
	SELECT L.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  location L,
	      city     C
	WHERE C.id = L.city
	AND   L.id = :location
    }] name city state nation

    if {$state ne {}} {
	return "$name $city $state $nation"
    } else {
	return "$name $city $nation"
    }
}

proc ::cm::db::location::label {name city} {
    debug.cm/db/location {}
    return "$name ($city)"
}

proc ::cm::db::location::known {} {
    debug.cm/db/location {}
    setup

    # dict: id -> list (label)
    set map {}

    db do eval {
	SELECT L.id     AS id,
	       L.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  location L,
	      city     C
	WHERE C.id = L.city
    } {
	if {$state ne {}} {
	    set label "$name $city $state $nation"
	} else {
	    set label "$name $city $nation"
	}
	set initials  [util initials $label]
	set llabel    [string tolower $label]
	set linitials [string tolower $initials]

	dict lappend map $id $label  "$initials $label"
	dict lappend map $id $llabel "$linitials $llabel"
    }

    # Rekey by names and drop all keys with multiple outcomes. No
    # permutations. Too slow, with list lengths around 6 and higher
    # (2-4 city, 2-4 location).
    set map [util dict-invert         $map]
    set map [util dict-drop-ambiguous $map]

    debug.cm/db/location {==> ($map)}
    return $map
}

proc ::cm::db::location::select {p} {
    debug.cm/db/location {}
    return [util select $p location Selection]
}

proc ::cm::db::location::Selection {} {
    debug.cm/db/location {}
    setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT L.id     AS id,
	       L.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  location L,
	      city     C
	WHERE C.id = L.city
    } {
	dict set known [label $name [city label $city $state $nation]] $id
    }

    debug.cm/db/location {==> ($known)}
    return $known
}

proc ::cm::db::location::get {id} {
    debug.cm/db/location {}
    setup

    set details [db do eval {
	SELECT 'xname',       name,
               'xcity',       city,
	       'xstreet',     streetaddress,
	       'xzipcode',    zipcode,
	       'xbookfax',    book_fax,
	       'xbooklink',   book_link,
	       'xbookphone',  book_phone,
	       'xlocalfax',   local_fax,
	       'xlocallink',  local_link,
	       'xlocalphone', local_phone,
	       'xtransport',  transportation
	    -- TODO: count staff
	FROM  location
	WHERE id = :id
    }]

    # Was quicker to write than an outer join aggregate to count.
    # Using an aggregate query would be nicer, likely.
    dict set details xstaffcount [db do eval {
	SELECT count (id)
	FROM   location_staff
	WHERE  location = :id
    }]

    return $details
}

proc ::cm::db::location::update {id details} {
    debug.cm/db/location {}
    setup

    dict with details {}
    # xstaffcount is ignored, derived data.

    db do eval {
	UPDATE location
	SET    city           = :xcity,
	       streetaddress  = :xstreet,
	       zipcode        = :xzipcode,
	       book_fax       = :xbookfax,
	       book_link      = :xbooklink,
	       book_phone     = :xbookphone,
	       local_fax      = :xlocalfax,
	       local_link     = :xlocallink,
	       local_phone    = :xlocalphone,
	       transportation = :xtransport
	WHERE id = :id
    }
}

proc ::cm::db::location::current= {location} {
    debug.cm/db/location {}
    config assign @current-location $location
    return
}

proc ::cm::db::location::current* {} {
    debug.cm/db/location {}
    return [config get* @current-location {}]
}

proc ::cm::db::location::current {} {
    debug.cm/db/location {}

    set location [Current]
    if {$location == -2} {
	util user-error \
	    "Current location is bad, please \"select\" one" \
	    LOCATION CURRENT BAD
    } elseif {$location < 0} {
	util user-error \
	    "No current location chosen, please \"select\" one"
	    LOCATION CURRENT MISSING
    } else {
	return $location
    }
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::location::new-staff {location position name email phone} {
    debug.cm/db/location {}
    setup

    db do eval {
	INSERT INTO location_staff
	VALUES (NULL, :location, :position, :name, :email, :phone)
    }

    return [db do last_insert_rowid]
}

proc ::cm::db::location::delete-staff {staff} {
    debug.cm/db/location {}
    setup

    db do eval {
	DELETE
	FROM   location_staff
	WHERE  id = :staff
    }
    return
}

proc ::cm::db::location::known-staff {} {
    debug.cm/db/location {}
    setup

    set location [Current]
    if {$location < 0} {
	return {}
    }

    set known {}
    db do eval {
	SELECT id, position, name
	FROM   location_staff
	WHERE  location = :location
    } {
	set key [list $id $position $name]
	dict set known "${position}: $name" $key
	dict set known "$name/$position"    $key
    }

    return $known
}

proc ::cm::db::location::select-staff {p} {
    debug.cm/db/location {}
    return [util select $p staff \
		[list SelectionStaff [Current]]]
}

proc ::cm::db::location::SelectionStaff {location} {
    debug.cm/db/location {}
    setup

    if {($location eq {}) ||
	($location < 0)} {
	return {}
    }

    # Not going through contact here. We need role information as
    # well.

    set selection {}
    db do eval {
	SELECT id, position, name
	FROM   location_staff
	WHERE  location = :location
	ORDER BY position, name
    } {
	dict set selection "$position/$name" [list $id $position $name]
    }
    return $selection
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::location::Current {} {
    debug.cm/db/location {}

    try {
	set location [config get @current-location]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	return -1
    }
    if {[Has $location]} { return $location }
    return -2
}

proc ::cm::db::location::Has {location} {
    debug.cm/db/location {}
    setup

    return [db do exists {
	SELECT name
	FROM   location
	WHERE  id = :location
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::location::issues {details} {
    debug.cm/db/location {}
    dict with details {}

    set issues {}

    if {!$xstaffcount}     { +issue "Staff missing" }
    if {$xzipcode   eq {}} { +issue "Zipcode missing" }
    if {$xstreet    eq {}} { +issue "Street address missing" }
    if {$xtransport eq {}} { +issue "Map & directions missing" }
    if {($xbookfax   eq {}) && ($xlocalfax   eq {})} { +issue "Booking FAX missing"   }
    if {($xbooklink  eq {}) && ($xlocallink  eq {})} { +issue "Booking URL missing"   }
    if {($xbookphone eq {}) && ($xlocalphone eq {})} { +issue "Booking Phone missing" }
    if {($xlocalfax   eq {})} { +issue "Local FAX missing"   }
    if {($xlocallink  eq {})} { +issue "Local URL missing"   }
    if {($xlocalphone eq {})} { +issue "Local Phone missing" }

    if {[llength $issues]} {
	set issues [join $issues \n]
    }
    return $issues
}

proc ::cm::db::location::+issue {text} {
    debug.cm/db/location {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::db::location::setup {} {
    debug.cm/db/location {}

    city   setup
    config setup

    if {![dbutil initialize-schema ::cm::db::do error location {
	{
	    id			INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name		TEXT    NOT NULL,
	    city		INTEGER NOT NULL REFERENCES city,
	    streetaddress	TEXT    NOT NULL,
	    zipcode		TEXT    NOT NULL,
	    book_fax		TEXT,	-- defaults to the local-*
	    book_link		TEXT,
	    book_phone		TEXT,
	    local_fax		TEXT	UNIQUE,
	    local_link		TEXT	UNIQUE,
	    local_phone		TEXT	UNIQUE,
	    transportation	TEXT,			-- html block (maps, descriptions, etc)
	    UNIQUE (city, streetaddress)
	} {
	    {id			INTEGER 1 {} 1}
	    {name		TEXT    1 {} 0}
	    {city		INTEGER 1 {} 0}
	    {streetaddress	TEXT    1 {} 0}
	    {zipcode		TEXT    1 {} 0}
	    {book_fax		TEXT	0 {} 0}
	    {book_link		TEXT	0 {} 0}
	    {book_phone		TEXT	0 {} 0}
	    {local_fax		TEXT	0 {} 0}
	    {local_link		TEXT	0 {} 0}
	    {local_phone	TEXT	0 {} 0}
	    {transportation	TEXT	0 {} 0}
	} {}
    }]} {
	db setup-error location $error
    }

    if {![dbutil initialize-schema ::cm::db::do error location_staff {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    location	INTEGER NOT NULL REFERENCES location,
	    position	TEXT	NOT NULL,
	    name	TEXT	NOT NULL,
	    email	TEXT,	-- either email or phone must be set, i.e. not null
	    phone	TEXT,	-- no idea how to specify such constraint in sql
	    UNIQUE (location, position, name) -- Same person may have multiple positions
	} {
	    {id			INTEGER 1 {} 1}
	    {location		INTEGER 1 {} 0}
	    {position		TEXT    1 {} 0}
	    {name		TEXT    1 {} 0}
	    {email		TEXT	0 {} 0}
	    {phone		TEXT	0 {} 0}
	} {}
    }]} {
	db setup-error location_staff $error
    }

    # Shortcircuit further calls
    proc ::cm::db::location::setup {args} {}
    return
}

proc ::cm::db::location::dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/location {}
    setup

    db do eval {
	SELECT id, name, city, streetaddress, zipcode,
	       book_fax, book_link, book_phone,
	       local_fax, local_link, local_phone,
	       transportation
	FROM   location
	ORDER BY name
    } {
	set city [city 2name $city]

	cm dump save  \
	    location create $name $streetaddress $zipcode $city
	# create auto-selects new location as current.
	cm dump save  \
	    location contact $book_phone $book_fax $book_link $local_phone $local_fax $local_link

	db do eval {
	    SELECT position, name, phone, email
	    FROM   location_staff
	    WHERE  location = :id
	    ORDER BY name, position
	} {	
	    cm dump save  \
		location add-staff $position $name $phone $email
	}

	if {$transportation ne {}} {
	    cm dump save \
		location map-set \
		< [cm dump write location$id $transportation]
	}

	cm dump step 
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::location 0
return
