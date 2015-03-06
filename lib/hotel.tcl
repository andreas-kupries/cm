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
package require cmdr::ask
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::city
package require cm::config::core
package require cm::db
package require cm::table
package require cm::util
#package require cm::validate::hotel

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export hotel
    namespace ensemble create
}
namespace eval ::cm::hotel {
    namespace export \
	cmd_create cmd_list cmd_select cmd_show cmd_contact \
	cmd_map select label get details
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cm::city
    namespace import ::cm::db
    namespace import ::cm::util

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

    [table t {{} Name Street Zip City} {
	db do eval {
	    SELECT H.id                   AS id,
                   H.name                 AS name,
	           H.streetaddress        AS street,
	           H.zipcode              AS zip,
	           C.name                 AS city,
	           C.state                AS state,
	           C.nation               AS nation
	    FROM  hotel H,
	          city  C
	    WHERE C.id = H.city
	    ORDER BY H.name, city
	} {
	    set city    [city label $city $state $nation]
	    set issues  [issues [details $id]]
	    if {$issues ne {}} {
		append name \n $issues
	    }

	    util highlight-current cid $id current name street zip city
	    $t add $current $name $street $zip $city
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

    puts -nonewline "Creating hotel \"[color name $name]\" ... "

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
	set id [db do last_insert_rowid]
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    puts [color warning {Please remember to set the contact details and staff information}]

    puts -nonewline "Setting as current hotel ... "
    config assign @current-hotel $id
    puts [color good OK]

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

    set id      [current]
    set details [details $id]

    puts "Details of \"[color name [get $id]]\":"
    [table t {Property Value} {
	set issues [issues $details]
	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
	    $t add -------- -----
	}

	dict with details {}

	set xcity [city get $xcity]

	$t add Street      $xstreet
	$t add Zipcode     $xzipcode
	$t add City        $xcity
	$t add Book/Phone  $xbookphone
	$t add Book/Fax    $xbookfax
	$t add Book/Url    $xbooklink
	$t add Local/Phone $xlocalphone
	$t add Local/Fax   $xlocalfax
	$t add Local/Url   $xlocallink
	$t add Transport   $xtransport
    }] show
    return
}


proc ::cm::hotel::cmd_map {config} {
    debug.cm/hotel {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]

    puts "Working with hotel \"[color name [get $id]]\" ..."

    set map [read stdin]

    dict set details transport $map

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

proc ::cm::hotel::cmd_contact {config} {
    debug.cm/hotel {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]

    puts "Working with hotel \"[color name [get $id]]\" ..."
    foreach {key label} {
	xbookphone  {Booking Phone}
	xbookfax    {Booking FAX  }
	xbooklink   {Booking Url  }
	xlocalphone {Local   Phone}
	xlocalfax   {Local   FAX  }
	xlocallink  {Local   Url  }
    } {
	set v [dict get $details $key]
	set new [ask string $label $v]
	dict set details $key $new
    }

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
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

proc ::cm::hotel::issues {details} {
    debug.cm/hotel {}
    dict with details {}

    set issues {}
    # TODO: Issue an issue when hotel not staffed (count == 0)

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

proc ::cm::hotel::+issue {text} {
    debug.cm/hotel {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
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

proc ::cm::hotel::details {id} {
    debug.cm/hotel {}
    return [db do eval {
	SELECT "xcity",       city,
	       "xstreet",     streetaddress,
	       "xzipcode",    zipcode,
	       "xbookfax",    book_fax,
	       "xbooklink",   book_link,
	       "xbookphone",  book_phone,
	       "xlocalfax",   local_fax,
	       "xlocallink",  local_link,
	       "xlocalphone", local_phone,
	       "xtransport",  transportation
	    -- TODO: count staff
	FROM  hotel
	WHERE id = :id
    }]
}

proc ::cm::hotel::write {id details} {
    debug.cm/hotel {}
    dict with details {}
    db do eval {
	UPDATE hotel
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

proc ::cm::hotel::current {} {
    debug.cm/hotel {}
    try {
	set id [config get @current-hotel]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	puts [color bad "No hotel chosen, please \"select\" a hotel"]
	::exit 0
    }
    if {[has $id]} { return $id }

    puts [color bad "Bad hotel index, please \"select\" a hotel"]
    ::exit 0
}

proc ::cm::hotel::has {id} {
    debug.cm/hotel {}
    upvar 1 config config
    Setup
    return [db do exists {
	SELECT name
	FROM   hotel
	WHERE  id = :id
    }]
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
