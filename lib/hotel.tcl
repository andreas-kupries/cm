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
#package require interp
#package require linenoise
#package require textutil::adjust
package require try

package require cm::table
#package require cm::util
package require cm::db
#package require cm::validate::hotel

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::hotel {
    namespace export cmd_create cmd_list
    namespace ensemble create

    namespace import ::cmdr::color
    #namespace import ::cm::util
    namespace import ::cm::db

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

    [table t {Name Street Zip City} {
	db do eval {
	    SELECT H.name                 AS name,
	           H.streetaddress        AS street,
	           H.zipcode              AS zip,
	           C.name||", "||C.nation AS city
	    FROM  hotel H,
	          city C
	    WHERE C.id = H.city
	    ORDER BY H.name, city
	} {
	    $t add $name $street $zip $city
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
    set zip [$config @zipcode]

    set str $name
    puts -nonewline "Creating hotel \"[color note $str]\" ... "

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

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::hotel::Setup {} {
    debug.cm/hotel {}
    upvar 1 config config
    db do version ;# Initialize db access.

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
