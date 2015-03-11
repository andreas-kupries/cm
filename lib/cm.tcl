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
    ## Manage mail templates

    officer template {
	description {
	    Manage the text templates used for mail campaigns.
	}

	private list {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Show a table of all known templates }
	} [cm::call template cmd_list]

	private show {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Show the text of the named template }
	    input name {
		Name of the template to show
	    } { validate [cm::vt template] }
	} [cm::call template cmd_show]

	private create {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Create a new template. The text is read from stdin. }
	    input name {
		Name of the template to create
	    } { validate [cm::vt nottemplate] }
	} [cm::call template cmd_create]
	alias add
	alias new

	private remove {
	    section {Conference Management} {Mail Campaign} {Template Management}
	    description { Remove the named template }
	    input name {
		Name of the template to remove
	    } { validate [cm::vt template] }
	} [cm::call template cmd_remove]
	alias drop

    }
    alias templates = template list

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
    ## Manage conferences

    officer conference {
	description {
	    Manage conferences
	}
	# -- (n:1) city, hotel, session
	# -- (n:1) hotel, session
	# title, year, start, end, talk-length, session-length
	# alignment (specific weekday, or none), length in days

	private create {
	    section {Conference Management}
	    description { Create a new conference }

	    input title {
		Name of the conference
	    } { optional ; interact }

	    input year {
		Year of the conference
	    } { optional ; interact ; validate [cm::cvt year] }

	    input alignment {
		Alignment within the week
	    } { optional ; validate [cm::cvt weekday] ; default -1 }

	    input start {
		Start date
	    } { optional ; interact ; validate [cm::cvt date] }

	    input length {
		Length in days
	    } { optional ; interact ; validate [cm::cvt posint] }

	    # Set later: hotel, session, city

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

	private timeline-init {
	    section {Conference Management}
	    description { Generate a basic timeline for the conference }
	} [cm::call conference cmd_timeline_init]

	private timeline-clear {
	    section {Conference Management}
	    description { Clear the timeline for the conference }
	} [cm::call conference cmd_timeline_clear]

	private center {
	    section {Conference Management}
	    description { Select the location for presentations }
	    input hotel { Conference hotel } {
		# TODO: validator <=> hotel identification (name + city)
		optional ; generate [cm::call hotel select]
	    }
	} [cm::call conference cmd_center]

	private hotel {
	    section {Conference Management}
	    description { Select the conference hotel }
	    input hotel { Conference hotel } {
		# TODO: validator <=> hotel identification (name + city)
		optional ; generate [cm::call hotel select]
	    }
	} [cm::call conference cmd_hotel]

	# remove - if not used
	# modify - change title, start, length, alignment

	private add-sponsor {
	    section {Conference Management}
	    description { Add one or more sponsoring contacts }
	    input name {
		Names of the contacts to add
	    } { list ; optional ; interact ; validate [cm::vt contact] } ; # TODO validator not m-lists
	} [cm::call conference cmd_sponsor_link]

	private drop-sponsor {
	    section {Conference Management}
	    description { Remove one or more sponsoring contacts }
	    input name {
		Name of the contact to remove
	    } { 
		optional
		generate [cm::call conference select-sponsor]
		validate [cm::vt sponsor]
	    }
	} [cm::call conference cmd_sponsor_unlink]

	private add-staff {
	    section {Conference Management}
	    description { Add one or more staff }
	    input role {
		The role to staff
	    } {
		optional
		generate [cm::call conference select-staff-role]
	    }
	    input name {
		Names of the contacts which are staff
	    } { list ; optional ; interact ; validate [cm::vt contact] } ; # TODO validator people only
	} [cm::call conference cmd_staff_link]

	private drop-staff {
	    section {Conference Management}
	    description { Remove one or more staff }
	    input name {
		Name of the staff to remove
	    } { 
		optional
		generate [cm::call conference select-staff]
		validate [cm::vt conference-staff]
	    }
	} [cm::call conference cmd_staff_unlink]

    }
    alias conferences = conference list

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
	} [cm::call campaign cmd_setup]

	private mail {
	    section {Conference Management} {Mail Campaign}
	    description {
		Generate campaign mails.
	    }
	    input template {
		Name of the template to use for the mail.
	    } { validate [cm::vt template] }
	} [cm::call campaign cmd_mail]

	private test {
	    section {Conference Management} {Mail Campaign}
	    description {
		Check generation of campaign mails.
	    }
	    input template {
		Name of the template to check.
	    } { validate [cm::vt template] }
	} [cm::call campaign cmd_test]

	private drop {
	    section {Conference Management} {Mail Campaign}
	    description {
		Remove one or more mail addresses from the campaign
		for the crrent conference.
		This does not affect future campaigns.
	    }
	    input entry {
	    } { list ; optional ; interact ; validate [cm::vt email] }
	} [cm::call campaign cmd_drop]

	private close {
	    section {Conference Management} {Mail Campaign}
	    description {
		Close the campaign of the current conference.
	    }
	} [cm::call campaign cmd_close]

	private reset {
	    section {Conference Management} {Mail Campaign}
	    description {
		Reset the campaign to empty. Use with care, this
		looses all information about templates, run, and
		already reached addresses.
	    }
	} [cm::call campaign cmd_reset]

	private status {
	    section {Conference Management} {Mail Campaign}
	    description {
		Show the status of the campaign.
	    }
	} [cm::call campaign cmd_status]
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
	} [cm::call contact cmd_create_person]

	private create-list {
	    section {Contact Management}
	    description {Create a new contact for a mailing list}
	    use .links
	    input name {List name} {}
	    input mail {List address} { validate [cm::vt mail-address] }
	} [cm::call contact cmd_create_mlist]

	private create-company {
	    section {Contact Management}
	    description {Create a new contact for a company}
	    use .links
	    use .mails
	    input name {Company name} {}
	} [cm::call contact cmd_create_company]

	private set-company {
	    section {Contact Management}
	    description {Set tag of the specified contact}
	    input name {
		Name of the contact to tag
	    } { optional ; interact ; validate [cm::vt contact] } ; # TODO validator only persons
	    input company {
		Name of the company to set as affiliation
	    } { optional ; interact ; validate [cm::vt contact] } ; # TODO validator only company
	} [cm::call contact cmd_set_company]
	alias affiliate

	private set-tag {
	    section {Contact Management}
	    description {Set tag of the specified contact}
	    input name {
		Name of the contact to tag
	    } { optional ; interact ; validate [cm::vt contact] } ; # TODO validator excluding non-persons
	    input tag {
		Tag to set
	    } { optional ; interact }
	} [cm::call contact cmd_set_tag]

	private set-bio {
	    section {Contact Management}
	    description {Set biography of the specified contact. Read from stdin.}
	    input name {
		Name of the contact to modify
	    } { optional ; interact ; validate [cm::vt contact] } ; # TODO validator excluding mlists
	} [cm::call contact cmd_set_bio]

	private add-mail {
	    section {Contact Management}
	    description {Add more email address to a contact}
	    use .mails
	    input name {
		Name of the contact to extend. No mailing lists.
	    } { optional ; interact ; validate [cm::vt contact] } ; # TODO validator excluding mlists
	} [cm::call contact cmd_add_mail]

	private add-link {
	    section {Contact Management}
	    description {Add more links to a contact}
	    use .links
	    input name {
		Name of the contact to extend.
	    } { optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact cmd_add_link]

	private disable-mail {
	    section {Contact Management}
	    description {Disable one or more email addresses}
	    use .imails
	} [cm::call contact cmd_disable_mail]

	private squash-mail {
	    section {Contact Management}
	    description {Fully remove one or more email addresses}
	    use .imails
	} [cm::call contact cmd_squash_mail]

	private disable {
	    section {Contact Management}
	    description {Disable the specified contacts}
	    input name {
		List of the contact to disable
	    } { list ; optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact cmd_disable]

	private enable {
	    section {Contact Management}
	    description {Enable the specified contacts}
	    input name {
		List of the contact to disable
	    } { list ; optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact cmd_disable]

	private list {
	    section {Contact Management}
	    description {Show all known contacts, possibly filtered}
	    input pattern {
		Filter list by the glob pattern
	    } { optional ; default * }
	    option with-mails {Show mail addresses} { presence }
	} [cm::call contact cmd_list]

	private show {
	    section {Contact Management}
	    description {Show the details of the specified contact}
	    input name {
		Name of the contact to show.
	    } { optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact cmd_show]

	private retype {
	    section {Contact Management}
	    description {Fix the type of the specified contacts. Resets flags to defaults.}
	    input type {
		The new type of the contact
	    } { validate [cm::vt contact-type] }
	    input name {
		Name of the contacts to modify.
	    } { list ; optional ; interact ; validate [cm::vt contact] }
	} [cm::call contact cmd_retype]

	private rename {
	    section {Contact Management}
	    description {Rename the specified contact.}
	    input name {
		Name of the contact to modify.
	    } { optional ; interact ; validate [cm::vt contact] }
	    input newname {
		New name of the contact
	    } { optional ; interact }
	} [cm::call contact cmd_rename]

	private merge {
	    section {Contact Management}
	    description {Merge the secondary contacts into a primary}
	    input primary {
		Name of the primary contact taking the merged data.
	    } { optional ; interact ; validate [cm::vt contact] }
	    input secondary {
		Name of the secondary contacts to merge into the primary
	    } { optional ; list ; interact ; validate [cm::vt contact] }
	} [cm::call contact cmd_merge]

	# TODO: change flags?
	# TODO: set link title
    }
    alias contacts = contact list

    # # ## ### ##### ######## ############# ######################
    ## Developer support, feature test and repository inspection.

    officer test {
	description {
	    Various commands to test the system and its configuration.
	}
	common *all* -extend {
	    section Advanced Testing
	}

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
    }
}

# # ## ### ##### ######## ############# ######################
package provide cm 0
return
