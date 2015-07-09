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
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::db::city
package require cm::db::location
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export location
    namespace ensemble create
}
namespace eval ::cm::location {
    namespace export \
	create delete list-all select show current current-reset \
	staff_create staff_delete staff_show \
	map_set map_get contact_set \
	test-known test-select \
	test-staff-known test-staff-select
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::db::city
    namespace import ::cm::db::location
    namespace import ::cm::util

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/location
debug prefix cm/location {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::location::list-all {config} {
    debug.cm/location {}
    location setup
    db show-location

    set clocation [location current*]

    [table t {{} Name Street Zip City} {
	foreach {id name street zip city state nation} [location all] {
	    set city    [city label $city $state $nation]
	    set issues  [location issues [location get $id]]
	    if {[llength $issues]} {
		append name \n [util fmt-issues-cli $issues]
	    }

	    util highlight-current clocation $id \
		current name street zip city
	    $t add $current $name $street $zip $city
	}
    }] show

    # TODO list-all: Report if a current location is defined, but not found in the list => bad index.
    return
}

proc ::cm::location::create {config} {
    debug.cm/location {}
    location setup
    db show-location
    # try to insert, report failure as user error

    set name   [$config @name]
    set street [$config @streetaddress]
    set zip    [$config @zipcode]
    set city   [$config @city]

    puts "Creating new location \"[color name $name]\" ... "
    puts "in \"[color name [city 2name $city]]\""
    puts "at $street"
    puts "   $zip"
    puts -nonewline " ... "
    flush stdout

    try {
	set location [location new $name $city $street $zip]
    } on error {e o} {
	# Report insert failure as user error
	# TODO: trap only proper insert error, if possible.
	util user-error $e LOCATION CREATE
    }

    puts [color good OK]

    puts -nonewline "Setting as current location ... "
    location current= $location
    puts [color good OK]

    puts [color warning {Please set the contact details and add staff}]
    return
}

proc ::cm::location::select {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]

    puts -nonewline "Setting current location to \"[color name [location 2name $location]]\" ... "
    location current= $location
    puts [color good OK]
    return
}

proc ::cm::location::current-reset {config} {
    debug.cm/location {}
    location setup
    db show-location

    puts -nonewline "Unsetting current location ... "
    location current-reset
    puts [color good OK]
    return
}

proc ::cm::location::current {config} {
    debug.cm/location {}
    location setup
    db show-location

    ShowCurrent
    return
}

proc ::cm::location::delete {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]

    puts -nonewline "Delete location \"[color name [location 2name $location]]\" ... "

    # TODO: constrain deletion to locations not in use by conferences.
    # TODO: should possibly report/note number of staff deleted as well.

    try {
	location delete $location
    } on error {e o} {
	# Report deletion failure as user error
	# TODO: trap only proper insert error, if possible.
	util user-error $e LOCATION DELETE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::location::show {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]
    set details  [location get $location]

    puts "Details of \"[color name [location 2name $location]]\":"
    [table t {Property Value} {
	set issues [location issues $details]
	if {[llength $issues]} {
	    $t add [color bad Issues] [util fmt-issues-cli $issues]
	    $t add -------- -----
	}

	dict with details {}

	set xcity [city 2name $xcity]

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


proc ::cm::location::map_set {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]
    set details  [location get $location]
    set map      [util text-stdin $config @map]

    puts -nonewline "Updating map of location \"[color name [location 2name $location]]\" ..."
    flush stdout

    dict set details xtransport $map
    location update $location $details

    puts [color good OK]
    return
}

proc ::cm::location::map_get {config} {
    debug.cm/location {}
    location setup

    set location [$config @location]
    set details  [location get $location]

    # TODO map-get: wrap into box vs raw
    puts [dict get $details xtransport]
    return
}

proc ::cm::location::contact_set {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]
    set details  [location get $location]

    puts "Working with location \"[color name [location 2name $location]]\" ..."
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
	    set v [dict get $details $key]
	    set new [ask string $label $v]
	}
	dict set details x$key $new
    }

    puts -nonewline "Saving ... "
    location update $location $details
    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::location::staff_show {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]

    puts "Staff of \"[color name [location 2name $location]]\":"
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

proc ::cm::location::staff_create {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]
    set position [$config @position]
    set name     [$config @name]
    set phone    [$config @phone]
    set email    [$config @email]

    if {($phone eq {}) && ($email eq {})} {
	util user-error "We need either phone or email, you cannot leave both undefined." \
	    LOCATION STAFF CONTACT
    }

    puts "Adding \"$position\" to location \"[color name [location 2name $location]]\" ... "
    puts -nonewline "  \"[color name $name]\" (P: $phone) (E: $email) ... "
    flush stdout

    location new-staff $location $position $name $email $phone

    puts [color good OK]
    return
}

proc ::cm::location::staff_delete {config} {
    debug.cm/location {}
    location setup
    db show-location

    set location [$config @location]
    lassign [$config @name] staff position name

    puts "Removing staff from location \"[color name [location 2name $location]]\" ... "
    puts -nonewline "  $position \"[color name $name]\" ... "
    flush stdout

    location delete-staff $staff

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::location::test-known {config} {
    debug.cm/location {}
    location setup

    util pdict [location known]
    return
}

proc ::cm::location::test-select {config} {
    debug.cm/location {}
    location setup

    util pdict [cm::db::location::Selection]
    return
}

proc ::cm::location::test-staff-known {config} {
    debug.cm/location {}
    location setup

    ShowCurrent
    util pdict [location known-staff]
    return
}

proc ::cm::location::test-staff-select {config} {
    debug.cm/location {}
    location setup

    ShowCurrent
    util pdict [cm::db::location::SelectionStaff [cm::db::location::Current]]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::location::ShowCurrent {} {
    set location [location current]
    if {$location == -2} {
	util user-error \
	    "Current location is bad, please \"select\" one" \
	    LOCATION CURRENT BAD
    } elseif {$location == -1} {
	util user-error \
	    "No current location chosen, please \"select\" one"
	    LOCATION CURRENT MISSING
    } else {
	puts [color name [location 2name $location]]
    }
}

# # ## ### ##### ######## ############# ######################
package provide cm::location 0
return
