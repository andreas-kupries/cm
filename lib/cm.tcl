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
package require cmdr::actor 1.3 ;# Need -extend support for common/use blocks.
package require cmdr::color ; # color activation
package require cmdr::help::tcl
package require cmdr::history
package require cmdr::pager 1.1
package require cmdr
package require debug
package require debug::caller
package require lambda
package require cmdr::table

cmdr color define heading =bold ;# Table header color.
cmdr table show \
    ::cmdr pager

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
      trap {CMDR PARAMETER UNDEFINED} {e o} - \
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
	puts stderr [cmdr color error $::errorCode]
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
proc ::cm::call-db {p args} {
    lambda {p args} {
	package require cm::db::$p
	cm::db::$p {*}$args
    } $p {*}$args
}

proc ::cm::call {p args} {
    lambda {p args} {
	package require cm::$p
	cm::$p {*}$args
    } $p {*}$args
}

proc ::cm::vt {p args} {
    lambda {p args} {
	package require cm::validate::$p
	try {
	    cm::validate::$p {*}$args
	} on error {e o} {
	    # DEBUGGING when 'complete' fails in interaction.
	    # ==> handle in Cmdr...
	    #puts "VT: $e"
	    #puts "VT: $o"
	    return {*}$o $e
	}
    } $p {*}$args
}

proc ::cm::cvt {p args} {
    lambda {p args} {
	package require cmdr::validate::$p
	cmdr::validate::$p {*}$args
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
cmdr history save-to       ~/.cm/history

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
	{Conference Management} 0
	{Hotel Management}      -10
	{City Management}       -20

	Convenience -8900
	Advanced    -9000
    }

    # # ## ### ##### ######## ############# ######################
    ## Common pieces across the various commands.

    # Global options, and state based on it.

    option database {
	Path to the database of managed conferences
    } {
	alias db
	alias D
	validate rwfile
	generate [cm::call db default-location]
	#when-set ... generate db immediately ?
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

    option no-prompt {
	Disable interactive queries.
    } {
	presence
	alias n
	alias non-interactive
	alias noprompt
	# Note: Global disabling of all interactivity. Use first
	# to affect all other input. Also the reason for when-set
	# instead of when-complete. Must be handled early to cut off
	# interactive entry in cmdr::private, where possible.
	when-set [lambda {p x} {
	    cmdr interactive [expr {!$x}]
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
    ## Backups and content transfer.

    private save {
	section Backup
	description {Save database as readable and executable Tcl script}
	# By generating a Tcl script which directly executes cm commands
	# an explicit restore command is superfluous.
	input destination {
	    Path to the file to save the databae to.
	    Note that an existing file will be overwritten.
	} { validate wfile }
    } [cm::call dump cmd]

    # # ## ### ##### ######## ############# ######################
    ## Manage configuration

    officer config {
	description {
	    Manage the conference-independent configuration of the application.
	}
	private set {
	    section Configuration
	    description {
		Change the value of the specified setting.
	    }
	    input key {
		The name of the setting to change
	    } { validate [cm::vt config] }
	    input value {
		The value to assign
	    } {}
	} [cm::call config update]

	private unset {
	    section Configuration
	    description {
		Drop the value of the specified setting back to its default.
	    }
	    input key {
		The name of the setting to drop.
	    } { validate [cm::vt config] }
	} [cm::call config undef]

	private get {
	    section Configuration
	    description {
		Print the current value of the specified setting to stdout
	    }
	    input key {
		The name of the setting to print.
	    } { validate [cm::vt config] }
	} [cm::call config get]

	private list {
	    section Configuration
	    description {Show the current state of all settings}
	} [cm::call config listall]
	default
    }

    # # ## ### ##### ######## ############# ######################
    ## Manage mail templates

    officer template {
	description {
	    Manage the text templates used for mail campaigns and web-site generation.
	}

	private list {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Show a table of all known templates }
	} [cm::call template list-all]
	default

	private show {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Show the text of the named template }
	    input name {
		Name of the template to show
	    } { validate [cm::vt template] }
	} [cm::call template show]

	private new {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Create a new template. }
	    input name {
		Name of the template to create. Normalized to lower-case.
	    } { validate [cm::vt nottemplate] }
	    input text {
		The contents of the template. If not specified stdin is read.		
	    } { optional }
	} [cm::call template create]
	alias add
	alias create

	private delete {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Remove the named template }
	    input name {
		Name of the template to delete.
	    } { validate [cm::vt template] }
	} [cm::call template remove]
	alias drop
	alias remove

	private update {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Update the contents of the named template. }
	    input name {
		Name of the template to update
	    } { validate [cm::vt template] }
	    input text {
		The new contents of the template. If not specified stdin is read.		
	    } { optional }
	} [cm::call template update]
	alias set
	alias replace
    }
    alias templates = template list

    # # ## ### ##### ######## ############# ######################
    ## Manage cities (for locations)

    officer city {
	description {
	    Manage the cities containing relevant locations
	}
	# -- name, state, nation
	# -- (1:n) locations

	private new {
	    section {City Management}
	    description { Create a new city for locations }
	    input name   { description {Name of the city}        }
	    input state  { description {State the city is in}    }
	    input nation { description {Nation the state is in}  }
	} [cm::call city create]
	alias create
	alias add

	private delete {
	    section {City Management}
	    description { Delete the specified city }
	    input city {
		The city to delete
	    } {
		optional
		validate [cm::vt city]
		generate [cm::call-db city select]
	    }
	} [cm::call city delete]
	alias remove
	alias drop

	private show {
	    section {City Management}
	    description { Show the details for the specified city }
	    input city {
		The city to show
	    } {
		optional
		validate [cm::vt city]
		generate [cm::call-db city select]
	    }
	} [cm::call city show]

	private list {
	    section {City Management}
	    description { Show a table of all known cities }
	} [cm::call city list-all]

	# TODO: modify cities - change name, state, nation
    }
    alias cities = city list

    # # ## ### ##### ######## ############# ######################
    ## Manage locations, i.e. hotels, resorts, conference centers, etc.

    officer location {
	description {
	    Manage hotels and facilities
	}
	# -- name, city, streetaddress, zip, book/local (fax, phone, url), transport
	# -- (n:1) city
	# -- (1:n) location_staff
	# -- (1:n) conference

	common .justcurrent {
	    state location {
		The current location
	    } {
		generate [cm::call-db location select]
	    }
	}
	common .location {
	    input location {
		The location to work with.
	    } {
		optional
		validate [cm::vt location]
		generate [cm::call-db location select]
	    }
	}

	common .rq_location {
	    input location {
		The location to work with.
	    } {
		validate [cm::vt location]
	    }
	}

	private new {
	    section {Location Management}
	    description { Create a new location }

	    input name          { Name of the location }              { optional ; interact {Name:    } }
	    input streetaddress { Where the location is in the city } { optional ; interact {Street:  } }
	    input zipcode       { Postal code of the location }       { optional ; interact {Zipcode: } }
	    input city          { City the location is in }           {
		optional
		validate [cm::vt city]
		generate [cm::call-db city select]
	    }

	    # Contact details, and staff information to be set after
	    # the fact (of creation).

	} [cm::call location create]
	alias create
	alias add

	private delete {
	    section {Location Management}
	    description { Delete the specified or current location }
	    use .location
	} [cm::call location delete]
	alias remove
	alias drop

	private show {
	    section {Location Management}
	    description { Print the details of the specified or current location }
	    use .location
	} [cm::call location show]

	private list {
	    section {Location Management}
	    description { Show a table of all known locations }
	} [cm::call location list-all]

	private current {
	    section {Location Management}
	    description { Print the current location, if any }
	} [cm::call location current]
	default

	private current-reset {
	    section {Location Management}
	    description { Unset the current location, if any }
	} [cm::call location current-reset]

	private select {
	    section {Location Management}
	    description { Select a specific location for further operation }
	    # This command has to ignore the 'current' selection even if there is one.
	    input location {
		The new current location.
	    } {
		optional
		validate [cm::vt location]
		generate [cm::call-db location select-always]
	    }
	} [cm::call location select]

	private contact {
	    section {Location Management}
	    description { Set the contact information of the current location }
	    use .justcurrent
	    input bookphone  {Phone number for booking rooms} { optional }
	    input bookfax    {Fax number for booking rooms}   { optional }
	    input booklink   {Website for booking rooms}      { optional }
	    input localphone {Direct phone to the hotel}      { optional }
	    input localfax   {Direct fax to the hotel}        { optional }
	    input locallink  {Direct website of the hotel}    { optional }
	} [cm::call location contact_set]

	private map-set {
	    section {Location Management}
	    description {
		Set the map, directions, transport information of the current location.
		Note: The data is read from stdin.
	    }
	    use .rq_location
	    input map {
		The new contents of the map, etc. information.
		If not specified stdin is read.		
	    } { optional }
	} [cm::call location map_set]
	alias directions-set
	alias transport-set
	alias note-set

	private map {
	    section {Location Management}
	    description {
		Return the map and other hotel specific data.
	    }
	    use .location
	} [cm::call location map_get]
	alias directions
	alias transport
	alias note

	private add-staff {
	    section {Location Management}
	    description {
		Add one or more staff to the specified or current location
	    }
	    use .justcurrent
	    input position {
		The role/position to staff
	    } { optional ; interact ; generate [stop!] }
	    input name {
		Staff name
	    } { optional ; interact ; generate [stop!] }
	    input phone {
		Staff phone
	    } { optional ; interact ; generate [stop!] } ;# can we validate a phone number ?
	    input email {
		Staff email
	    } { optional ; interact ; validate [cm::vt mail-address]
		generate [stop!] }
	} [cm::call location staff_create]

	private drop-staff {
	    section {Location Management}
	    description {
		Remove one or more staff from the specified or current location.
	    }
	    use .justcurrent
	    input name {
		Position and name of the staff to remove
	    } { 
		optional
		generate [cm::call-db location select-staff]
		validate [cm::vt location-staff]
	    }
	} [cm::call location staff_delete]

	private staff {
	    section {Location Management}
	    description {
		Print staff information for the specified or current location
	    }
	    use .location
	} [cm::call location staff_show]

	# modify - change name, street, zip, city (rename, relocate/move)
    }
    alias hotels     = location list
    alias locations  = location list
    alias facilities = location list

    # # ## ### ##### ######## ############# ######################
    ## Manage tutorials (shared among conferences)

    officer tutorial {
	description {
	    Manage the tutorials we can or have offered in conferences.
	}

	private list {
	    section {Tutorial Management}
	    description { Show a table of all known tutorials }
	} [cm::call tutorial list-all]

	private show {
	    section {Tutorial Management}
	    description { Show the text of the specified tutorial }
	    input name {
		Identifier of the tutorial to show (handle, tag, unambigous part of the title)
	    } { optional ; generate [cm::call-db tutorial select] ; validate [cm::vt tutorial] }
	} [cm::call tutorial show]

	private create {
	    section {Tutorial Management}
	    description { Create a new tutorial to offer. }

	    option requisites {
		Knowledge needed to take the course.
	    } { alias prereq ; alias R ; validate str }

	    input speaker {
		The speaker/lecturer offering the tutorial.
	    } { validate [cm::vt contact] } ; # TODO validator person

	    # Note: tag and title are unique only within the context
	    # of the speaker. I.e. the speaker must be known for the
	    # validations below to work. Reason for why the speaker is
	    # first.
	    input tag {
		Short tag for the tutorial, must be usable in an html anchor.
	    } { validate [cm::vt nottutorialtag] }
	    input title {
		Title of the new tutorial
	    } { optional ; interact ; validate [cm::vt nottutorial] }

	    input description {
		The description of the course.
	    } { optional ; validate str }

	} [cm::call tutorial create]
	alias add
	alias new

	private set-title {
	    section {Tutorial Management}
	    description { Change title of the named tutorial }
	    input tutorial {
		The tutorial to change
	    } { validate [cm::vt tutorial] }
	    input text { The new text to set }
	} [cm::call tutorial set-title]
	alias change-title

	private set-description {
	    section {Tutorial Management}
	    description { Change description of the named tutorial }
	    input tutorial {
		The tutorial to change
	    } { validate [cm::vt tutorial] }
	    # TODO: This would be useful to have a mode taking either a path to a file, or reading stdin.
	    input text { The new text to set } { optional }
	} [cm::call tutorial set-desc]
	alias change-description

	private set-prereq {
	    section {Tutorial Management}
	    description { Change description of the named tutorial }
	    input tutorial {
		The tutorial to change
	    } { validate [cm::vt tutorial] }
	    input text { The new text to set }
	} [cm::call tutorial set-req]
	alias change-prereq

	private set-tag {
	    section {Tutorial Management}
	    description { Change tag of the named tutorial }
	    input tutorial {
		The tutorial to change
	    } { validate [cm::vt tutorial] }
	    input text { The new text to set }
	} [cm::call tutorial set-tag]
	alias change-tag

	# TODO tutorial operations: remove (if not used), retag,
    }
    alias tutorials = tutorial list

    # # ## ### ##### ######## ############# ######################
    ## Manage conferences

    officer conference {
	description {
	    Manage conferences
	}
	# -- (n:1) city, location (hotel, facility)
	# title, year, start, end, talk-length, session-length
	# alignment (specific weekday, or none), length in days

	# - -- --- ----  -------- ------------- ----------------------

	private create {
	    section {Conference Management}
	    description { Create a new conference }

	    option current {
		Make new conference current
	    } { default yes }

	    input title {
		Name of the conference
	    } { optional ; interact ; generate [stop!] }

	    input year {
		Year of the conference
	    } { optional ; interact ; validate [cm::cvt year]
		generate [stop!] }

	    input alignment {
		Alignment within the week
	    } { optional ; validate [cm::cvt weekday] ; default -1 }

	    input start {
		Start date
	    } { optional ; interact ; validate [cm::cvt date]
		generate [stop!] }

	    input length {
		Length in days
	    } { optional ; interact ; validate [cm::cvt posint]
		generate [stop!] }

	    input manager {
		Person or organization managing the conference
	    } { optional ; interact ; validate [cm::vt contact]
		generate [stop!] }

	    input submission {
		Email address for submissions to be sent to.
	    } { optional ; interact ; validate [cm::vt email]
		generate [stop!] }

	    # Set later: hotel, facility, city

	} [cm::call conference cmd_create]
	alias new
	alias add

	private list {
	    section {Conference Management}
	    description { Show a table of all known conferences }
	} [cm::call conference cmd_list]

	private select {
	    section {Conference Management}
	    description { Select a specific conference for further operation }
	    input conference {
		Conference to operate on in the future - The "current" conference
	    } {
		optional
		# TODO: validator <=> conference identification (name + city)
		generate [cm::call conference select]
	    }
	} [cm::call conference cmd_select]

	private show {
	    section {Conference Management}
	    description { Show the details of the current conference }
	} [cm::call conference cmd_show]

	# - -- --- ----  -------- ------------- ----------------------

	private timeline-init {
	    section {Conference Management}
	    description { Generate a basic timeline for the conference }
	} [cm::call conference cmd_timeline_init]

	private timeline-clear {
	    section {Conference Management}
	    description { Clear the timeline for the conference }
	} [cm::call conference cmd_timeline_clear]

	private timeline-shift {
	    section {Conference Management}
	    description { Shift an event of the timeline for the conference }
	    input event {
		The event to shift.
	    } {	optional
		validate [cm::vt timeline]
		generate [cm::call-db timeline select]
	    }
	    input shift {
		Number of days to shift the event by.
		Negative numbers to the past, positive numbers to the future.
	    } {	optional ; interact ; validate integer ; generate [stop!] }
	    # TODO: Note, bad interaction between optional arg, neg sign of numbers, and option processing of cmdr ... See if fixable.
	} [cm::call conference cmd_timeline_shift]

	private timeline-set {
	    section {Conference Management}
	    description { Set an event of the timeline for the conference to an exact date }
	    input event {
		The event to set the date of.
	    } {	optional
		validate [cm::vt timeline]
		generate [cm::call-db timeline select]
	    }
	    input date {
		The new date for the event.
	    } {	optional ; interact ; validate [cm::cvt date]
		generate [stop!] }
	} [cm::call conference cmd_timeline_set]

	private timeline-done {
	    section {Conference Management}
	    description { Mark an event on the timeline for the conference as done. }
	    input event {
		The event to mark as done.
	    } {	optional
		validate [cm::vt timeline]
		generate [cm::call-db timeline select]
	    }
	} [cm::call conference cmd_timeline_done]

	private timeline {
	    section {Conference Management}
	    description { Show the timeline for the conference }
	} [cm::call conference cmd_timeline_show]

	# - -- --- ----  -------- ------------- ----------------------

	private facility {
	    section {Conference Management}
	    description { Select the location for presentations }
	    input location { Conference facility } {
		optional
		validate [cm::vt location]
		generate [cm::call-db location select]
	    }
	} [cm::call conference cmd_facility]

	private hotel {
	    section {Conference Management}
	    description { Select the conference hotel }
	    input location { Conference hotel } {
		optional
		validate [cm::vt location]
		generate [cm::call-db location select]
	    }
	} [cm::call conference cmd_hotel]

	# - -- --- ----  -------- ------------- ----------------------

	private add-sponsor {
	    section {Conference Management}
	    description { Add one or more sponsoring contacts }
	    input name {
		Names of the contacts to add
	    } { list ; optional ; interact ; validate [cm::vt contact] ; # TODO validator not m-lists
		generate [stop!] }
	} [cm::call conference cmd_sponsor_link]

	private drop-sponsor {
	    section {Conference Management}
	    description { Remove a sponsoring contact }
	    input name {
		Name of the contact to remove
	    } { 
		optional
		generate [cm::call conference select-sponsor]
		validate [cm::vt sponsor]
	    }
	} [cm::call conference cmd_sponsor_unlink]

	private sponsors {
	    section {Conference Management}
	    description { Show the sponsors of the conference }
	} [cm::call conference cmd_sponsor_show]

	private sponsor-ping {
	    section {Conference Management}
	    description { Send a mail to the sponsors }
	    option dry {
		When present do not actually mail anything.
	    } { presence }
	    input template {
		Name of the template holding mail subject and body.
	    } { optional ; 
		generate [cm::call-db template find-p mail-sponsors]
		validate [cm::vt template] }
	    # TODO: Allow for external file and/or stdin as mail input.
	} [cm::call conference cmd_sponsor_ping]

	# - -- --- ----  -------- ------------- ----------------------

	private add-staff {
	    section {Conference Management}
	    description { Add one or more staff }
	    input role {
		The role to staff
	    } {
		optional
		validate [cm::vt staff-role]
		generate [cm::call db::staff-role select]
	    }
	    input name {
		Names of the contacts which are staff
	    } { list ; optional ; interact ; validate [cm::vt contact] ; # TODO validator people only
		generate [stop!] }
	} [cm::call conference cmd_staff_link]

	private drop-staff {
	    section {Conference Management}
	    description { Remove a staffer }
	    input name {
		Name of the staff to remove
	    } { 
		optional
		generate [cm::call conference select-staff]
		validate [cm::vt conference-staff]
	    }
	} [cm::call conference cmd_staff_unlink]

	private staff {
	    section {Conference Management}
	    description { Show the staff of the conference }
	} [cm::call conference cmd_staff_show]

	private committee-ping {
	    section {Conference Management}
	    description { Send a mail to the program committee }
	    option dry {
		When present do not actually mail anything.
	    } { presence }
	    input template {
		Name of the template holding mail subject and body.
	    } { optional ; 
		generate [cm::call-db template find-p mail-committee]
		validate [cm::vt template] }
	    # TODO: Allow for external file and/or stdin as mail input.
	} [cm::call conference cmd_committee_ping]

	# TODO: Full staff ping.

	# - -- --- ----  -------- ------------- ----------------------

	private schedule {
	    section {Conference Management}
	    description { Link a schedule to the conference }
	    input name {
		The name of the schedule to use.
	    } {
		optional
		validate [cm::vt pschedule]
		generate [cm::call schedule active-or-select]
	    }
	} [cm::call conference cmd_schedule_set]

	private schedule-show {
	    section {Conference Management}
	    description { Show the current logical schedule for the conference }
	} [cm::call conference cmd_schedule_show]

	private schedule-edit {
	    section {Conference Management}
	    description { Edit the logical schedule for the conference }
	    input label {
		Name of the slot to edit.
	    } { validate [cm::vt schedule-slot] }
	    input type {
		New type of the slot
	    } { validate [cm::vt schedule-slot-type] }
	    input value {
		New value of the slot, type-dependent interpretation.
	    } { validate [cm::vt schedule-slot-value] }
	} [cm::call conference cmd_schedule_edit]

	# TODO: Drop physical schedule, integrated drop of logical entries.
	# - -- --- ----  -------- ------------- ----------------------

	private rate {
	    section {Conference Management}
	    description { Set the room rate information }
	    # conference - implied, current
	    # location   - implied, by conference (hotel)
	    # (rate, factor, currency) - required
	    # groupcode, begin/end/deadline/publicdeadline
	    option groupcode {
		Groupcode to get the discounted rate
	    } { alias G ; argument text ; validate str }
	    option begin {
		Start of the validity period for discounted rate. Default: Conference start.
	    } { alias from ; alias F ; argument date ; validate [cm::cvt date] }
	    option end {
		End of the validity period for discounted rate. Default: Conference end.
	    } { alias to ; alias T ; argument date ; validate [cm::cvt date] }
	    option deadline {
		End of the period where you can register for the discounted rate.
		Default: 2 weeks before (--begin).
	    } { alias D ; argument date ; validate [cm::cvt date] }
	    option public-deadline {
		Disclosed end of the period where you can register for the discounted rate.
		Default: 1 week before (--deadline)
	    } { alias P ; argument date ; validate [cm::cvt date] }
	    input rate     { Discounted room rate, in currency }  { validate ::cmdr::validate::double }
	    # something defined a 'double' procedure wrapping 'expr double()'.
	    input currency { Currency of the rate }               { }
	    input decimal  { Decimal points to store, default 2 } { optional ; default 2 ; validate [cm::cvt posint] }
	} [cm::call conference cmd_rate_set]

	private rates {
	    section {Conference Management}
	    description { Show the conference rates }
	} [cm::call conference cmd_rate_show]

	# - -- --- ----  -------- ------------- ----------------------

	private set-end {
	    section {Conference Management} Advanced
	    description { Set/fix the conference end-date }
	    input enddate {
		New end date
	    } { optional ; interact ; validate [cm::cvt date] }
	} [cm::call conference cmd_end_set]

	# - -- --- ----  -------- ------------- ----------------------
	# TODO: conference remove - if not used
	# TODO: conference modify - change title, start, length, alignment

	# - -- --- ----  -------- ------------- ----------------------

	private make-website {
	    section {Conference Management}
	    description { Create a website from the conference information }
	    input destination {
		Path to the directory to create the website.
	    } { optional ; default conweb
		;#validate wdirectory - TODO cmdr
	    }
	} [cm::call conference cmd_website_make]

	private registration {
	    section {Conference Management}
	    description { Set the registration status of the conference. }
	    input status {
		The new registration status.
	    } { validate [cm::vt rstatus] }
	} [cm::call conference cmd_registration]

	# - -- --- ----  -------- ------------- ----------------------

	private add-tutorial {
	    section {Conference Management}
	    description { Add a tutorial to the lineup }

	    input day {
		Day of the tutorial as integer - 1 <=> 1st day of conference, etc.
	    } { validate [cm::cvt posint] }
	    input half {
		Overall part of the day for the tutorial (morning, afternoon, evening)
	    } { validate [cm::vt dayhalf] }
	    input track {
		On days with multiple tutorials in parallel, the id of the track.
	    } { validate [cm::cvt posint] }
	    input tutorial {
		The tutorial to add
	    } { optional
		validate [cm::vt tutorial]
		generate [cm::call-db tutorial select] }
	} [cm::call conference cmd_tutorial_link]

	private drop-tutorial {
	    section {Conference Management}
	    description { Remove one or more tutorials from the lineup }
	    input tutorial {
		Identifiers of the tutorials to remove
	    } { 
		optional ; list
		generate [cm::call-db tutorial select]
		validate [cm::vt tutorial]
	    }
	} [cm::call conference cmd_tutorial_unlink]

	private tutorials {
	    section {Conference Management}
	    description { Show the tutorial lineup for the conference }
	} [cm::call conference cmd_tutorial_show]

	# - -- --- ----  -------- ------------- ----------------------
	# - -- --- ----  -------- ------------- ----------------------
    }
    alias conferences = conference list

    # # ## ### ##### ######## ############# ######################
    ## Management of registrations for a conference. Own toplevel
    ## ensemble, although it could be put under 'conference'. Less to
    ## type.

    officer registration {
	description {
	    Manage the registrations
	}

	# TODO: Reporting - x-ref with speakers, missing speakers are issues.

	private list {
	    section {Registration Management}
	    description {
		Show the set of registered people.
	    }
	} [cm::call conference cmd_registration_list]

	private add {
	    section {Registration Management}
	    description {
		Register contact with the conference.
		Options for setting up presenter discount, taken tutorials, walkin fee, etc.
	    }

	    option walkin {
		Mark a walk-in registration -- late fee
	    } { alias W ; presence }

	    # Presenter flag is automatically determined.
	    # Simply check against speakers for tutorials, keynotes and general talks.
	    # Storage is redundant, so don't.

	    option taking {
		Tutorial taken by the registrant -- fees
	    } {
		alias T ; list
		validate [cm::vt ctutorial]
	    }
	    input person {
		The person getting registered
	    } { validate [cm::vt contact] } ; # TODO validator person

	    # FUTURE: Extend with code able to tabulate and compute
	    # the conference fee taking all discounts and fees into
	    # account.
	} [cm::call conference cmd_registration_add]

	private remove {
	    section {Registration Management}
	    description {
		Drop contact from the list of registered people
	    }

	    input person {
		The person dropping their registration.
	    } { validate [cm::vt contact] } ; # TODO validator person

	} [cm::call conference cmd_registration_remove]
	alias drop
    }
    alias registered = registration list
    alias register   = registration add
    alias unregister = registration remove

    # # ## ### ##### ######## ############# ######################
    ## Management of hotel bookings for a conference. Own toplevel
    ## ensemble, although it could be put under 'conference'. Less to
    ## type.

    officer booking {
	description {
	    Manage the hotel bookings by people.
	}

	private list {
	    section {Booking Management}
	    description {
		Show the set of people having booked a hotel room for the conference, and where.
	    }
	} [cm::call conference cmd_booking_list]

	private add {
	    section {Booking Management}
	    description {
		Add contact as having booked a hotel for the conference.
		The hotel defaults to the conference hotel.
	    }
	    input person {
		The person booking a room.
	    } { validate [cm::vt contact] } ; # TODO validator person

	    input hotel { Booked hotel, defaults to conference hotel } {
		optional
		validate [cm::vt location]
		generate [cm::call conference its-hotel]
	    }

	} [cm::call conference cmd_booking_add]

	private remove {
	    section {Booking Management}
	    description {
		Drop contact from the list of people who booked their hotel for the conference.
	    }

	    input person {
		The person dropping their booking.
	    } { validate [cm::vt contact] } ; # TODO validator person

	} [cm::call conference cmd_booking_remove]
	alias drop
    }
    alias bookings = booking list
    alias booked   = booking list

    # # ## ### ##### ######## ############# ######################
    ## Submission management. Own toplevel ensemble, although it could
    ## be put under 'conference'. Less to type as is.

    officer submission {
	description {
	    Manage the submissions
	}

	private add {
	    section {Submission Management}
	    description { Submit a paper/talk proposal. The abstract is read from stdin. }
	    option on {
		Date of submission. Defaults to today.
	    } { validate [cm::cvt date]
		generate [lambda p {clock seconds}] }
	    option invited {
		Set when this is an invited talk.
	    } { presence }
	    input title {
		Title of the proposed talk
	    } { validate str }
	    input author {
		One or more authors of the talk
	    } { optional ; list ; validate [cm::vt contact] } ; # TODO validator can-submit
	} [cm::call conference cmd_submission_add]

	private drop {
	    section {Submission Management}
	    description { Remove one or more specified submissions }
	    input submission {
		The submission to drop.
	    } { list ; optional ; validate [cm::vt submission] ;
		generate [cm::call conference select-submission] }
	} [cm::call conference cmd_submission_drop]

	private set-summary {
	    section {Submission Management}
	    description { Change summary of a submission. Read from stdin. }
	    input submission {
		The submission to change
	    } { validate [cm::vt submission] }
	} [cm::call conference cmd_submission_setsummary]
	alias change-summary

	private set-abstract {
	    section {Submission Management}
	    description { Change abstract of a submission. Read from stdin. }
	    input submission {
		The submission to change
	    } { validate [cm::vt submission] }
	} [cm::call conference cmd_submission_setabstract]
	alias change-abstract

	private set-title {
	    section {Submission Management}
	    description { Change title of a submission. }
	    input submission {
		The submission to change
	    } { validate [cm::vt submission] }
	    input text {
		New title of the submission.
	    } { optional ; interact }
	} [cm::call conference cmd_submission_settitle]
	alias change-title

	private set-date {
	    section {Submission Management}
	    description { Change the submission date of a submission. }
	    input submission {
		The submission to change
	    } { validate [cm::vt submission] }
	    input date {
		New submisison date.
	    } { optional ; interact ; validate [cm::cvt date] }
	} [cm::call conference cmd_submission_setdate]
	alias change-date

	private add-submitter {
	    section {Submission Management}
	    description { Add one or more submitters to a submission. }
	    input submission {
		The submission to modify
	    } { validate [cm::vt submission] }
	    input submitter {
		The submitters to add
	    } { optional ; list ; interact ; validate [cm::vt contact] } ; # TODO validator person (can_talk)
	} [cm::call conference cmd_submission_addsubmitter]

	private drop-submitter {
	    section {Submission Management}
	    description { Remove one or more submitter from a submission. }
	    input submission {
		The submission to modify
	    } { validate [cm::vt submission] }
	    input submitter {
		The submitters to remove
	    } { optional ; list ; interact ; validate [cm::vt submitter] }
	} [cm::call conference cmd_submission_dropsubmitter]

	private show {
	    section {Submission Management}
	    description { Show the details of the specified submission }
	    input submission {
		The submission to show
	    } { optional ; validate [cm::vt submission]
		generate [cm::call conference select-submission] }
	} [cm::call conference cmd_submission_show]
	alias details
	default

	private list {
	    section {Submission Management}
	    description { Show submissions for the current conference }
	} [cm::call conference cmd_submission_list]

	private accepted {
	    section {Submission Management}
	    description { Show accepted submissions, aka presentations for the current conference }
	} [cm::call conference cmd_submission_list_accepted]

	private accept {
	    section {Submission Management}
	    description { Accept the specified submission }
	    option type {
		Type of talk. Default is based on the invited
		state of the chosen submission.
		invited => keynote
		regular => submitted
	    } { validate [cm::vt talk-type] }
	    input submission {
		The submission to accept.
	    } { optional
		validate [cm::vt submission]
		generate [cm::call conference select-submission] }
	} [cm::call conference cmd_submission_accept]

	private reject {
	    section {Submission Management}
	    description { Reject the specified submissions }
	    input submission {
		The submissions to reject.
	    } { list ; optional ; validate [cm::vt submission] ;
		generate [cm::call conference select-submission] }
	} [cm::call conference cmd_submission_reject]
	alias unaccept

	private add-speaker {
	    section {Submission Management}
	    description { Add one or more speakers to an accepted submission. }
	    input submission {
		The submission to modify
	    } { validate [cm::vt submission] }
	    input speaker {
		The speakers to add
	    } { optional ; list ; interact ; validate [cm::vt contact] } ; # TODO validator person (can_talk)
	} [cm::call conference cmd_submission_addspeaker]

	private drop-speaker {
	    section {Submission Management}
	    description { Remove one or more speakers from an accepted submission. }
	    input submission {
		The submission to modify
	    } { validate [cm::vt submission] }
	    input speaker {
		The speakers to remove
	    } { optional ; list ; interact ; validate [cm::vt speaker] }
	} [cm::call conference cmd_submission_dropspeaker]

	private attach {
	    section {Submission Management}
	    description { Add an attachment to an accepted submission. Read from stdin. }
	    input submission {
		The submission to modify
	    } { validate [cm::vt submission] }
	    input type {
		Type of the attachment.
	    } {}
	    input mimetype {
		MIME type of the attachment.
	    } {}
	} [cm::call conference cmd_submission_attach]

	private detach {
	    section {Submission Management}
	    description { Remove one or more attachment from an accepted submission. }
	    input submission {
		The submission to modify
	    } { validate [cm::vt submission] }
	    input type {
		The type of attachment to remove
	    } { optional ; list ; interact ; validate [cm::vt attachment] }
	} [cm::call conference cmd_submission_detach]

	# attachments: change type, mimetype, content
	# talks:       change type, status
    }
    alias submissions = submission list
    alias accepted    = submission accepted
    alias unsubmit    = submission drop
    alias submit      = submission add

    # # ## ### ##### ######## ############# ######################
    ## Campaign management

    officer campaign {
	description {
	    Manage the campaign for a conference.
	    All commands assume a "current conference".
	}

	private setup {
	    section {Conference Management} {Mail Campaign}
	    description {
		Initialize the campaign for the current conference.
	    }
	    option empty {
		Create an empty campaign. Mail addresses will be loaded
		into it via a series of "campaign destination" commands.
		If this option is not present the new campaign will get
		its mail addresses automatically from the known contacts.
	    } { presence }
	} [cm::call campaign setup]

	private mail {
	    section {Conference Management} {Mail Campaign}
	    description {
		Generate campaign mails.
	    }
	    option fake {
		Create a fake mail run, in that the database gets
		updated in full, but no mails are actuall send out.
		This option is only for testing.
	    } { presence }
	    option force {
		Force mail run, even if the template has issues.
	    } { presence }
	    input template {
		Name of the template to use for the mail.
	    } { validate [cm::vt template] }
	} [cm::call campaign mail]

	private run {
	    section {Conference Management} {Mail Campaign}
	    description {
		Create an empty campaign mail run for a specific time.
		To be bulk-loaded with emails via "campaign received".
	    }
	    input epoch {
		Timestamp for the new mail run.
	    } { validate [cm::cvt time] }
	    input template {
		Name of the template to use for the mail.
	    } { validate [cm::vt template] }
	} [cm::call campaign mailrun]

	private test {
	    section {Conference Management} {Mail Campaign}
	    description {
		Check generation of campaign mails.
	    }
	    input template {
		Name of the template to check.
	    } { validate [cm::vt template] }
	} [cm::call campaign test]

	private drop {
	    section {Conference Management} {Mail Campaign}
	    description {
		Remove one or more mail addresses from the campaign
		for the current conference.
		This does not affect future campaigns.
	    }
	    input entry {
		The list of emails to remove.
	    } { list ; optional ; interact ; validate [cm::vt email]
		generate [stop!] }
	} [cm::call campaign drop]

	private destination {
	    section {Conference Management} {Mail Campaign}
	    description {
		Add one or more mail addresses to the campaign
		for the current conference. This is for bulk-loading
		from "cm save" dumps.
	    }
	    input entry {
		The list of emails to add.
	    } { list ; validate [cm::vt email] }
	} [cm::call campaign destination]

	private close {
	    section {Conference Management} {Mail Campaign}
	    description {
		Close the campaign of the current conference.
	    }
	} [cm::call campaign close]

	private reset {
	    section {Conference Management} {Mail Campaign}
	    description {
		Reset the campaign to empty. Use with care, this
		causes the system to forget *all* information about
		templates, runs, and already reached addresses.
	    }
	} [cm::call campaign reset]

	private received {
	    section {Conference Management} {Mail Campaign}
	    description {
		Add one or more mail addresses to the campaign mail run 
		for the current conference and identified by its timestamp.
		This is for bulk-loading from "cm save" dumps.
	    }
	    input epoch {
		The timestamp identifying the mail run.
	    } { validate [cm::cvt time] }
	    input entry {
		The list of emails to add.
	    } { list ; validate [cm::vt email] }
	} [cm::call campaign received]

	private status {
	    section {Conference Management} {Mail Campaign}
	    description {
		Show the status of the campaign.
	    }
	    option detailed {
		Show status in full detail, listing all mails, not just counts.
	    } { presence }
	} [cm::call campaign status]
	default
    }

    # # ## ### ##### ######## ############# ######################
    ## Contacts for campaigns, and as speakers, attendees, staff ...

    officer contact {
	description {
	    Manage the contacts used in campaigns and other contexts.
	    I.e. conference staff, presenters, attendees, etc.
	}

	common .links {
	    option link {
		One or more links for the contact
	    } { alias L ; validate str ; list }
	}
	common .mails {
	    option email {
		One or more emails for the contact
	    } { alias E ; list ; validate [cm::vt mail-address] }
	}

	common .imails {
	    input email {
		One or more known emails
	    } { list ; optional ; interact ; validate [cm::vt email] }
	}

	private create-person {
	    section {Contact Management}
	    description {Create a new contact for a person}
	    use .links
	    use .mails
	    input name   {First name of the person} {}
	    input tag    {Short tag suitable as html anchor} { optional }
	} [cm::call contact create-person]

	private create-list {
	    section {Contact Management}
	    description {Create a new contact for a mailing list}
	    use .links
	    input name {List name} {}
	    input mail {List address} { validate [cm::vt mail-address] }
	} [cm::call contact create-mlist]

	private create-company {
	    section {Contact Management}
	    description {Create a new contact for a company}
	    use .links
	    use .mails
	    input name {Company name} {}
	} [cm::call contact create-company]

	# TODO: contact delete -- delete a superfluous contact - not referenced...

	private add-affiliation {
	    section {Contact Management}
	    description {Add one or more companies as the affiliations of the specified person}
	    input name {
		Name of the contact to modify
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator only persons
		generate [stop!] }
	    input company {
		Names of the companies to add as affiliations
	    } { optional ; list ; interact ; validate [cm::vt contact] } ; # TODO validator only company
	} [cm::call contact add-affiliation]

	private remove-affiliation {
	    section {Contact Management}
	    description {Remove one or more companies from the set of affiliations of the specified person}
	    input name {
		Name of the contact to modify
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator only persons
		generate [stop!] }
	    input company {
		Names of the companies to remove from the set of affiliations
	    } { optional ; list ; interact ; validate [cm::vt contact] } ; # TODO validator only company
	} [cm::call contact remove-affiliation]

	# Reverse affiliation. A personal contact into the company ... A liaison, point of contact, representative
	private add-representative {
	    section {Contact Management}
	    description {Add one or more liaisons to the specified company}
	    input company {
		Name of the company to modify
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator only company
		generate [stop!] }
	    input name {
		Name of the contacts to add as liaisons
	    } { optional ; list ; interact ; validate [cm::vt contact] } ; # TODO validator only persons
	} [cm::call contact add-representative]
	alias add-rep
	alias add-poc

	private remove-representative {
	    section {Contact Management}
	    description {Remove one or more liaisons from the specified company}
	    input company {
		Name of the company to modify
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator only company
		generate [stop!] }
	    input name {
		Name of the contacts to remove as liaisons
	    } { optional ; list ; interact ; validate [cm::vt contact] } ; # TODO validator only persons
	} [cm::call contact remove-representative]
	alias remove-rep
	alias remove-poc

	private set-tag {
	    section {Contact Management}
	    description {Set tag of the specified contact}
	    input name {
		Name of the contact to tag
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator excluding non-persons
		generate [stop!] }
	    input tag {
		Tag to set
	    } { optional ; interact ; generate [stop!] }
	} [cm::call contact tag=]
	alias retag
	alias tag=

	private set-bio {
	    section {Contact Management}
	    description {Set biography of the specified contact. Read from stdin.}
	    input name {
		Name of the contact to modify
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator excluding mlists
		generate [stop!] }
	} [cm::call contact bio=]
	alias bio=

	private retype {
	    section {Contact Management}
	    description {Fix the type of the specified contacts. Resets flags to defaults.}
	    input type {
		The new type of the contact
	    } { validate [cm::vt contact-type] }
	    input name {
		Name of the contacts to modify.
	    } { list ; optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact type=]
	alias type=

	private rename {
	    section {Contact Management}
	    description {Rename the specified contact.}
	    input name {
		Name of the contact to modify.
	    } { optional ; interact ; validate [cm::vt contact]
		generate [stop!] }
	    input newname {
		New name of the contact.
	    } { optional ; interact ; validate [cm::vt notcontact]
		generate [stop!] }
	} [cm::call contact name=]
	alias name=

	private add-mail {
	    section {Contact Management}
	    description {Add more email address to a contact}
	    use .mails
	    input name {
		Name of the contact to extend. No mailing lists.
	    } { optional ; interact ; validate [cm::vt contact] ; # TODO validator excluding mlists
		generate [stop!] }
	} [cm::call contact add-mail]

	private add-link {
	    section {Contact Management}
	    description {Add more links to a contact}
	    use .links
	    input name {
		Name of the contact to extend.
	    } { optional ; interact ; validate [cm::vt contact]
		generate [stop!] }
	} [cm::call contact add-link]

	private disable-mail {
	    section {Contact Management}
	    description {Disable one or more email addresses}
	    use .imails
	} [cm::call contact disable-mail]

	private squash-mail {
	    section {Contact Management}
	    description {Fully remove one or more email addresses}
	    use .imails
	} [cm::call contact squash-mail]

	private disable {
	    section {Contact Management}
	    description {Disable the specified contacts}
	    input name {
		List of the contact to disable
	    } { list ; optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact disable]

	private enable {
	    section {Contact Management}
	    description {Enable the specified contacts}
	    input name {
		List of the contact to disable
	    } { list ; optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact enable]

	private list {
	    section {Contact Management}
	    description {Show all known contacts, possibly filtered}
	    input pattern {
		Filter list by the glob pattern
	    } { optional ; default * }
	    option with-mails {Show mail addresses} { presence }
	    option only {
		Show only entries of the requested type(s).
		If not specified show all.
	    } { list ; validate [cm::vt contact-type] }
	} [cm::call contact list-all]

	private show {
	    section {Contact Management}
	    description {Show the details of the specified contact}
	    input name {
		Name of the contact to show.
	    } { optional ; interact ; validate [cm::vt contact]
		generate [stop!] }
	} [cm::call contact show]

	private merge {
	    section {Contact Management}
	    description {Merge the secondary contacts into a primary}
	    input primary {
		Name of the primary contact taking the merged data.
	    } { optional ; interact ; validate [cm::vt contact]
		generate [stop!] }
	    input secondary {
		Name of the secondary contacts to merge into the primary
	    } { optional ; list ; interact ; validate [cm::vt contact]
		generate [stop!] }
	} [cm::call contact merge]

	# TODO: change flags?
	# TODO: set link title
    }
    alias contacts = contact list

    # # ## ### ##### ######## ############# ######################
    ## Schedule management

    officer schedule {
	description {
	    Manage conference schedules.
	}

	common *all* -extend {
	    section {Conference Management} Schedules
	}

	common .opt_schedule {
	    input name {
		The name of the schedule to work on.
	    } {
		optional
		validate [cm::vt pschedule]
		generate [cm::call schedule active-or-select]
	    }
	}

	common .opt_schedule_select {
	    input name {
		The name of the schedule to work on.
	    } {
		optional
		validate [cm::vt pschedule]
		generate [cm::call schedule just-select]
	    }
	}

	common .opt_track_select {
	    input name {
		The name of the track to work on.
	    } {
		optional
		validate [cm::vt pschedule-track]
		generate [cm::call schedule track-just-select]
	    }
	}

	common .opt_day_select {
	    input day {
		The index of the day to work on (0-based)
	    } {
		optional
		validate [cm::vt pschedule-day]
		generate [cm::call schedule day-just-select]
	    }
	}

	private add {
	    description { Create a new, empty named schedule }
	    input name {
		The name of the new schedule.
	    } { validate [cm::vt notpschedule] }
	} [cm::call schedule add]
	alias create

	private remove {
	    description { Destroy the named schedule }
	    use .opt_schedule
	} [cm::call schedule remove]
	alias drop

	private rename {
	    description { Rename the named schedule }
	    input name {
		The name of the schedule to modify
	    } { validate [cm::vt pschedule] }
	    input newname {
		The new name of the schedule
	    } { validate [cm::vt notpschedule] }
	} [cm::call schedule rename]

	private select {
	    description { Activate the named schedule }
	    use .opt_schedule_select
	} [cm::call schedule select]

	private clear-select {
	    description { Clear active schedule }
	} [cm::call schedule select-clear]

	private selected {
	    description { Tell which schedule is active }
	} [cm::call schedule selected]

	# TODO: Duplicate an entire schedule under a new name.

	private show {
	    description { Show information about the named schedule }
	    use .opt_schedule
	} [cm::call schedule show]
	default

	private start {
	    description { Show and/or set a global start-time }
	    input time {
		If present, set the global start time to this value.
		Else simply show the current value of this setting.
	    } {
		optional
		validate [cm::cvt time::minute]
	    }
	} [cm::call schedule start]
	default

	private list {
	    description { Show a table of all known schedules }
	} [cm::call schedule listing]

	private validate {
	    description { Validate schedule information }
	} [cm::call schedule validate]

	# TODO : Item handling

	common .schedule-context {
	    option schedule {
		The schedule to operate on.
	    } {
		alias S
		validate [cm::vt pschedule]
		generate [cm::call schedule active-or-select]
	    }
	}

	common .full-context {
	    option schedule {
		The schedule to use.
	    } {
		alias S
		validate [cm::vt pschedule]
		generate [cm::call schedule active-or-select]
	    }

	    option dont-check {
		Presence prevents schedule validation, allowing for intermediate invalid state.
	    } { presence }

	    ## # # ## ### ##### ######## #############
	    # Focus elements in the schedule. Command behaviour influenced by
	    # - element specified by the user
	    # - vs element taken from focus location
	    # - plus additional specialities, like
	    #   - Track needs mode to set it as NULL.
	    ## # # ## ### ##### ######## #############

	    state context {
		Internal focus context holding all focus information
		and associated flags across the different options.

		structure is dict {
		    schedule -> active schedule
		    focus    -> focus data
		    flags    -> focus stati
		}
	    } { defered
		validate identity
		generate [cm::call schedule context-setup]
	    }

	    ## # # ## ### ##### ######## #############
	    ### Logic for parent item.

	    option child {
		Presence of this option tells the system that the new
		item requires a parent, which shall be the active
		item, before and after.

		The start-time shall be the current end-time of the
		parent, and the parent be extended by the length of
		the new item. Regardless of user choice.

		The track and day of the new item shall be inherited
		from the parent. Regardless of user choice.
	    } { presence
		alias P

		when-set [disallow @track]
		when-set [disallow @cross-tracks]
		when-set [disallow @day]
		when-set [disallow @start-time]

		when-set [cm::call schedule context-request-parent]
	    }
	    state parent {
		Context derived parent information. See also
		--child above, and "context-request-parent".
	    } {
		generate [cm::call schedule context-get-parent]
	    }

	    ## # # ## ### ##### ######## #############
	    ## Logic for track.

	    option track {
		The track to use for the new item
	    } {
		alias T
		validate [cm::vt pschedule-track]

		when-set [disallow @cross-tracks]
		when-set [disallow @child]

		when-set [cm::call schedule context-set-track]
		generate [cm::call schedule context-get-track]
	    }
	    option cross-tracks {
		Create an item crossing all tracks
	    } { presence
		alias across
		when-set [disallow @track]
		when-set [disallow @child]

		when-set [cm::call schedule context-cross-tracks]
	    }

	    ## # # ## ### ##### ######## #############
	    ## Logic for day.

	    option day {
		The day to use
	    } {
		alias D
		validate [cm::vt pschedule-day]

		when-set [disallow @child]

		when-set [cm::call schedule context-set-day]
		generate [cm::call schedule context-get-day]
	    }

	    ## # # ## ### ##### ######## #############
	    ## Logic for start-time

	    option start-time {
		The start time of the item
	    } {
		alias B
		validate [cm::cvt time::minute]

		when-set [disallow @child]

		when-set [cm::call schedule context-set-time]
		generate [cm::call schedule context-get-time]
	    }

	    option length {
		The length of the item in minutes
	    } {
		alias L
		validate [cm::cvt time::minute]
		default 0
	    }

	    ## # # ## ### ##### ######## #############
	}

	officer track {
	    private add {
		description { Create a new track for the schedule }
		use .schedule-context
		input name {
		    The name of the new track.
		} { validate [cm::vt notpschedule-track] }
	    } [cm::call schedule track-add]
	    alias create

	    private remove {
		description { Destroy the named track in the schedule }
		use .schedule-context
		input name {
		    The name of the track to destroy.
		} { validate [cm::vt pschedule-track] }
	    } [cm::call schedule track-remove]
	    alias drop

	    private rename {
		description { Rename the named track }
		use .schedule-context
		input name {
		    The name of the track to rename
		} { validate [cm::vt pschedule-track] }
		input newname {
		    The new name of the track
		} { validate [cm::vt notpschedule-track] }
	    } [cm::call schedule track-rename]

	    private clear-select {
		description { Clear active track }
		use .schedule-context
	    } [cm::call schedule track-select-clear]

	    private selected {
		description { Tell which track is active }
		use .schedule-context
	    } [cm::call schedule track-selected]

	    # Track nav commands

	    private select {
		description { Activate the named track }
		use .schedule-context
		use .opt_track_select
	    } [cm::call schedule track-select]
	    # Track axis: "go to"

	    private leftmost {
		description { Activate the lexicographically first track }
		use .schedule-context
	    } [cm::call schedule track-leftmost]

	    private left {
		description { Activate the lexicographically previous track }
		use .schedule-context
	    } [cm::call schedule track-left]

	    private rightmost {
		description { Activate the lexicographically last track }
		use .schedule-context
	    } [cm::call schedule track-rightmost]

	    private right {
		description { Activate the lexicographically next track }
		use .schedule-context
	    } [cm::call schedule track-right]
	}

	officer day {
	    private clear-select {
		description { Clear active day }
		use .schedule-context
	    } [cm::call schedule day-select-clear]

	    private selected {
		description { Tell which day is active }
		use .schedule-context
	    } [cm::call schedule day-selected]

	    # Day nav commands

	    private select {
		description { Activate the named day }
		use .schedule-context
		use .opt_day_select
	    } [cm::call schedule day-select]
	    # Day axis: "go to"

	    private first {
		description { Activate the first day }
		use .schedule-context
	    } [cm::call schedule day-first]

	    private previous {
		description { Activate the previous day }
		use .schedule-context
	    } [cm::call schedule day-previous]

	    private last {
		description { Activate the last day }
		use .schedule-context
	    } [cm::call schedule day-last]

	    private next {
		description { Activate the next day }
		use .schedule-context
	    } [cm::call schedule day-next]
	}

	# Nav shorts - Tracks
	alias leftmost  = track leftmost
	alias lm        = track leftmost
	alias rightmost = track rightmost
	alias rm        = track rightmost
	alias left      = track left
	alias l         = track left
	alias right     = track right
	alias r         = track right

	# Nav shorts - Days
	alias first     = day first
	alias f         = day first
	alias last      = day last
	#alias l         = day last -- clash (left)
	alias previous  = day previous
	alias prev      = day previous
	alias p         = day previous
	alias next      = day next
	alias n         = day next

	officer item {
	    private event {
		description { Create a new fixed event for the schedule }
		use .full-context
		input description {
		    The description of the new event
		} { validate str }
		input note {
		    Additional notes for the new event
		} { optional ; validate str }
	    } [cm::call schedule item-add-event]

	    private placeholder {
		description { Create a new placeholder for the schedule }
		use .full-context
		input label {
		    The label of the placeholder.
		} { validate str }
	    } [cm::call schedule item-add-placeholder]

	    # edit operations -- interactive, item via active context.
	    private remove {
		description { Destroy the item in the schedule }
		use .schedule-context
		input ref {
		    The identifier of the item to work with.
		} { validate [cm::vt pschedule-item] }
	    } [cm::call schedule item-remove]
	    alias drop

	    private rename {
		description { Rename the specified item }
		use .schedule-context
		input ref {
		    The identifier of the item to work with.
		} { validate [cm::vt pschedule-item] }
		input newname {
		    The new description or label of the item
		} { validate str }
	    } [cm::call schedule item-rename]
	}
	alias event       = item event
	alias placeholder = item placeholder

	# TODO : Interactive operations.
	##
	# Navigation - Active item, day, track, time
	#
	# - Three axes: day, time, track
	#
	# - Day (numerically ordered 0, 1, ...):
	#   - f(irst), l(ast),
	#   - p(rev(ious)), n(ext)
	#
	# - Time (numerically ordered ascending from midnight):
	#   - t(op), b(ottom),
	#   - u(p)/f(orw(ard)), d(own)/back(ward)
	#
	# - Track (lexicographically ordered by name):
	#   - l(eft)m(ost), r(ight)m(ost)
	#   - l(eft), r(ight)
	##
	# Selection
	# - SetMark, FromMark, Include, Exclude
	# - Copy, Cut, Paste
	# = Selection limits: Single day, track ?
	# Enter/Close
	##
	# Pinning
	# - Interactive entry of new items - movable by default ?!
	# - Bulk        entry of new items - pinned  by default !?

    }
    alias schedules = schedule list

    # # ## ### ##### ######## ############# ######################
    ## Developer support, feature test and repository inspection.

    officer test {
	description {
	    Various commands to test the system and its configuration.
	}
	common *all* -extend {
	    section Advanced Testing
	}

	# - -- --- ----- -------- -------------

	# - -- --- ----- -------- -------------

	private mail-address {
	    description {
		Parse the specified address into parts, and determine
		if it is lexically ok for us, or not, and why not in
		case of the latter.
	    }
	    input address {
		The address to parse and test.
	    } { }
	} [cm::call mailer cmd_test_address]

	private mail-setup {
	    description {
		Generate a test mail and send it using the current
		mail configuration.
	    }
	    input destination {
		The destination address to send the test mail to.
	    } { }
	} [cm::call mailer cmd_test_mail_config]

	# - -- --- ----- -------- -------------

	private city-known {
	    description {Print validation dict}
	} [cm::call city test-known]

	private city-select {
	    description {Print selection dict}
	} [cm::call city test-select]

	# - -- --- ----- -------- -------------

	private location-known {
	    description {Print validation dict}
	} [cm::call location test-known]

	private location-select {
	    description {Print selection dict}
	} [cm::call location test-select]

	private location-staff-known {
	    description {Print validation dict, stafff of current location}
	} [cm::call location test-staff-known]

	private location-staff-select {
	    description {Print selection dict, staff of current location}
	} [cm::call location test-staff-select]

	# - -- --- ----- -------- -------------

	private contact-known {
	    description {Print validation dict}
	} [cm::call contact test-known]

	private contact-select {
	    description {Print selection dict}
	} [cm::call contact test-select]

	# - -- --- ----- -------- -------------

	private timeline-known {
	    description {Print validation dictionary}
	} [cm::call conference test-timeline-known]

	# - -- --- ----- -------- -------------

	private tutorial-known {
	    description {Print validation dictionary}
	} [cm::call tutorial test-known]

	# - -- --- ----- -------- -------------

	private schedule-known {
	    description {Print validation dictionary}
	} [cm::call schedule test-known]

	private schedule-select {
	    description {Print selection dictionary}
	} [cm::call schedule test-select]

	common .schedule {
	    input schedule {
		Name of the schedule to inspect
	    } { validate [cm::vt pschedule] }
	}

	private schedule-track-known {
	    description {Print validation dictionary}
	    use .schedule
	} [cm::call schedule test-track-known]

	private schedule-track-select {
	    description {Print selection dictionary}
	    use .schedule
	} [cm::call schedule test-track-select]

	private schedule-item-day-max {
	    description {Print day validation information}
	    use .schedule
	} [cm::call schedule test-item-day-max]

	# - -- --- ----- -------- -------------
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

	private fix-mails {
	    description {
		Force all mail addresses into lower-case.
	    }
	} [cm::call contact cmd_mail_fix]

	private speakers {
	    description {
		Show speaker information inserted into the overview page.
	    }
	    option mail {
		When present show speaker information inserted into a CFP.
	    } { presence }
	} [cm::call conference cmd_debug_speakers]
    }
}

# # ## ### ##### ######## ############# ######################
package provide cm 0
return
