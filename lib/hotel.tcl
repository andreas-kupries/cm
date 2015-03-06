## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::hotel 0
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
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::table
package require cm::city
package require cm::config::core
package require cm::db
#package require cm::validate::hotel

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export hotel
    namespace ensemble create
}
namespace eval ::cm::hotel {
    namespace export \
	cmd_create cmd_list cmd_select cmd_show cmd_contact \
	select label
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::city
    namespace import ::cm::config::core
    rename core config

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/hotel
debug prefix cm/hotel {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::hotel::cmd_list {config} {
    debug.cm/hotel {}
    Setup
    db show-location

    set cid [config get* @current-hotel {}]

    [table t {{} Name Street Zip City Issues} {
	db do eval {
	    SELECT H.id                   AS id,
                   H.name                 AS name,
	           H.streetaddress        AS street,
	           H.zipcode              AS zip,
	           C.name                 AS city,
	           C.state                AS state,
	           C.nation               AS nation,
	           H.book_fax             AS bf,
	           H.book_link            AS bl,
	           H.book_phone           AS bp,
	           H.local_fax            AS lf,
	           H.local_link           AS ll,
	           H.local_phone          AS lp
	    -- todo: count staff
	    FROM  hotel H,
	          city  C
	    WHERE C.id = H.city
	    ORDER BY H.name, city
	} {
	    set city [city label $city $state $nation]

	    set issues {}
	    # TODO: Issue and issue when hotel not staffed (count == 0)
	    if {($bf eq {}) && ($lf eq {})} { lappend issues [color bad "Booking FAX missing"] }
	    if {($bl eq {}) && ($lf eq {})} { lappend issues [color bad "Booking URL missing"] }
	    if {($bp eq {}) && ($lf eq {})} { lappend issues [color bad "Booking Phone missing"] }
	    if {[llength $issues]} {
		set issues [join $issues \n]
	    }

	    set current [expr {($id == $cid)
			       ? "*"
			       : ""}]
	    $t add $current $name $street $zip $city $issues
	}
    }] show
    return
}

proc ::cm::hotel::cmd_create {config} {
    debug.cm/hotel {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set name   [$config @name]
    set cityid [$config @city]
    set street [$config @streetaddress]
    set zip    [$config @zipcode]

    set str $name
    puts -nonewline "Creating hotel \"[color name $str]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO hotel
		VALUES (NULL, :name, :cityid, :street, :zip,
			NULL, NULL, NULL, -- booking contact
			NULL, NULL, NULL, -- local contact
			NULL)
	    }
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    puts [color warning {Please remember to set the contact details and staff information}]
    return
}

proc ::cm::hotel::cmd_select {config} {
    debug.cm/hotel {}
    Setup
    db show-location

    set id [$config @hotel]

    puts -nonewline "Setting current hotel to \"[color name [get $id]]\" ... "
    config assign @current-hotel $id
    puts [color good OK]
    return
}

proc ::cm::hotel::cmd_show {config} {
    debug.cm/hotel {}
    Setup
    db show-location

    set id [config get @current-hotel]

    ... get details ...

    puts [color name ...]
    [table t {Property Value} {
    }] show
    return
}

proc ::cm::hotel::cmd_contact {config} {
    debug.cm/hotel {}
    Setup
    db show-location

    set id [config get @current-hotel]

    ... current values ... ask for new values ...

    puts -nonewline "Saving ... "
    config assign current-hotel $id
    puts [color good OK]

}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::hotel::label {name city} {
    debug.cm/hotel {}
    return "$name ($city)"
}

proc ::cm::hotel::known {p} {
    debug.cm/hotel {}

    set config [$p config self]
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT H.id     AS id,
	       H.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  hotel H,
	      city  C
	WHERE C.id = H.city
    } {
	dict set known [label $name [city label $city $state $nation]] $id
    }

    debug.cm/hotel {==> ($known)}
    return $known
}

proc ::cm::hotel::get {id} {
    debug.cm/hotel {}
    upvar 1 config config
    Setup

    lassign [db do eval {
	SELECT H.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  hotel H,
	      city  C
	WHERE C.id = H.city
	AND   H.id = :id
    }] name city state nation

    return [label $name [city label $city $state $nation]]
}

proc ::cm::hotel::select {p} {
    debug.cm/hotel {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set hotels  [known $p]
    set choices [lsort -dict [dict keys $hotels]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note
	    return [lindex $hotels 1]
	}
    }

    set choice [ask menu "" "Which hotel: " $choices]

    # Map back to id
    return [dict get $hotels $choice]
}

proc ::cm::hotel::Setup {} {
    debug.cm/hotel {}
    upvar 1 config config
    db do version ;# Initialize db access.

    ::cm::config::core::Setup

    if {![dbutil initialize-schema ::cm::db::do error hotel {
	{
	    id			INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name		TEXT    NOT NULL,
	    city		INTEGER NOT NULL REFERENCES city(id),
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
	return -code error -errorcode {CM DB HOTEL SETUP} $error
    }

    # Shortcuit further calls
    proc ::cm::hotel::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::hotel 0
return
