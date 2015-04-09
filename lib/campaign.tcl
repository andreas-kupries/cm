## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::campaign 0
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
package require struct::set

package require cm::conference
#package require cm::contact
package require cm::db
package require cm::db::campaign
package require cm::db::contact
package require cm::db::template
package require cm::mailer
package require cm::mailgen
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export campaign
    namespace ensemble create
}
namespace eval ::cm::campaign {
    namespace export setup close reset drop status mail test
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask

    namespace import ::cm::conference
    namespace import ::cm::db
    namespace import ::cm::db::contact
    namespace import ::cm::db::template
    namespace import ::cm::mailer
    namespace import ::cm::mailgen
    namespace import ::cm::util

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/campaign
debug prefix cm/campaign {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::campaign::setup {config} {
    debug.cm/campaign {}
    campaign setup
    contact  setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign ne {}} {
	if {[campaign isactive $campaign]} {
	    util user-error "Conference \"$clabel\" already has an active campaign" \
		CAMPAIGN ALREADY ACTIVE
	} else {
	    util user-error "Conference \"$clabel\" has a closed campaign" \
		CAMPAIGN ALREADY CLOSED
	}
    }

    # No campaign for the conference, set it up now.

    puts -nonewline "Creating campaign \"[color name $clabel]\" ... "
    flush stdout

    lassign [campaign new $conference] campaign new

    if {!$new} {
	util user-error "Failed, empty" CAMPAIGN EMPTY
    }

    puts "[color good OK] ($new entries)"
    return
}

proc ::cm::campaign::close {config} {
    debug.cm/campaign {}
    campaign setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    puts -nonewline "Closing campaign \"[color name $clabel]\" ... "
    flush stdout

    if {[campaign isactive $campaign]} {
	campaign close $campaign
    }

    puts "[color good OK]"
    return
}

proc ::cm::campaign::reset {config} {
    debug.cm/campaign {}
    campaign setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    if {![ask yn "Campaign \"[color name $clabel]\" [color bad RESET]" no]} {
	puts [color note Aborted]
	return
    }

    campaign reset $campaign

    puts [color good OK]
    return
}

proc ::cm::campaign::status {config} {
    debug.cm/campaign {}
    campaign setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }

    puts "Campaign \"[color name $clabel]\" status"

    # 1. Mailings performed ... when, template, #destinations
    # 2. Destinations in campaign vs destinations in mailings.

    set destinations [campaign destinations $campaign]

    puts "Destinations: [llength $destinations]"
    debug.cm/campaign {destinations = ($destinations)}

    puts "Runs:"
    [table t {When Template Reached Unreached} {
	foreach {mailrun date name} [campaign runs $campaign] {
	    set date [clock format $date -format {%Y-%m-%d %H:%M:%S}]
	    # See conference h* commands.

	    set reached [campaign run-reach $mailrun]
	    debug.cm/campaign {run $mailrun reached   = ($reached)}

	    set unreached [struct::set difference \
			       $destinations $reached]

	    debug.cm/campaign {run $mailrun unreached = ($unreached)}

	    set unreached [llength $unreached]
	    set reached   [llength $reached]

	    debug.cm/campaign {run $mailrun $reached/$unreached}

	    if {$unreached} {
		set unreached [color bad $unreached]
	    }

	    debug.cm/campaign {run $mailrun $reached/$unreached}

	    $t add $date $name $reached $unreached
	}
    }] show
    return
}

proc ::cm::campaign::mail {config} {
    debug.cm/campaign {}
    campaign setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![campaign isactive $campaign]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    set template [$config @template]
    set tname    [template 2name $template]

    puts "Campaign \"[color name $clabel]\" run with template \"[color name $tname]\" ..."

    set destinations [campaign destinations $campaign]

    puts "Destinations: [llength $destinations]"
    debug.cm/campaign {destinations = ($destinations)}

    # Check for preceding runs with the same template, take their receivers, and drop them from the set of destinations. No duplicate delivery!

    foreach {date mailrun} [campaign runs-of $template] {
	set date [clock format $date -format {%Y-%m-%d %H:%M:%S}]

	set reached [campaign run-reach $mailrun]
	debug.cm/campaign {reached      = ($reached)}

	set destinations [struct::set difference \
			      $destinations $reached]
	debug.cm/campaign {not reached  = ($destinations)}

	puts "Run $date reached [llength $reached], leaving [llength $destinations]"
    }

    if {![llength $destinations]} {
	puts "[color note {No destinations left}]."
	return
    } else {
	puts "Addressing:   [llength $destinations]"
    }

    set text [template value $template]

    set issues [CheckTemplate $text]
    if {$issues ne {}} {
	puts $issues
	if {![ask yn "Continue with mail run ?" no]} {
	    puts [color note Aborted]
	    return
	}
    }

    set mconfig [mailer get-config]
    set text    [conference insert $conference $text]
    set mailrun [campaign run-create $campaign $template]

    mailer batch receiver address name $destinations {
	# Insert address and name into the template

	puts "To: $name [color name $address]"

	if 1 {
	    #TODO: non-dry
	    mailer send $mconfig \
		[list $address] \
		[mailgen call $address $name $text] \
		0 ;# not verbose
	}

	campaign run-extend $mailrun $receiver
    }
    return
}

proc ::cm::campaign::test {config} {
    debug.cm/campaign {}
    campaign setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![campaign isactive $campaign]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    set template [$config @template]
    set tname    [template 2name $template]

    puts "Campaign \"[color name $clabel]\" run with template \"[color name $tname]\" ..."

    set text   [template value $template]
    set issues [CheckTemplate $text]

    set text [conference insert $conference $text]
    set text [mailgen call "test@example.com" Tester $text]

    puts $text

    if {$issues ne {}} {
	puts =======================
	puts $issues
    }
    return
}

proc ::cm::campaign::drop {config} {
    debug.cm/campaign {}
    campaign setup
    db show-location

    set conference [conference current]
    set clabel     [conference get $conference]

    set campaign [campaign for-conference $conference]
    if {$campaign eq {}} {
	util user-error "Conference \"$clabel\" has no campaign" \
	    CAMPAIGN MISSING
    }
    if {![campaign isactive $campaign]} {
	util user-error "Campaign \"$clabel\" is closed, cannot be modified" \
	    CAMPAIGN CLOSED
    }

    puts "Campaign \"[color name $clabel]\" dropping ..."

    foreach email [$config @entry] {
	puts -nonewline "* [color name [contact get-email $email]] ... "
	flush stdout

	campaign drop-email $campaign $email

	puts "[color good OK]"
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::campaign::CheckTemplate {text} {
    debug.cm/campaign {}
    set issues {}
    foreach {rq placeholder} {
	0 mg:sender
	0 mg:name
	1 h:hotel
	1 h:city
	1 h:street
	1 c:name
	1 c:city
	1 c:year
	1 c:start
	1 c:end
	1 c:when
	1 c:talklength
	1 c:contact
	0 c:sponsors
	0 c:committee
	1 c:t:wipopen
	1 c:t:submitdead
	1 c:t:authornote
	1 c:t:writedead
	1 c:t:begin-t
	1 c:t:begin-s
    } {
	if {[string match *@${placeholder}@* $text]} continue
	if {$rq} {
	    set msg "  [color bad Required]  placeholder \"$placeholder\" [color bad missing]"
	} else {
	    set msg "  Suggested placeholder \"$placeholder\" missing"
	}
	lappend issues $msg
    }
    return [join $issues \n]
}

# # ## ### ##### ######## ############# ######################
package provide cm::campaign 0
return
