#!/usr/bin/env tclsh
## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm ?
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     sqlite3
# Meta require     cmdr
# Meta require     {Tcl 8.5-}
# Meta require     lambda
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::color ; # color activation
package require cmdr::history
package require cmdr::help::tcl
package require cmdr::actor 1.3 ;# Need -extend support for common/use blocks.
package require cmdr
package require debug
package require debug::caller
package require lambda

#package require cm::seen  ; # set-progress

# # ## ### ##### ######## ############# ######################

debug level  cm
debug prefix cm {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval cm {
    namespace export main
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::cm::main {argv} {
    debug.cm {}
    try {
	cm do {*}$argv
    } trap {CMDR CONFIG WRONG-ARGS} {e o} - \
      trap {CMDR CONFIG BAD OPTION} {e o} - \
      trap {CMDR VALIDATE} {e o} - \
      trap {CMDR ACTION UNKNOWN} {e o} - \
      trap {CMDR ACTION BAD} {e o} - \
      trap {CMDR VALIDATE} {e o} - \
      trap {CMDR PARAMETER LOCKED} {e o} - \
      trap {CMDR DO UNKNOWN} {e o} {
	debug.cm {trap - cmdline user error}
	puts stderr "$::argv0 cmdr: [cmdr color error $e]"
	return 1

    } trap {CM} {e o} {
	debug.cm {trap - other user error}
	puts stderr "$::argv0 general: [cmdr color error $e]"
	return 1
	
    } on error {e o} {
	debug.cm {trap - general, internal error}
	debug.cm {[debug pdict $o]}
	# TODO: nicer formatting of internal errors.
	puts stderr [cmdr color error $::errorInfo]
	return 1
    }

    debug.cm {done, ok}
    return 0
}

# # ## ### ##### ######## ############# ######################
## Support commands constructing glue for various callbacks.

proc ::cm::no-search {} {
    lambda {p x} {
	$p config @repository-active set off
    }
}

# NOTE: call, vt, sequence, exclude - Possible convenience cmds for Cmdr.
proc ::cm::call {p args} {
    lambda {p args} {
	package require cm::$p
	cm::$p {*}$args
    } $p {*}$args
}

proc ::cm::vt {p args} {
    lambda {p args} {
	package require cm::validate::$p
	cm::validate::$p {*}$args
    } $p {*}$args
}

proc ::cm::sequence {args} {
    lambda {cmds p x} {
	foreach c $cmds {
	    {*}$c $p $x
	}
    } $args
}

proc ::cm::exclude {locked} {
    # Jump into the context of the parameter instance currently
    # getting configured. At the time the spec is executed things
    # regarding naming are in good enough shape to extract naming
    # information. While aliases for options are missing these are of
    # no relevance to our purpose here either, we need only the
    # primary name, and that is initialized by now.

    set by [uplevel 2 {my the-name}]
    lambda {locked by p args} {
	#debug.cmdr {}
	$p config @$locked lock $by
    } $locked $by
}

# # ## ### ##### ######## ############# ######################

cmdr history initial-limit 20
cmdr history save-to       ~/.cm_history

cmdr create cm::cm [file tail $::argv0] {
    ##
    # # ## ### ##### ######## ############# #####################

    description {
	The cm command line client
    }

    shandler ::cmdr::history::attach

    # # ## ### ##### ######## ############# #####################
    ## Bespoke category ordering for help
    ## Values are priorities. Final order is by decreasing priority.
    ## I.e. Highest priority is printed first, at the top, beginning.

    common *category-order* {
	Convenience -8900
	Advanced    -9000
    }

    # # ## ### ##### ######## ############# ######################
    ## Common pieces across the various commands.

    #common *all* {}

    # Global options, and state based on it.

    option database {
	Path to the database of managed conferences
    } {
	alias db
	alias D
	validate rwfile
	generate [cm::call db default-location]
    }
    state managed {
	The database we are working with.
    } {
	generate [cm::call db make]
    }

    option debug {
	Placeholder. Processed before reaching cmdr.
    } {
	undocumented
	argument section
	validate [cm::vt debug]
	default {}
    }

    option colormode {
	Set color mode (always|auto|never) of the application.
	The default of "auto" activates color depending on the
	environment, active when talking to a tty, and
	otherwise not.
    } {
	argument mode
	label color
	validate  [cm::vt colormode]
	# React early to user settings.
	when-set [lambda {p x} {
	    switch -exact -- $x {
		auto   {
		    # Nothing to do, system default, already in place.
		}
		always { cmdr color activate 1 }
		never  { cmdr color activate 0 }
	    }
	}]
    }

    # # ## ### ##### ######## ############# ######################

    private version {
	section Introspection
	description {
	    Print version and revision of the application.
	}
    } [lambda config {
	puts "[file tail $::argv0] [package present cm]"
    }]

    # # ## ### ##### ######## ############# ######################
    ## Manage configuration

    officer config {
	description {
	    Manage the conference-independent configuration of the application.
	}
	private set {
	    section Configuration
	    description {Change setting}
	    input key {
		The name of the setting to change
	    } {
		validate [cm::vt config]
	    }
	    input value {
		The value to assign
	    } {}
	} [cm::call config cmd_set]

	private unset {
	    section Configuration
	    description {Drop setting back to its default}
	    input key {
		The name of the setting to drop
	    } {
		validate [cm::vt config]
	    }
	} [cm::call config cmd_unset]

	private list {
	    section Configuration
	    description {Show the current state of all settings}
	} [cm::call config cmd_list]
	default
    }

    # # ## ### ##### ######## ############# ######################
    ## Manage cities

    officer city {
	description {
	    Manage the cities containing relevant locations
	}
	# -- name, state, nation
	# -- (1:n) locations

	private create {
	    section {City Management}
	    description { Create a new city for locations }
	    input name   { description {Name of the city}        }
	    input state  { description {State the city is in}    }
	    input nation { description {Nation the state is in}  }
	} [cm::call city cmd_create]
	alias new
	alias add

	private list {
	    section {City Management}
	    description { Show a table of all known cities }
	} [cm::call city cmd_list]

	# remove - if not used
	# modify - change state, nation
    }
    alias cities = city list

    # # ## ### ##### ######## ############# ######################
    ## Manage locations, i.e. hotels, resorts, etc.

    officer hotel {
	description {
	    Manage hotels and other locations (when hotel != session)
	}
	# -- name, city, streetaddress, zip, book/local (fax, phone, url), transport
	# -- (n:1) city
	# -- (1:n) hotel_staff
	# -- (1:n) conference

	private create {
	    section {Hotel Management}
	    description { Create a new hotel }

	    input name          { Name of the hotel }                 { optional ; interact {Name:    } }
	    input streetaddress { Location of the hotel in the city } { optional ; interact {Street:  } }
	    input zipcode       { Postal code of the location }       { optional ; interact {Zipcode: } }
	    state city          { City the hotel is in }              { generate [cm::call city select] }

	    # Contact details, and staff information to be set after
	    # the fact (of creation).

	} [cm::call hotel cmd_create]
	alias new
	alias add

	private list {
	    section {Hotel Management}
	    description { Show a table of all known hotels }
	} [cm::call hotel cmd_list]

	private select {
	    section {Hotel Management}
	    description { Select a specific hotel for further operation }
	    input hotel {
		Hotel to operate on in the future - The "current" hotel
	    } {
		optional
		# TODO: validator <=> hotel identification (name + city)
		generate [cm::call hotel select]
	    }
	} [cm::call hotel cmd_select]

	private show {
	    section {Hotel Management}
	    description { Show the details of the current hotel }
	} [cm::call hotel cmd_show]

	private contact {
	    section {Hotel Management}
	    description { Set the contact information of the current hotel }
	} [cm::call hotel cmd_contact]

	private map {
	    section {Hotel Management}
	    description {
		Set the map, directions, transport information of the current hotel.
		Note: The data is read from stdin.
	    }
	} [cm::call hotel cmd_map]
	alias directions
	alias transport
	alias note

	# remove - if not used
	# modify - change name, street, zip, city (rename, relocate/move)
    }
    alias hotels    = hotel list
    alias locations = hotel list

    # # ## ### ##### ######## ############# ######################
    ## Developer support, feature test and repository inspection.

    officer test {
	description {
	    Various commands to test the system and its configuration.
	}
	common *all* -extend {
	    section Advanced Testing
	}
    }

    # # ## ### ##### ######## ############# ######################
    ## Developer support, debugging.

    officer debug {
	description {
	    Various commands to help debugging the system itself
	    and its configuration.
	}
	common *all* -extend {
	    section Advanced Debugging
	}

	private levels {
	    description {
		List all the debug levels known to the system,
		which we can enable to gain a (partial) narrative
		of the application-internal actions.
	    }
	} [cm::call debug cmd_levels]
    }
}

# # ## ### ##### ######## ############# ######################
package provide cm 0
return
