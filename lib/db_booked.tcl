## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::db::booked 0
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
package require debug
package require debug::caller
package require try

package require cm::db

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}
namespace eval ::cm::db {
    namespace export booked
    namespace ensemble create
}
namespace eval ::cm::db::booked {
    namespace export listing add remove setup dump
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## ############# ######################

debug level  cm/db/booked
debug prefix cm/db/booked {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::db::booked::listing {conference} {
    debug.cm/db/booked {}
    setup

    return [db do eval {
	SELECT CO.dname        AS dname
	,      L.id            AS location
	,      L.name          AS locname
	,      L.streetaddress AS street
	,      L.zipcode       AS zip
	,      CY.name         AS cityname
	,      CY.state        AS state
	,      CY.nation       AS nation
	FROM booked     B
	,    contact    CO
	,    conference C
	,    location   L
	,    city       CY
	WHERE B.conference = :conference
	AND   B.conference = C.id
	AND   B.contact    = CO.id
	AND   B.hotel      = L.id
	AND   L.city       = CY.id
	ORDER BY dname
    }]
}

proc ::cm::db::booked::add {conference contact hotel} {
    debug.cm/db/booked {}
    setup

    db do eval {
	INSERT
	INTO booked
	VALUES (NULL,
		:conference,
		:contact,
		:hotel)
    }
    return [db do last_insert_rowid]
}

proc ::cm::db::booked::remove {conference contact} {
    debug.cm/db/booked {}
    setup

    db do eval {
	DELETE
	FROM booked
	WHERE conference = :conference
	AND   contact    = :contact
    }
    return
}

# # ## ### ##### ######## ############# ######################

cm db setup cm::db::booked {
    debug.cm/db/booked {}

    # TODO: booked - setup conference
    db use contact
    db use location

    if {![dbutil initialize-schema ::cm::db::do error booked {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER NOT NULL REFERENCES conference,
	    contact	INTEGER NOT NULL REFERENCES contact,	-- can_book (person)
	    hotel	INTEGER	NOT NULL REFERENCES location,	-- may not be the conference hotel!
	    UNIQUE (conference, contact)
	} {
	    {id         INTEGER 1 {} 1}
	    {conference INTEGER 1 {} 0}
	    {contact    INTEGER 1 {} 0}
	    {hotel      INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error booked $error
    }
    return
}

proc ::cm::db::booked::dump {conference} {
    # We can assume existence of the 'cm dump' ensemble.
    debug.cm/db/booked {}
    setup

    # booked
    set first 1
    db do eval {
	SELECT C.dname  AS contact
	,      L.name   AS name
	,      Y.name   AS city
	,      Y.state  AS state
	,      Y.nation AS nation
	FROM   booked   B
	,      contact  C
	,      location L
	,      city     Y
	WHERE B.conference = :conference
	AND   B.contact    = C.id
	AND   B.hotel      = L.id
	AND   L.city       = Y.id
	ORDER BY contact, name, city, state, nation
    } {
	if {$first} { cm dump step ; set first 0 }

	if {$state ne {}} {
	    set hname "$name $city $state $nation"
	} else {
	    set hname "$name $city $nation"
	}

	cm dump save \
	    booking add $contact $hname
    }

    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::db::booked 0
return
