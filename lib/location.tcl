## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::location 0
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

package require cm::city
package require cm::config::core
package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export location
    namespace ensemble create
}
namespace eval ::cm::location {
    namespace export \
	cmd_create cmd_list cmd_select cmd_show cmd_contact \
	cmd_map cmd_staff_show cmd_map_get \
	cmd_staff_link cmd_staff_unlink known-validation \
	select label get details known-staff select-staff get-name
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cm::city
    namespace import ::cm::db
    namespace import ::cm::util

    namespace import ::cm::config::core
    rename core config

    namespace import ::cmdr::table::general ; rename general table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/location
debug prefix cm/location {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::location::cmd_list {config} {
    debug.cm/location {}
    Setup
    db show-location

    set cid [config get* @current-location {}]

    [table t {{} Name Street Zip City} {
	db do eval {
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

proc ::cm::location::cmd_create {config} {
    debug.cm/location {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set name   [$config @name]
    set cityid [$config @city]
    set street [$config @streetaddress]
    set zip    [$config @zipcode]

    puts -nonewline "Creating location \"[color name $name]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO location
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

    puts -nonewline "Setting as current location ... "
    config assign @current-location $id
    puts [color good OK]

    return
}

proc ::cm::location::cmd_select {config} {
    debug.cm/location {}
    Setup
    db show-location

    set id [$config @location]

    puts -nonewline "Setting current location to \"[color name [get $id]]\" ... "
    config assign @current-location $id
    puts [color good OK]
    return
}

proc ::cm::location::cmd_show {config} {
    debug.cm/location {}
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

	if {!$xstaffcount} {
	    set xstaffcount [color bad None]
	    append xstaffcount "\n(=> location add-staff)"
	} else {
	    append xstaffcount "\n(=> location staff)"
	}

	if {$xtransport eq {}} {
	    set xtransport [color bad None]
	} elseif {[string length $xtransport] > 30} {
	    set xtransport [string range $xtransport 0 26]...
	}

	$t add Staff       $xstaffcount
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


proc ::cm::location::cmd_map {config} {
    debug.cm/location {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]

    puts "Working with location \"[color name [get $id]]\" ..."

    set map [read stdin]

    dict set details xtransport $map

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

proc ::cm::location::cmd_map_get {config} {
    debug.cm/location {}
    Setup

    set id      [current]
    set details [details $id]

    puts [dict get $details xtransport]
    return
}

proc ::cm::location::cmd_contact {config} {
    debug.cm/location {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]

    puts "Working with location \"[color name [get $id]]\" ..."
    # NOTE: Could move the interaction into the cli spec, at the
    # NOTE: expense of either not showing the non-interactive pieces,
    # NOTE: or showing them after the interaction, i.e. out of the
    # NOTE: chosen order.
    foreach {key label} {
	bookphone  {Booking Phone}
	bookfax    {Booking FAX  }
	booklink   {Booking Url  }
	localphone {Local   Phone}
	localfax   {Local   FAX  }
	locallink  {Local   Url  }
    } {
	if {[$config @$key set?]} {
	    set new [$config @$key]
	    puts "${label}: $new"
	} else {
	    set v [dict get $details x$key]
	    set new [ask string $label $v]
	}
	dict set details x$key $new
    }

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::location::cmd_staff_show {config} {
    debug.cm/location {}
    Setup
    db show-location

    set location [current]

    puts "Staff of \"[color name [get $location]]\":"
    [table t {Role Staff Phone Email} {
	set first 1
	db do eval {
	    SELECT position, name, phone, email
	    FROM   location_staff
	    WHERE  location = :location
	    ORDER BY position, name
	} {
	    if {$first} {
		set lastposition $position
		set first 0
	    } elseif {$lastposition ne $position} {
		$t add {} {}
		set lastposition $position
	    } else {
		set position {}
	    }
	    $t add $position $name $phone $email
	}
    }] show
    return
}

proc ::cm::location::cmd_staff_link {config} {
    debug.cm/location {}
    Setup
    db show-location

    set location [current]
    set position [$config @position]
    set name     [$config @name]
    set phone    [$config @phone]
    set email    [$config @email]

    if {($phone eq {}) && ($email eq {})} {
	util user-error "We need either phone or email, you cannot leave both undefined." \
	    LOCATION STAFF CONTACT
    }

    puts "Adding \"$position\" to location \"[color name [get $location]]\" ... "
    puts -nonewline "  \"[color name $name]\" (P: $phone) (E: $email) ... "
    flush stdout

    db do eval {
	INSERT INTO location_staff
	VALUES (NULL, :location, :position, :name, :email, :phone)
    }

    puts [color good OK]
    return
}

proc ::cm::location::cmd_staff_unlink {config} {
    debug.cm/location {}
    Setup
    db show-location

    set location [current]
    lassign [$config @name] id position name

    puts "Removing staff from location \"[color name [get $location]]\" ... "
    puts -nonewline "  $position \"[color name $name]\" ... "
    flush stdout

    db do eval {
	DELETE
	FROM location_staff
	WHERE id = :id
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::location::label {name city} {
    debug.cm/location {}
    return "$name ($city)"
}

proc ::cm::location::known-validation {} {
    debug.cm/location {}
    Setup

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

    # Rekey by names, then extend with key permutations which do not
    # clash, lastly drop all keys with multiple outcomes.
    set map   [util dict-invert         $map]
    # Long names for hotels, longer with location ... Too slow at the moment.
    #set map   [util dict-fill-permute   $map]
    set known [util dict-drop-ambiguous $map]

    debug.cm/location {==> ($known)}
    return $known
}

proc ::cm::location::known {} {
    debug.cm/location {}
    Setup

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

    debug.cm/location {==> ($known)}
    return $known
}

proc ::cm::location::issues {details} {
    debug.cm/location {}
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

proc ::cm::location::+issue {text} {
    debug.cm/location {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

proc ::cm::location::get {id} {
    debug.cm/location {}
    Setup

    lassign [db do eval {
	SELECT L.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  location L,
	      city     C
	WHERE C.id = L.city
	AND   L.id = :id
    }] name city state nation

    return [label $name [city label $city $state $nation]]
}

proc ::cm::location::get-name {id} {
    debug.cm/location {}
    Setup

    lassign [db do eval {
	SELECT L.name   AS name,
	       C.name   AS city,
	       C.state  AS state,
	       C.nation AS nation
	FROM  location L,
	      city     C
	WHERE C.id = L.city
	AND   L.id = :id
    }] name city state nation

    if {$state ne {}} {
	return "$name $city $state $nation"
    } else {
	return "$name $city $nation"
    }
}

proc ::cm::location::details {id} {
    debug.cm/location {}
    Setup

    set details [db do eval {
	SELECT "xname",       name,
               "xcity",       city,
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

proc ::cm::location::write {id details} {
    debug.cm/location {}
    Setup

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

proc ::cm::location::the-current {} {
    debug.cm/location {}

    try {
	set id [config get @current-location]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	return -1
    }
    if {[has $id]} { return $id }
    return -1
}

proc ::cm::location::current {} {
    debug.cm/location {}

    try {
	set id [config get @current-location]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	puts [color bad "No location chosen, please \"select\" one"]
	::exit 0
    }
    if {[has $id]} { return $id }

    puts [color bad "Bad location index, please \"select\" one"]
    ::exit 0
}

proc ::cm::location::has {id} {
    debug.cm/location {}
    Setup

    return [db do exists {
	SELECT name
	FROM   location
	WHERE  id = :id
    }]
}

proc ::cm::location::select {p} {
    debug.cm/location {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set locations [known]
    set choices   [lsort -dict [dict keys $locations]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $locations 1]
	}
    }

    set choice [ask menu "" "Which location: " $choices]

    # Map back to id
    return [dict get $locations $choice]
}

proc ::cm::location::select-staff {p} {
    debug.cm/location {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> (id,position,name)
    set staff   [known-staff-select [the-current]]
    set choices [lsort -dict [dict keys $staff]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $staff 1]
	}
    }

    set choice [ask menu "" "Which staff: " $choices]

    # Map back to (id,position,name)
    return [dict get $staff $choice]
}

proc ::cm::location::known-staff {} {
    debug.cm/location {}
    Setup

    set location [the-current]
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

proc ::cm::location::known-staff-select {location} {
    debug.cm/location {}
    Setup

    if {($location eq {}) ||
	($location < 0)} {
	return {}
    }

    # Not going through contact here. We need role information as
    # well.

    set known {}
    db do eval {
	SELECT id, position, name
	FROM   location_staff
	WHERE  location = :location
	ORDER BY position, name
    } {
	dict set known "$position/$name" [list $id $position $name]
    }
    return $known
}

# # ## ### ##### ######## ############# ######################

proc ::cm::location::Setup {} {
    debug.cm/location {}

    ::cm::config::core::Setup
    ::cm::city::Setup

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
    proc ::cm::location::Setup {args} {}
    return
}

proc ::cm::location::Dump {} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/location {}

    db do eval {
	SELECT id, name, city, streetaddress, zipcode,
	       book_fax, book_link, book_phone,
	       local_fax, local_link, local_phone,
	       transportation
	FROM   location
	ORDER BY name
    } {
	set city [city get $city]

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
package provide cm::location 0
return
