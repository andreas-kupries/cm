## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::conference 0
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
package require cmdr::ask
package require cmdr::color
package require cmdr::table
package require cmdr::validate::date
package require cmdr::validate::weekday
package require dbutil
package require debug
package require debug::caller
package require struct::set
package require try

package require cm::db
package require cm::db::booked
package require cm::db::city
package require cm::db::config
package require cm::db::contact
package require cm::db::dayhalf
package require cm::db::location
package require cm::db::pschedule
package require cm::db::registered
package require cm::db::rstatus
package require cm::db::schedule
package require cm::db::staff-role
package require cm::db::talk-state
package require cm::db::talk-type
package require cm::db::template
package require cm::db::timeline
package require cm::db::tutorial
package require cm::mailer
package require cm::mailgen
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export conference
    namespace ensemble create
}
namespace eval ::cm::conference {
    namespace export \
	cmd_create cmd_list cmd_select cmd_show cmd_facility cmd_hotel \
	cmd_timeline_init cmd_timeline_clear cmd_timeline_show cmd_timeline_shift \
	cmd_timeline_set cmd_timeline_done cmd_sponsor_show cmd_sponsor_link cmd_sponsor_unlink \
	cmd_sponsor_ping cmd_committee_ping cmd_website_make cmd_end_set cmd_rate_show \
	cmd_rate_set cmd_staff_show cmd_staff_link cmd_staff_unlink \
	cmd_submission_add cmd_submission_drop cmd_submission_show cmd_submission_list \
	cmd_submission_setsummary cmd_submission_setabstract cmd_registration \
	cmd_submission_accept cmd_submission_reject cmd_submission_addspeaker \
	cmd_submission_dropspeaker cmd_submission_attach cmd_submission_detach \
	cmd_submission_settitle cmd_submission_setdate cmd_submission_addsubmitter \
	cmd_submission_dropsubmitter cmd_submission_list_accepted cmd_tutorial_show cmd_tutorial_link \
	cmd_tutorial_unlink cmd_debug_speakers \
	\
	cmd_booking_list cmd_booking_add cmd_booking_remove \
	cmd_registration_list cmd_registration_add cmd_registration_remove \
	\
	cmd_schedule_set cmd_schedule_show cmd_schedule_edit \
	\
	select label current get insert known-sponsor \
	select-sponsor select-staff known-staff \
	select-submission get-submission \
	get-submission-handle known-submissions-vt \
	known-speaker known-attachment get-attachment known-submitter \
	its-hotel known-talks-vt \
	\
	test-timeline-known

    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cmdr::validate::date
    namespace import ::cmdr::validate::weekday
    namespace import ::cm::db
    namespace import ::cm::db::booked
    namespace import ::cm::db::city
    namespace import ::cm::db::config
    namespace import ::cm::db::contact
    namespace import ::cm::db::dayhalf
    namespace import ::cm::db::location
    namespace import ::cm::db::pschedule
    namespace import ::cm::db::registered
    namespace import ::cm::db::rstatus
    namespace import ::cm::db::schedule
    namespace import ::cm::db::staff-role
    namespace import ::cm::db::talk-state
    namespace import ::cm::db::talk-type
    namespace import ::cm::db::template
    namespace import ::cm::db::timeline
    namespace import ::cm::db::tutorial
    namespace import ::cm::mailer
    namespace import ::cm::mailgen
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
    namespace import ::cmdr::table::dict    ; rename dict    table/d
}

# # ## ### ##### ######## ############# ######################

debug level  cm/conference
debug prefix cm/conference {[debug caller] | }

# # ## ### ##### ######## ############# ######################
 
proc ::cm::conference::test-timeline-known {config} {
    debug.cm/conference {}
    Setup
    db show-location
    util pdict [known-timeline-validation]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_list {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set cid [config get* @current-conference {}]

    [table t {{} Name Start End City} {
	db do eval {
	    SELECT C.id                    AS id,
                   C.title                 AS title,
	           C.startdate             AS start,
	           c.enddate               AS end,
	           CC.name                 AS city,
	           CC.state                AS state,
	           CC.nation               AS nation
	    FROM      conference C
            LEFT JOIN city      CC
	    ON        CC.id = C.city
	    ORDER BY C.title
	} {
	    set start "[date 2external $start] [hwday $start]"
	    set end   "[date 2external $end] [hwday $end]"

	    set city    [city label $city $state $nation]
	    set issues  [issues [details $id]]
	    if {[llength $issues]} {
		append title \n [util fmt-issues-cli $issues]
	    }

	    util highlight-current cid $id current title start end city
	    $t add $current $title $start $end $city
	}
    }] show
    return
}

proc ::cm::conference::cmd_create {config} {
    debug.cm/conference {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set ascurr  [$config @current]    ; debug.cm/conference {ascurr  = $ascurr}
    set title   [$config @title]      ; debug.cm/conference {title   = $title}
    set year    [$config @year]       ; debug.cm/conference {year    = $year}
    set align   [$config @alignment]  ; debug.cm/conference {align   = $align}
    set start   [$config @start]      ; debug.cm/conference {start   = $start}
    set length  [$config @length]     ; debug.cm/conference {length  = $length}
    set manager [$config @manager]    ; debug.cm/conference {manager = $manager}
    set subrecv [$config @submission] ; debug.cm/conference {subrecv = $subrecv}

    puts -nonewline "Creating conference \"[color name $title]\" ... "
    flush stdout

    # move start-date into alignment
    if {$align > 0} {
	set old $start
	while {[clock format $start -format %u] != $align} {
	    set start [clock add $start -1 days]
	}
	if {$start != $old} {
	    puts -nonewline "Realigned to [hdate $start] ..."
	    flush stdout
	}
    }

    # check year-of start-date vs year
    set syear [hyear $start]
    if {$syear != $year} {
	util user-error \
	    "Start date in $syear does not match conference year $year" \
	    YEAR MISMATCH $syear $year
    }

    # calculate end-date (= start + (length - 1))
    incr length -1
    set end [clock add $start $length days]

    # defaults for talk-length and session-length - see sql below
    try {
	db do transaction {
	    db do eval {
		INSERT INTO conference
		VALUES (NULL,     -- id, auto-assigned
			:title,
			:year,
			:manager,
			:subrecv,
			NULL,     -- city
			NULL,     -- hotel
			NULL,     -- facility
			:start,
			:end,
			:align,
			:length,
			30,       -- minutes per talk
			3,        -- talks per session
			1,        -- registration pending
			NULL      -- No linked schedule.
	        )
	    }
	}
	set id [db do last_insert_rowid]
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    timeline-init $id

    puts [color good OK]

    if {$ascurr} {
	puts -nonewline "Setting as current conference ... "
	flush stdout
	config assign @current-conference $id
	puts [color good OK]
    }

    puts [color warning {Please remember to set the location information}]
    # TODO conference create - Extend to ask for the locations of hotel and facility.
    return
}

proc ::cm::conference::cmd_select {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id [$config @conference]

    puts -nonewline "Setting current conference to \"[color name [get $id]]\" ... "
    config assign @current-conference $id
    puts [color good OK]
    return
}

proc ::cm::conference::cmd_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]

    puts "Details of \"[color name [get $id]]\":"
    [table t {Property Value} {
	set issues [issues $details]
	if {[llength $issues]} {
	    $t add [color bad Issues] [util fmt-issues-cli $issues]
	    $t add {} {}
	}

	dict with details {}

	set xstart [hdate $xstart]
	set xend   [hdate $xend]

	if {$xalign > 0} {
	    set xalign [weekday 2external $xalign]
	} else {
	    set xalign <<none>>
	}

	set xhotelid $xhotel
	if {$xcity     ne {}} { set xcity     [city     2name $xcity] }
	if {$xhotel    ne {}} { set xhotel    [location 2name $xhotel] }
	if {$xfacility ne {}} { set xfacility [location 2name $xfacility] }

	set xmanagement [contact 2name       $xmanagement]
	set xsubmission [contact 2name-email $xsubmission]

	$t add Year             $xyear
	$t add Management       $xmanagement
	$t add {Submissions To} $xsubmission
	$t add Registrations    [rstatus 2name $xrstatus] ;# TODO: colorize the status
	$t add Start            $xstart
	$t add End              $xend
	$t add Aligned          $xalign
	$t add Days             $xlength
	$t add {} {}
	$t add In               $xcity
	$t add @Hotel           $xhotel
	$t add @Facility        $xfacility
	$t add {} {}
	$t add Minutes/Talk     $xtalklen
	$t add Talks/Session    $xsesslen

	if {$xpschedule eq {}} {
	    $t add Schedule "[color bad Undefined]\n(=> conference schedule)"
	} else {
	    $t add Schedule [pschedule piece $xpschedule dname]
	}

	$t add {} {}

	# - -- --- ----  -------- ------------- rate info
	if {![db do exists {
	    SELECT *
	    FROM   rate
	    WHERE  conference = :id
	    AND    location   = :xhotelid
	}]} {
	    $t add [color bad Rate]  "[color bad Undefined]\n(=> conference rate)"
	} else {
	    $t add [color note Rate] "[color note ok]\n(=> conference rates)"
	}

	# - -- --- ----  -------- ------------- timeline
	set tcount [db do eval {
	    SELECT count (id)
	    FROM   timeline
	    WHERE  con = :id
	}]
	if {!$tcount} {
	    set tcount Undefined
	    set color  bad
	    set suffix "\n(=> conference timeline-init)"
	} else {
	    set color  note
	    set suffix "\n(=> conference timeline)"
	}
	$t add [color $color Timeline] [color $color $tcount]$suffix

	# - -- --- ----  -------- ------------- sponsors
	# And the sponsors, if any.
	set scount [db do eval {
	    SELECT count (id)
	    FROM   sponsors
	    WHERE  conference = :id
	}]
	if {!$scount} {
	    set scount None
	    set color  bad
	    set suffix "\n(=> conference add-sponsor)"
	} else {
	    set color  note
	    set suffix "\n(=> conference sponsors)"
	}
	$t add [color $color Sponsors] [color $color $scount]$suffix

	# - -- --- ----  -------- ------------- staff
	set scount [db do eval {
	    SELECT count (id)
	    FROM   conference_staff
	    WHERE  conference = :id
	}]
	if {!$scount} {
	    set scount None
	    set color  bad
	    set suffix "\n(=> conference add-staff)"
	} else {
	    set color  note
	    set suffix "\n(=> conference staff)"
	}
	$t add [color $color Staff] [color $color $scount]$suffix

	# - -- --- ----  -------- ------------- tutorial summary
	set tcount [tutorial scheduled $id]
	if {!$tcount} {
	    set tcount None
	    set color  bad
	    set suffix "\n(=> conference add-tutorial)"
	} else {
	    set color  note
	    set suffix "\n(=> conference tutorials)"
	}
	$t add [color $color Tutorials] [color $color $tcount]$suffix

	# - -- --- ----  -------- ------------- submission summary
	set scount [db do eval {
	    SELECT count (id)
	    FROM   submission
	    WHERE  conference = :id
	}]
	if {!$scount} {
	    set scount None
	    set color  bad
	    set suffix "\n(=> submit)"
	} else {
	    set color  note
	    set suffix "\n(=> submissions)"
	}
	$t add [color $color Submissions] [color $color $scount]$suffix

	# - -- --- ----  -------- ------------- talk summary /TODO
    }] show
    return
}

proc ::cm::conference::cmd_facility {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]
    dict with details {}

    set facility [$config @location]
    set city     [dict get [location get $facility] xcity]
    set flabel   [location 2name $facility]
    set clabel   [city 2name $city]

    puts "Conference \"[color name [get $id]]\":"
    puts "- Set facility as \"[color name $flabel]\""
    puts "- Set city     as \"[color name $clabel]\""

    dict set details xfacility $facility
    dict set details xcity     $city

    if {$xhotel eq {}} {
	puts "- Set hotel    as the same"
	dict set details xhotel $facility
    }

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

proc ::cm::conference::cmd_hotel {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id      [current]
    set details [details $id]
    dict with details {}

    set hotel   [$config @location]
    set city    [dict get [location get $hotel] xcity]
    set hlabel  [location 2name $hotel]
    set clabel  [city 2name $city]

    puts "Conference \"[color name [get $id]]\":"
    puts "- Set hotel    as \"[color name $hlabel]\""

    dict set details xhotel $hotel

    if {$xfacility eq {}} {
	puts "- Set facility as the same"
	puts "- Set city     as \"[color name $clabel]\""

	dict set details xfacility $hotel
	dict set details xcity     $city
    }

    puts -nonewline "Saving ... "
    write $id $details
    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_timeline_shift {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set entry      [$config @event]
    set shift      [$config @shift]

    puts "Shift \"[timeline 2name $entry]\"\nOf    \"[color name [get $conference]]\"\nBy    $shift days"

    db do transaction {
	set old [db do onecolumn {
	    SELECT date 
	    FROM   timeline
	    WHERE  con  = :conference
	    AND    type = :entry
	}]

	set new [clock add $old $shift days]

	puts -nonewline "To    [hdate $new] ... "
	flush stdout

	db do eval {
	    UPDATE timeline
	    SET    date = :new
	    WHERE  con  = :conference
	    AND    type = :entry
	}
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_timeline_set {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set entry      [$config @event]
    set date       [$config @date]

    puts "Set \"[timeline 2name $entry]\"\nOf    \"[color name [get $conference]]\""

    db do transaction {
	puts -nonewline "To    [hdate $date] ... "
	flush stdout

	db do eval {
	    UPDATE timeline
	    SET    date = :date
	    WHERE  con  = :conference
	    AND    type = :entry
	}
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_timeline_done {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set entry      [$config @event]

    puts "Mark \"[timeline 2name $entry]\"\nOf    \"[color name [get $conference]]\""

    db do transaction {
	puts -nonewline "Done ... "
	flush stdout

	db do eval {
	    UPDATE timeline
	    SET    done = 1
	    WHERE  con  = :conference
	    AND    type = :entry
	}
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_timeline_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    set sql [TimelineSQL $conference]

    puts "Timeline of \"[color name [get $conference]]\":"
    [table t {Done Event When} {
	#$t style cmdr/table/html ;# quick testing
	db do eval $sql {
	    set date [hdate $date]
	    set done [expr {$done
			    ? "[color good Yes]"
			    : "No"}]

	    if {$ispublic} {
		set text [color note $text]
		set date [color note $date]
	    }
	    $t add $done $text $date
	}
    }] show
    return
}

proc ::cm::conference::cmd_timeline_init {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id [current]

    puts "Conference \"[color name [get $id]]\", initialize timeline ... "
    flush stdout

    # Clear and re-initialize

    timeline-clear $id
    timeline-init $id

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_timeline_clear {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set id [current]

    puts "Conference \"[color name [get $id]]\", clear timeline ... "
    flush stdout

    timeline-clear $id

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_committee_ping {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set details    [details $conference]
    set dry        [$config @dry]
    set template   [$config @template]
    set tlabel     [template 2name $template]

    puts "Mailing the committee of \"[color name [get $conference]]\":"
    puts "Using template: [color name $tlabel]"
    if {$dry} { puts [color note "Dry run"] }

    set template     [template value $template]
    set destinations [db do eval {
	SELECT id, email
	FROM   email
	WHERE  contact IN (SELECT contact
			   FROM   conference_staff
			   WHERE  conference = :conference
			   AND    role       = 4) -- program committee
    }]

    debug.cm/conference {destinations = ($destinations)}

    set addresses    [lsort -dict [dict values $destinations]]
    set destinations [dict keys $destinations]

    debug.cm/conference {addresses    = ($addresses)}
    debug.cm/conference {destinations = ($destinations)}

    if {![llength $addresses]} {
	util user-error \
	    "No destinations." \
	    COMMITEE PING EMPTY
    }

    set origins [db do eval {
	SELECT dname
	FROM   contact
	WHERE  id IN (SELECT contact
		      FROM   conference_staff
		      WHERE  conference = :conference
		      AND    role       = 3) -- program chair
    }]

    set origins [lsort -dict $origins]
    if {[llength $origins] > 1} {
	set origins [string map {and, and} [join [linsert end-1 and] {, }]]
    } else {
	set origins [join $origins {, }]
    }

    if {![llength $origins]} {
	util user-error \
	    "No chairs." \
	    COMMITEE PING NO-CHAIRS
    }

    puts "From: $origins"
    puts [util indent [join $addresses \n] "To: "]

    # TODO: sponsor-ping - Allow conference placeholders ?
    # TODO: sponsor-ping - Placeholder for a sender signature ? - maybe just ref to p:chair ?

    [table t Text {
	lappend map @mg:sender@ [color red <<sender>>]
	lappend map @mg:name@   [color red <<name>>]
	lappend map @c:year@    [color red <<year>>]
	lappend map @origins@   [color red <<origins>>]
	$t noheader
	$t add [util adjust [util tspace 0 60] \
		    [string map $map $template]]
    }] show

    if {!$dry &&
	(![cmdr interactive?] ||
	 ![ask yn "Send mail ? " no])} {
	puts [color note Aborted]
	return
    }
    if {$dry} {
	puts [color note "Skipped mailing"]
	return
    }

    set mconfig [mailer get-config]
    set template [string map [list @origins@ $origins] [insert $conference $template]]

    mailer batch _ address name $destinations {
	mailer send $mconfig \
	    [list $address] \
	    [mailgen call $address $name $template] \
	    0 ;# not verbose
    }

    puts [color good OK]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_submission_add {config} {
    debug.cm/conference {}
    Setup
    db show-location

    # submission-add - TODO - Block submissions to a past/locked conference
    # => trigger on the conference timeline ?!
    # => nicer workflow (grace handling) with an explicit flag.

    set conference [current]
    set invited    [$config @invited]
    set title      [$config @title]
    set authors    [$config @author]
    set now        [$config @on]
    set abstract   [read stdin]

    puts -nonewline "Add submission \"[color name $title]\" to conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do transaction {
	db do eval {
	    INSERT INTO submission
	    VALUES (NULL, :conference, :title, :abstract, NULL, :invited, :now)
	}
	set submission [db do last_insert_rowid]
	foreach author $authors {
	    db do eval {
		INSERT INTO submitter
		VALUES (NULL, :submission, :author, NULL)
	    }
	}
    }

    puts -nonewline "Id [color name [get-submission-handle $submission]] ... "
    flush stdout

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_submission_drop {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Changing conference \"[color name [get $conference]]\" ... "

    foreach submission [$config @submission] {
	puts -nonewline "Remove submission \"[color name [get-submission $submission]]\" ... "
	flush stdout

	# submission-drop TODO - prevent removal of submissions which have talks.

	db do transaction {
	    db do eval {
		DELETE
		FROM  submitter
		WHERE submission = :submission
		;
		DELETE
		FROM  submission
		WHERE id = :submission
	    }
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_submission_setsummary {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission] 
    set summary    [read stdin]

    puts -nonewline "Set summary of \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do eval {
	UPDATE submission
	SET    summary = :summary
	WHERE  id      = :submission
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_submission_setabstract {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission] 
    set abstract   [read stdin]

    puts -nonewline "Set abstract of \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do eval {
	UPDATE submission
	SET    abstract = :abstract
	WHERE  id       = :submission
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_submission_settitle {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]
    set title      [$config @text]

    puts -nonewline "Set title of \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do eval {
	UPDATE submission
	SET    title = :title
	WHERE  id    = :submission
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_submission_setdate {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]
    set date       [$config @date]

    puts -nonewline "Set submission date of \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do eval {
	UPDATE submission
	SET    submitdate = :date
	WHERE  id         = :submission
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_submission_addsubmitter {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]

    puts "Adding submitters to \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "

    foreach submitter [$config @submitter] {
	puts -nonewline "  \"[color name [contact 2name $submitter]]\" ... "
	flush stdout

	db do eval {
	    INSERT INTO submitter
	    VALUES (NULL, :submission, :submitter, NULL)
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_submission_dropsubmitter {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]

    puts "Removing submitters from \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "

    foreach submitter [$config @submitter] {
	puts -nonewline "  \"[color name [contact 2name $submitter]]\" ... "
	flush stdout

	db do eval {
	    DELETE
	    FROM   submitter
	    WHERE  submission = :submission
	    AND    contact    = :submitter
	}

	puts [color good OK]
    }
    return
}


proc ::cm::conference::cmd_submission_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission] 

    set w [util tspace [expr {[string length Abstract]+7}] 72]

    puts [color name [get $conference]]
    [table t {Property Value} {
	db do eval {
	    SELECT id, title, abstract, summary, invited, submitdate
	    FROM   submission
	    WHERE  id = :submission
	} {
	    set authors [join [db do eval {
		SELECT dname
		FROM   contact
		WHERE  id IN (SELECT contact
			      FROM   submitter
			      WHERE  submission = :id)
		ORDER BY dname
	    }] \n]

	    set issues {}

	    if {([string trim $abstract] eq {}) &&
		([string trim $summary] eq {})} {
		+issue "Missing abstract/summary"
	    }

	    # Accepted as talk ?
	    set talk [db do onecolumn {
		SELECT id
		FROM   talk
		WHERE  submission = :id
	    }]
	    # When accepted, check for speakers and attachments.
	    # These are issues if found missing.
	    if {$talk ne {}} {
		set accepted 1
		set alabel [color good yes]
		if {![db do eval {
		    SELECT count(id)
		    FROM   talker
		    WHERE  talk = :talk
		}]} {
		    +issue "No speakers"
		}
		if {![db do eval {
		    SELECT count(id)
		    FROM   attachment
		    WHERE  talk = :talk
		}]} {
		    +issue "No materials"
		}
	    } else {
		set accepted 0
		set alabel [color bad no]
	    }

	    if {[llength $issues]} {
		$t add [color bad Issues] [util fmt-issues-cli $issues]
		$t add {} {}
	    }

	    $t add Id        [get-submission-handle $id]
	    $t add Submitted [hdate $submitdate]
	    $t add Title     $title
	    $t add Accepted  $alabel

	    if {$invited} {
		$t add [color note Invited] yes
	    } else {
		$t add Invited  no
	    }

	    if {$accepted} {
		db do eval {
		    SELECT type AS ttype, state AS tstate
		    FROM   talk
		    WHERE  submission = :id
		} {
		    $t add Type  [talk-type  2name $ttype]
		    $t add State [talk-state 2name $tstate]
		}
	    }

	    $t add Authors  $authors

	    if {$accepted} {
		set speakers [talk-speakers $talk]
		if {[llength $speakers]} {
		    $t add Speakers [join $speakers \n]
		}

		# TODO: attachments - determine and show size ?
		set attachments [db do eval {
		    SELECT type AS atype
		    FROM   attachment
		    WHERE  talk = :talk
		}]
		if {[llength $attachments]} {
		    $t add Attachments [join $attachments \n]
		}
	    }

	    $t add Abstract [util adjust $w $abstract]
	    $t add Summary  [util adjust $w $summary]
	}
    }] show
    return
}

proc ::cm::conference::cmd_submission_list {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    set w [string length "| Id | Date | Authors |  | Title | Accepted |"]
    set w [util tspace $w 60]

    puts "Submissions for \"[color name [get $conference]]\""
    [table t {Id Date Authors {} Title Accepted} {
	db do eval {
	    SELECT id, title, invited, submitdate, abstract, summary
	    FROM   submission
	    WHERE  conference = :conference
	    ORDER BY submitdate, id
	} {
	    # submission-list - TODO - pull and show the per-author notes
	    # submission-list - TODO - show if a talk is associated with the submission
	    set authors [join [db do eval {
		SELECT dname
		FROM   contact
		WHERE  id IN (SELECT contact
			      FROM   submitter
			      WHERE  submission = :id)
		ORDER BY dname
	    }] \n]
	    set invited    [expr {$invited ? "Invited" : ""}]
	    set submitdate [hdate $submitdate]

	    set issues {}

	    if {([string trim $abstract] eq {}) &&
		([string trim $summary] eq {})} {
		+issue "Missing abstract/summary"
	    }

	    # Accepted as talk ?
	    set talk [db do onecolumn {
		SELECT id
		FROM   talk
		WHERE  submission = :id
	    }]
	    # When accepted, check for speakers and attachments.
	    # These are issues if found missing.
	    if {$talk ne {}} {
		set accepted [color good yes]
		if {![db do eval {
		    SELECT count(id)
		    FROM   talker
		    WHERE  talk = :talk
		}]} {
		    +issue "No speakers"
		}
		if {![db do eval {
		    SELECT count(id)
		    FROM   attachment
		    WHERE  talk = :talk
		}]} {
		    +issue "No materials"
		}
	    } else {
		set accepted [color bad no]
	    }

	    if {[llength $issues]} {
		append authors \n [util fmt-issues-cli $issues]
	    }

	    set title [util adjust $w $title]
	    $t add [get-submission-handle $id] $submitdate $authors $invited $title $accepted
	}
    }] show
    return
}

proc ::cm::conference::cmd_submission_list_accepted {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    set w [string length "| Id | Type | Date | State | Authors | Speakers |  | Title | Attachments |"]
    set w [util tspace $w 60]

    puts "Submissions for \"[color name [get $conference]]\""
    [table t {Id Type Date State Authors Speakers {} Title Attachments} {
	db do eval {
	    SELECT S.id         AS id
	    ,      S.title      AS title
	    ,      S.invited    AS invited
	    ,      S.submitdate AS submitdate
	    ,      S.abstract   AS abstract
	    ,      S.summary    AS summary
	    ,      TT.text      AS ttype
	    ,      TS.text      AS tstate
	    ,      T.id         AS tid
	    FROM   submission S
	    ,      talk       T
	    ,      talk_type  TT
	    ,      talk_state TS
	    WHERE  S.conference = :conference
	    AND    T.submission = S.id
	    AND    T.type       = TT.id
	    AND    T.state      = TS.id
	    ORDER BY S.submitdate, S.id
	} {
	    set authors [join [db do eval {
		SELECT dname
		FROM   contact
		WHERE  id IN (SELECT contact
			      FROM   submitter
			      WHERE  submission = :id)
		ORDER BY dname
	    }] \n]
	    set speakers [join [talk-speakers $tid] \n]
	    set attachments [join [db do eval {
		SELECT type
		FROM   attachment
		WHERE  talk = :tid
		ORDER BY type
	    }] \n]
	    set invited    [expr {$invited ? "Invited" : ""}]
	    set submitdate [hdate $submitdate]

	    set issues {}

	    if {([string trim $abstract] eq {}) &&
		([string trim $summary] eq {})} {
		+issue "Missing abstract/summary"
	    }

	    # These are issues if speakers or attachments are found missing.
	    if {$speakers eq {}} {
		+issue "No speakers"
	    }
	    if {$attachments eq {}} {
		+issue "No materials"
	    }

	    if {[llength $issues]} {
		append authors \n [fmt-issues-cli $issues]
	    }

	    set title [util adjust $w $title]
	    $t add [get-submission-handle $id] $ttype $submitdate $tstate \
		$authors $speakers $invited $title $attachments
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_submission_accept {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]

    if {[$config @type set?]} {
	set type [$config @type]
    } else {
	set invited [db do eval { SELECT invited FROM submission WHERE id = :submission }]
	set type [expr {$invited ? 3 : 2}]
    }

    puts -nonewline "Accept \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do transaction {
	if {[db do exists {
	    SELECT id FROM talk WHERE submission = :submission
	}]} {
	    puts [color note {Already accepted, nothing done}]
	} else {
	    db do eval {
		INSERT INTO talk
		VALUES (NULL, :submission, :type, 1, 0)
	    }

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::conference::cmd_submission_reject {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "In conference \"[color name [get $conference]]\""

    foreach submission [$config @submission] {
	puts -nonewline "Reject \"[color name [get-submission $submission]]\" ... "
	flush stdout

	db do eval {
	    DELETE
	    FROM  talk
	    WHERE submission = :submission
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_submission_addspeaker {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]

    set talk [db do onecolumn {
	SELECT id
	FROM   talk
	WHERE  submission = :submission
    }]
    if {$talk eq {}} {
	util user-error \
	    "Unable to add speakers for a submission which is not an accepted talk" \
	    NOT-A-TALK
    }

    puts "Adding speakers to \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "

    foreach speaker [$config @speaker] {
	puts -nonewline "  \"[color name [contact 2name $speaker]]\" ... "
	flush stdout

	db do eval {
	    INSERT INTO talker
	    VALUES (NULL, :talk, :speaker)
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_submission_dropspeaker {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]

    set talk [db do onecolumn {
	SELECT id
	FROM   talk
	WHERE  submission = :submission
    }]
    if {$talk eq {}} {
	util user-error \
	    "Unable to remove speakers from a submission which is not an accepted talk" \
	    NOT-A-TALK
    }

    puts "Removing speakers from \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "

    foreach speaker [$config @speaker] {
	puts -nonewline "  \"[color name [contact 2name $speaker]]\" ... "
	flush stdout

	db do eval {
	    DELETE
	    FROM   talker
	    WHERE  talk    = :talk
	    AND    contact = :speaker
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_submission_attach {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]
    set type       [$config @type]
    set mime       [$config @mimetype]

    set talk [db do onecolumn {
	SELECT id
	FROM   talk
	WHERE  submission = :submission
    }]
    if {$talk eq {}} {
	util user-error \
	    "Unable to attach to a submission which is not an accepted talk" \
	    NOT-A-TALK
    }

    puts -nonewline "Adding attachment \"$type\" to \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\" ... "
    flush stdout

    fconfigure stdin -translation binary -encoding binary
    set data [read stdin]

    db do eval {
	INSERT INTO attachment
	VALUES (NULL, :talk, :type, :mime, @data)
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_submission_detach {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set submission [$config @submission]

    set talk [db do onecolumn {
	SELECT id
	FROM   talk
	WHERE  submission = :submission
    }]
    if {$talk eq {}} {
	util user-error \
	    "Unable to detach from a submission which is not an accepted talk" \
	    NOT-A-TALK
    }

    puts "Removing attachments from \"[color name [get-submission $submission]]\" in conference \"[color name [get $conference]]\""

    foreach type [$config @type] {
	puts -nonewline "- \"[get-attachment $type]\" ... "
	flush stdout

	db do eval {
	    DELETE
	    FROM   attachment
	    WHERE  id = :type
	}

	puts [color good OK]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_registration {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set newstatus  [$config @status] 

    puts -nonewline "Conference \"[color name [get $conference]]\" registration = [rstatus 2name $newstatus] ... "
    flush stdout

    db do eval {
	UPDATE conference
	SET    rstatus = :newstatus
	WHERE  id      = :conference
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_sponsor_ping {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set dry        [$config @dry]
    set template   [$config @template]
    set tlabel     [template 2name $template]

    puts "Mailing the sponsors of \"[color name [get $conference]]\":"
    puts "Using template: [color name $tlabel]"
    if {$dry} { puts [color note "Dry run"] }

    set template     [template value $template]
    set destinations [db do eval {
	SELECT id, email
	FROM   email
	WHERE  contact IN (-- branch a: sponsors which are companies, mail their represenatives
			   SELECT person
			   FROM   liaison
			   WHERE  company IN (SELECT contact
					      FROM   sponsors
					      WHERE  conference = :conference)
			   UNION
			   -- branch b: sponsors which are people, mail them directly
			   SELECT id
			   FROM contact
			   WHERE id IN (SELECT contact
					FROM   sponsors
					WHERE  conference = :conference)
			   AND   type = 1 -- sponsor is person
			   -- TODO: in-memory cache of type/name mapping. or put into join ?
			   )
    }]

    debug.cm/conference {destinations = ($destinations)}

    set addresses    [lsort -dict [dict values $destinations]]
    set destinations [dict keys $destinations]

    debug.cm/conference {addresses    = ($addresses)}
    debug.cm/conference {destinations = ($destinations)}

    if {![llength $addresses]} {
	util user-error \
	    "No destinations." \
	    SPONSOR PING EMPTY
    }

    puts [util indent [join $addresses \n] "To: "]

    # TODO: sponsor-ping - Allow conference placeholders ?
    # TODO: sponsor-ping - Placeholder for a sender signature ? - maybe just ref to p:chair ?

    [table t Text {
	lappend map @mg:sender@ [color red <<sender>>]
	lappend map @mg:name@   [color red <<name>>]
	$t noheader
	$t add [util adjust [util tspace 0 60] \
		    [string map $map $template]]
    }] show

    if {!$dry &&
	(![cmdr interactive?] ||
	 ![ask yn "Send mail ? " no])} {
	puts [color note Aborted]
	return
    }
    if {$dry} {
	puts [color note "Skipped mailing"]
	return
    }

    set mconfig [mailer get-config]
    mailer batch _ address name $destinations {
	mailer send $mconfig \
	    [list $address] \
	    [mailgen call $address $name $template] \
	    0 ;# not verbose
    }

    puts [color good OK]
}

proc ::cm::conference::cmd_sponsor_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Sponsors of \"[color name [get $conference]]\":"
    [table t {Sponsor Reference} {
	# TODO: sponsors - mail/link/notes ?
	db do eval {
	    SELECT C.id          AS contact,
	           C.dname       AS name,
	           C.type        AS type
	    FROM   sponsors S,
	           contact  C
	    WHERE  S.conference = :conference
	    AND    S.contact    = C.id
	    ORDER BY C.dname
	} {
	    # get liaisons of the sponsor companies.
	    # get affiliations of sponsoring persons.

	    set related [contact relations-formatted $contact $type]

	    $t add $name $related
	}
    }] show
    return
}

proc ::cm::conference::cmd_sponsor_link {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Adding sponsors to conference \"[color name [get $conference]]\" ... "

    foreach contact [$config @name] {
	puts -nonewline "  \"[color name [contact 2name $contact]]\" ... "
	flush stdout

	db do eval {
	    INSERT INTO sponsors
	    VALUES (NULL, :conference, :contact)
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_sponsor_unlink {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Removing sponsors from conference \"[color name [get $conference]]\" ... "

    foreach contact [$config @name] {
	puts -nonewline "  \"[color name [contact 2name $contact]]\" ... "
	flush stdout

	db do eval {
	    DELETE
	    FROM sponsors
	    WHERE conference = :conference
	    AND   contact    = :contact
	}

	puts [color good OK]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_staff_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Staff of \"[color name [get $conference]]\":"
    [table t {Role Staff} {
	set first 1
	db do eval {
	    SELECT C.dname AS name,
	           R.text  AS role
	    FROM   conference_staff S,
	           contact          C,
	           staff_role       R
	    WHERE  S.conference = :conference
	    AND    S.contact    = C.id
	    AND    S.role       = R.id
	    ORDER BY role, name
	} {
	    if {$first} {
		set lastrole $role
		set first 0
	    } elseif {$lastrole ne $role} {
		$t add {} {}
		set lastrole $role
	    } else {
		set role {}
	    }
	    $t add $role $name
	}
    }] show
    return
}

proc ::cm::conference::cmd_staff_link {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set role       [$config @role]

    puts "Adding [staff-role 2name $role] to conference \"[color name [get $conference]]\" ... "

    foreach contact [$config @name] {
	puts -nonewline "  \"[color name [contact 2name $contact]]\" ... "
	flush stdout

	db do eval {
	    INSERT INTO conference_staff
	    VALUES (NULL, :conference, :contact, :role)
	}

	puts [color good OK]
    }
    return
}

proc ::cm::conference::cmd_staff_unlink {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Removing staff from conference \"[color name [get $conference]]\" ... "

    lassign [$config @name] role contact

    debug.cm/conference {role    = ($role)}
    debug.cm/conference {contact = ($contact)}

    puts -nonewline "  [staff-role 2name $role] \"[color name [contact 2name $contact]]\" ... "
    flush stdout

    db do eval {
	DELETE
	FROM conference_staff
	WHERE conference = :conference
	AND   contact    = :contact
	AND   role       = :role
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_tutorial_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set start [dict get [details $conference] xstart]

    puts "Tutorial lineup of \"[color name [get $conference]]\":"
    # Similar code will be needed for the website ... Maybe same, with
    # a different style for the table and elements

    # Day   Track  Morning     Afternoon Evening
    # 0     1      Tag + Title ...
    # 0     ...
    # ...

    lassign [tutorial dayrange   $conference] daymin   daymax   daylast
    lassign [tutorial trackrange $conference] trackmin trackmax tracklast

    # Build table, by day, by track in day, by half in the day.
    # TODO: See if we can do loops and the range extraction above in a single sql SELECT.
    # Main issue might be filling in the holes

    [table t {Date Day Track Half Tag Title} {
	for {set day $daymin} {$day < $daymax} {incr day} {
	    set  date [hdate [clock add $start $day days]]
	    set  dlabel $day
	    incr dlabel ;# Display is 1-based.

	    for {set track $trackmin} {$track < $trackmax} {incr track} {
		set dtrack $track
		db do eval {
		    SELECT id   AS half,
		           text AS dhalf
		    FROM   dayhalf
		    ORDER  BY id
		} {
		    set tutorial [tutorial cell $conference $day $half $track]

		    debug.cm/conference {con $conference day $day track $track half $half == $tutorial}

		    if {$tutorial ne {}} {
			set    tdetails [tutorial get $tutorial]
			set    title    [dict get $tdetails xtitle]
			set    tag      @
			append tag      [dict get [contact get [dict get $tdetails xspeaker]] xtag] :
			append tag      [dict get $tdetails xtag]
		    } else {
			set tag   [color bad None]
			set title [color bad None]
		    }

		    $t add $date $dlabel $dtrack $dhalf $tag $title
		    set dlabel {}
		    set dtrack {}
		    set date {}
		}
		if {($day == $daylast) && ($track == $tracklast)} continue
		$t add {} {} {} {} {} {}
	    }
	}
    }] show
    return
}

proc ::cm::conference::cmd_tutorial_link {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set day      [$config @day]      ;# 1-based, limit to conference length.
    set half     [$config @half]
    set track    [$config @track]    ;# future - constrain|limit to a max number of tracks
    set tutorial [$config @tutorial]

    puts "Adding \"[color name [tutorial 2name $tutorial]]\" to conference \"[color name [get $conference]]\" ... "
    set details [details $conference]
    set clen    [dict get $details xlength]

    if {$day > $clen} {
	util user-error "Bad day $day, conference is only $clen days long" DAY-OUT-OF-RANGE $day $clen
    }

    # TODO: day (=offset) => date from start, weekday

    puts "@ day $day [dayhalf 2name $half], track $track"
    flush stdout

    tutorial schedule $conference $tutorial $day $half $track

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_tutorial_unlink {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Removing tutorials from conference \"[color name [get $conference]]\" ... "

    foreach tutorial [$config @tutorial] {
	puts -nonewline "- \"[color name [tutorial 2name $tutorial]]\" ... "
	flush stdout

	tutorial unschedule $conference $tutorial

	puts [color good OK]
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_rate_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set details [details $conference]
    dict with details {}
    set location $xhotel
    if {$location eq {}} {
	util user-error "No hotel known" \
	    CONFERENCE RATE HOTEL
    }

    [table/d t {
	db do eval {
	    SELECT rate, decimal, currency, groupcode, begindate, enddate, deadline, pdeadline
	    FROM   rate
	    WHERE  conference = :conference
	    AND    location   = :location
	} {
	    set factor 10e$decimal
	    set rate [format %.${decimal}f [expr {$rate / $factor}]]

	    set begindate [expr {($begindate ne {})
				 ? [hdate $begindate]
				 : [color bad Undefined]}]
	    set enddate [expr {($enddate ne {})
				 ? [hdate $enddate]
				 : [color bad Undefined]}]
	    set deadline [expr {($deadline ne {})
				 ? [hdate $deadline]
				 : [color bad Undefined]}]
	    set pdeadline [expr {($pdeadline ne {})
				 ? [hdate $pdeadline]
				 : [color bad Undefined]}]

	    $t add Rate      "$rate $currency"
	    $t add GroupCode $groupcode
	    $t add Begin                   $begindate
	    $t add End                     $enddate
	    $t add {Registration deadline} $deadline
	    $t add {Public deadline}       $pdeadline
	}
    }] show
    return
}

proc ::cm::conference::cmd_rate_set {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set details [details $conference]
    dict with details {}
    set location $xhotel
    if {$location eq {}} {
	util user-error "No hotel known to apply the rate to" \
	    CONFERENCE RATE HOTEL
    }

    set rate     [$config @rate]
    set currency [$config @currency]
    set decimal  [$config @decimal]

    set group [cdefault @groupcode       {return {}}]
    set begin [cdefault @begin           {set xstart}]
    set end   [cdefault @end             {set xend}]
    set dead  [cdefault @deadline        {clock add $begin -14 days}]
    set pdead [cdefault @public-deadline {clock add $dead   -7 days}]

    # Limit to the chosen number of digits after the decimal point, we
    # will store things as int.
    set factor 10e$decimal
    set rate [expr {int($rate * $factor)}]

    puts "Setting rates for conference \"[color name [get $conference]]\" ... "
    flush stdout

    if {[db do exists {
	SELECT *
	FROM   rate
	WHERE  conference = :conference
	AND    location   = :location
    }]} {
	# Update existing rate
	db do eval {
	    UPDATE rate
	    SET    rate       = :rate
	    ,      decimal    = :decimal
	    ,      currency   = :currency
	    ,      groupcode  = :group
	    ,      begindate  = :begin
	    ,      enddate    = :end
	    ,      deadline   = :dead
	    ,      pdeadline  = :pdead
	    WHERE  conference = :conference
	    AND    location   = :location
	}
    } else {
	# Insert the rate data
	db do eval {
	    INSERT INTO rate
	    VALUES (NULL, :conference, :location,
		    :rate, :decimal, :currency,
		    :group, :begin, :end, :dead, :pdead)
	}
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_end_set {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set details    [details $conference]
    set end        [$config @enddate]

    dict set details xend $end

    puts "Setting new end-date \"[hdate $end]\" for conference \"[color name [get $conference]]\" ... "
    flush stdout

    write $conference $details

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_schedule_set {config} {
    debug.cm/conference {}
    Setup
    schedule setup

    db show-location

    # Link named physical schedule to the conference.
    # Locate all placeholder items, their labels and use
    # them to generate the logical schedule to fill out.

    # TODO: Handle a previous physical schedule. Handle carry over of
    # TODO: user-customized logical entries.

    set conference [current]
    set pschedule  [$config @name]
    set pslabel    [pschedule piece $pschedule dname]

    puts -nonewline "\nConference \"[color name [get $conference]]\": Linking to schedule \"[color name $pslabel]\" ... "
    flush stdout

    db do transaction {
	schedule drop    $conference
	DB-pschedule-set $conference $pschedule
	foreach label [pschedule item-placeholders $pschedule] {
	    switch -glob -- $label {
		@S* {
		    # Sessions, Fixed lines. Create a basic default.
		    regexp {@S(.*)$} $label -> sno
		    schedule add_fixed $conference $label "Session $sno"
		}
		@T* {
		    # Tutorial placeholder, encoded slot.
		    regexp {@T(\d+)([ame])(\d+)$} $label -> day half track
		    # half = m morning   1
		    #      = a afternoon 2
		    #      = e evening   3
		    set half [string map {m 1 a 2 e 3} $half]
		    incr day   -1

		    # Find the tutorial in that slot.
		    set t [tutorial cell-schedule $conference $day $half $track]

		    debug.cm/conference {con $conference day $day track $track half $half == $t}

		    if {$t eq {}} {
			# Nothing. Make it fixed, a warning.
			schedule add_fixed $conference $label "!Missing"
		    } else {
			# Link tutorial into the slot.
			schedule add_tutorial $conference $label $t
		    }
		}
		default {
		    # General entry, all undefined.
		    schedule add_empty $conference $label
		}
	    }
	}
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_schedule_show {config} {
    debug.cm/conference {}
    Setup
    schedule setup

    db show-location

    set conference [current]
    set details    [details $conference]
    dict with details {}

    puts -nonewline "\nConference \"[color name [get $conference]]\": "
    flush stdout

    if {$xpschedule eq {}} {
	util user-error {No schedule defined}
    }

    set pslabel [pschedule piece $xpschedule dname]
    puts "Schedule \"[color name $pslabel]\": " 

    [table t {Slot Type Details} {
	foreach {label talk tutorial session} [schedule of $conference] {
	    if {$talk ne {}} {
		set type Talk
		set note $talk
	    } elseif {$tutorial ne {}} {
		set type Tutorial
		set note $tutorial
	    } elseif {$session ne {}} {
		set type Fixed
		set note $session
	    } else {
		set type {}
		set note {}
	    }
	    $t add $label $type $note
	}
    }] show
    return
}

proc ::cm::conference::cmd_schedule_edit {config} {
    debug.cm/conference {}
    Setup
    schedule setup

    db show-location

    set conference [current]
    set details    [details $conference]
    dict with details {}

    puts -nonewline "\nConference \"[color name [get $conference]]\": "
    flush stdout

    if {$xpschedule eq {}} {
	util user-error {No schedule defined}
    }

    set pslabel [pschedule piece $xpschedule dname]
    puts -nonewline "Schedule \"[color name $pslabel]\": " 
    flush stdout

    set slot  [$config @label]
    set sname [$config @label string]
    set type  [$config @type]
    set value [$config @value]

    puts -nonewline "Slot \"[color name $sname]\" := " 
    flush stdout

    # TODO: Ensure uniqueness of talk/tutorial assignments.

    switch -exact $type {
	talk {
	    # value = talk-id
	    set title [get-talk-title $value]
	    puts -nonewline "Talk \"[color name $title]\" ... " 
	    flush stdout

	    schedule set_talk $slot $value
	}
	tutorial {
	    # value = (scheduled-id day half tutorial)
	    lassign $value value _ _ _
	    set title [tutorial 2name-from-schedule $value]
	    puts -nonewline "Tutorial \"[color name $title]\" ... " 
	    flush stdout

	    schedule set_tutorial $slot $value
	}
	fixed {
	    # value = string
	    puts -nonewline "\"$value\" ... " 
	    flush stdout

	    schedule set_fixed $slot $value
	}
    }

    puts [color good OK]
    return
}

proc ::cm::conference::DB-pschedule-set {conference pschedule} {
    debug.cm/conference {}
    Setup
    db do eval {
	UPDATE conference
	SET    pschedule = :pschedule
	WHERE  id = :conference
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_registration_list {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set speakers   [the-presenters $conference]
    # Tutorial speakers are not required to register, i.e. they can
    # teach without attending the tech sessions.
    set count 0

    puts "Registered for \"[color name [get $conference]]\" ..."
    [table t {Who Walkin? {Day 1 Morning} {Day 1 Afternoon} {Day 2 Morning} {Day 2 Afternoon}} {
	# Show the registrations we have.
	foreach {dname walkin ta tb tc td} [registered listing $conference] {
	    $t add $dname [hbool $walkin] $ta $tb $tc $td
	    dict unset speakers $dname
	    incr count
	}

	# Now, if we have speakers which are not registered, show
	# these as well, highlighted as issue.

	if {[dict size $speakers]} {
	    if {$count} { $t add {} {} {} {} {} {} }
	    foreach dname [lsort -dict [dict keys $speakers]] {
		$t add [color bad "MISSING: $dname"] {} {} {} {} {}
	    }
	}
    }] show
    return
}

proc ::cm::conference::cmd_registration_add {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set person     [$config @person] ;    debug.cm/conference {person = $person}
    set walkin     [$config @walkin] ;    debug.cm/conference {walkin = $walkin}
    set tutorials  [$config @taking] ;    debug.cm/conference {tut = ([join $tutorials {),(}])}
    # tutorials = ((id,day,half,tutorial)...)
    #        id => in the tutorial __schedule__

    if {[llength $tutorials] > 4} {
	error "Too many tutorials, canonly handle 4."
    }

    set c [get $conference]
    set p [contact get $person]

    puts -nonewline "Register \"[color name $p]\" for \"[color name $c]\" ... "
    set close 0

    try {
	db do transaction {
	    set r [registered add $conference $person $walkin]
	    # TODO: tutorials - map day/half into slot number.
	    # ASSUMES day  in (0,1),  |1st two conference days
	    #         half in (1,2)   |morning,afternoon
	    # ==> (1..4) ((half+2*day)
	    # Day 1 morning   0,1 - 1
	    # Day 1 afternoon 0,2 - 2
	    # Day 2 morning   1,1 - 3
	    # Day 2 afternoon 1,2 - 4

	    foreach t $tutorials {
		lassign $t id day half tutorial
		debug.cm/conference {tutorial s=$id d=$day h=$half t=$tutorial}

		puts -nonewline "\n Taking tutorial \"[color name [cm tutorial get $tutorial]]\""

		set slot [expr {2*$day+$half}]
		debug.cm/conference {slot = $slot}

		registered pupil-of $r $slot $id
		set close 1
	    }
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	if {$close} { puts {} }
	puts [color bad $e]
	return
    }

    if {$close} { puts {} }
    puts [color good OK]
    return
}

proc ::cm::conference::cmd_registration_remove {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set person     [$config @person]

    set c [get $conference]
    set p [contact get $person]

    puts -nonewline "Unregister \"[color name $p]\" from \"[color name $c]\" ... "

    try {
	db do transaction {
	    registered remove $conference $person
	}
    } on error {e o} {
	# TODO: trap only proper delete error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::its-hotel {p} {
    # add @hotel - generate callback
    debug.cm/conference {}
    set conference [current]
    set hotel [dict get [details $conference] xhotel]
    return $hotel
}

proc ::cm::conference::cmd_booking_list {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set speakers   [the-speakers $conference]
    set count 0

    puts "Booked for \"[color name [get $conference]]\" ..."
    [table t {Who Hotel City} {
	foreach {dname _ locname _ _ cityname state nation} [booked listing $conference] {
	    $t add $dname $locname [city label $cityname $state $nation]
	    dict unset speakers $dname
	    incr count
	}

	# Now, if we have speakers without a booked hotel, show these
	# as well, highlighted as issue.

	if {[dict size $speakers]} {
	    if {$count} { $t add {} {} {} }
	    foreach dname [lsort -dict [dict keys $speakers]] {
		$t add [color bad "MISSING $dname"] {} {}
	    }
	}
    }] show
    return
}

proc ::cm::conference::cmd_booking_add {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set person     [$config @person]
    set hotel      [$config @hotel]

    set c [get $conference]
    set p [contact get $person]
    set h [location get $hotel]

    puts -nonewline "Booking \"[color name $p]\" at \"[color name $h]\" for \"[color name $c]\" ... "

    try {
	db do transaction {
	    booked add $conference $person $hotel
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_booking_remove {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set person     [$config @person]

    set c [get $conference]
    set p [contact get $person]

    puts -nonewline "Unbooking \"[color name $p]\" for \"[color name $c]\" ... "

    try {
	db do transaction {
	    booked remove $conference $person
	}
    } on error {e o} {
	# TODO: trap only proper delete error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_website_make {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set dstdir     [$config @destination]

    # TODO Fix issues with using a relative destination path moving outside of the CWD.

    # # ## ### ##### ######## #############
    puts "Remove old..."
    file delete -force  $dstdir ${dstdir}_out

    # # ## ### ##### ######## #############
    puts "Initialization..."
    ssg init $dstdir ${dstdir}_out ;# TODO Use a tmp dir for this
    file delete -force $dstdir/pages/blog

    # # ## ### ##### ######## #############
    ## Data configuration

    if {[rate-have-group-code $conference]} {
	puts "Groupcode: [color good Yes]"
    } else {
	puts "Groupcode: [color bad No]"
    }

    if {[have-speakers $conference]} {
	puts "Speakers:  [color good Yes]"
    } else {
	puts "Speakers:  [color bad None]"
    }

    if {[tutorial scheduled $conference]} {
	puts "Tutorials: [color good Yes]"
    } else {
	puts "Tutorials: [color bad None]"
    }

    if {[have-talks $conference]} {
	puts "Talks:     [color good Yes]"
    } else {
	puts "Talks:     [color bad None]"
    }

    set rstatus [registration-mode $conference]
    puts "Registration: $rstatus"

    # # ## ### ##### ######## #############
    puts "Filling in..."

    if {[have-speakers $conference]} {
	make_page Overview  index  make_overview_speakers $conference
    } else {
	make_page Overview  index  make_overview
    }

    lappend navbar {*}[make_page {Call For Papers}  cfp  make_callforpapers]

    if {[rate-have-group-code $conference]} {
	lappend navbar {*}[make_page Location  location  make_location]
    } else {
	lappend navbar {*}[make_page Location  location  make_location_nogc]
    }

    # The rstatus strings match the contents of table 'rstatus'.
    switch -exact -- $rstatus {
	pending {
	    lappend navbar {*}[make_page Registration register make_registration_pending]
	}
	open {
	    lappend navbar {*}[make_page Registration              register       make_registration_open]
	    make_page                   {Registration By Mail/Fax} register_paper make_registration_paper
	}
	closed {
	    lappend navbar {*}[make_page Registration register make_registration_closed]
	}
    }

    if {[tutorial scheduled $conference]} {
	lappend navbar {*}[make_page Tutorials  tutorials   make_tutorials $conference]
    } else {
	lappend navbar {*}[make_page Tutorials  tutorials   make_tutorials_none]
    }

    lappend navbar {*}[make_page Schedule   schedule   make_schedule]
    if {[have-talks $conference]} {
	make_page   Abstracts  abstracts  make_abstracts $conference
    } else {
	make_page   Abstracts  abstracts  make_abstracts_none
    }

    if {[have-speakers $conference]} {
	make_page  Speakers  bios  make_speakers $conference
    } else {
	make_page  Speakers  bios  make_speakers_none
    }

    lappend navbar {*}[make_page Proceedings       proceedings make_proceedings]
    #lappend navbar {*}[make_page Contact           contact     make_contact]
    make_page                    Disclaimer        disclaimer  make_disclaimer

    make_internal_page Administrivia __dwarf make_admin $conference

    # # ## ### ##### ######## #############
    # Configuration file.
    puts "\tWebsite configuration"

    # NOTE: website.conf TODO - treat template as the semi-dict it is, prog access.
    #       Do programmatic access, instead of text manipulation.

    set text [template use www-wconf]
    set text [insert $conference $text]
    lappend map @wc:nav@     $navbar
    lappend map @wc:sidebar@ [make_sidebar $conference]
    set    text [string map $map $text]
    unset map
    fileutil::writeFile $dstdir/website.conf $text

    # # ## ### ##### ######## #############
    puts "Generation..."
    ssg build $dstdir ${dstdir}_out ;# TODO from tmp dir, use actual destination => implied deployment

    return
    puts "Deploy..."
    ssg deploy-copy $dstdir
    # custom - use rsync - or directory swap
}

proc ::cm::conference::ssg {args} {
    # option to switch verbosity
    #exec >@stdout 2>@stderr <@stdin ssg {*}$args
    exec 2>@stderr <@stdin ssg {*}$args
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::conference::make_page {title fname args} {
    debug.cm/conference {}

    set generatorcmd $args
    upvar 1 dstdir dstdir conference conference
    puts \t${title}...

    set text [make_page_header $title]

    try {
	append text \n [uplevel 1 $generatorcmd]
    } on error {e o} {
	puts "\t\t[color bad ERROR:] [color bad $e]"
	append text "\n__ERROR__\n\n" <pre>$::errorInfo</pre> \n\n
    }

    append text [make_page_footer]
    set    text [insert $conference $text]

    fileutil::writeFile $dstdir/pages/${fname}.md $text
    return [list $title "\$rootDirPath/${fname}.html"]
}

proc ::cm::conference::make_internal_page {title fname args} {
    debug.cm/conference {}

    set generatorcmd $args
    upvar 1 dstdir dstdir conference conference
    puts "\t${title}... ([color note Internal])"

    set text [make_internal_page_header $title]

    try {
	append text \n [uplevel 1 $generatorcmd]
    } on error {e o} {
	puts "\t\t[color bad ERROR:] [color bad $e]"
	append text "\n__ERROR__\n\n" <pre>$::errorInfo</pre> \n\n
    }

    append text [make_page_footer]
    set    text [insert $conference $text]

    fileutil::writeFile $dstdir/pages/${fname}.md $text
    return
}

proc ::cm::conference::make_page_header {title} {
    debug.cm/conference {}
    # page-header - TODO: Separate hotel and facilities. - header2
    # page-header - TODO: Conditional text for link, phone, and fax, any could be missing.

    lappend map @@ $title
    return [string map $map [template use www-header1]]
}

proc ::cm::conference::make_internal_page_header {title} {
    debug.cm/conference {}

    lappend map @@ $title
    return [string map $map [template use www-headeri]]
}

proc ::cm::conference::make_page_footer {} {
    debug.cm/conference {}
    return [template use www-footer]
}

proc ::cm::conference::make_internal_page_footer {} {
    debug.cm/conference {}
    return [template use www-footeri]
}

proc ::cm::conference::make_overview {} {
    debug.cm/conference {}
    return [template use www-main]
}

proc ::cm::conference::make_overview_speakers {conference} {
    debug.cm/conference {}
    return [string map \
		[list @speakers@ [speaker-listing $conference]] \
		[template use www-main-speakers]]
}

proc ::cm::conference::make_callforpapers {} {
    return [template use www-cfp]
}

proc ::cm::conference::make_location {} {
    debug.cm/conference {}
    # make-location - TODO: switch to a different text block when deadline has passed.
    return [template use www-location]
}

proc ::cm::conference::make_location_nogc {} {
    debug.cm/conference {}
    # make-location - TODO: switch to a different text block when deadline has passed.
    return [template use www-location-without-gcode]
}

proc ::cm::conference::rate-have-group-code {conference} {
    set details [details $conference]
    dict with details {}
    set location $xhotel

    set gcode [db do onecolumn {
	SELECT groupcode
	FROM   rate
	WHERE  conference = :conference
	AND    location   = :location
    }]
    return [expr {$gcode ne {}}]
}

proc ::cm::conference::registration-mode {conference} {
    debug.cm/conference {}
    return [rstatus 2name [dict get [details $conference] xrstatus]]
}

proc ::cm::conference::make_registration_pending {} {
    debug.cm/conference {}
    return [template use www-regpending]
}

proc ::cm::conference::make_registration_closed {} {
    debug.cm/conference {}
    return [template use www-regclosed]
}

proc ::cm::conference::make_registration_paper {} {
    debug.cm/conference {}
    return [template use www-regpaper]
}

proc ::cm::conference::make_registration_open {} {
    debug.cm/conference {}
    return [template use www-regopen]
}

proc ::cm::conference::make_tutorials_none {} {
    debug.cm/conference {}
    return [template use www-tutorials.none]
}

proc ::cm::conference::make_tutorials {conference} {
    debug.cm/conference {}

    set    text [template use www-tutorials]
    append text \n "# Tutorial schedule" \n\n

    lassign [tutorial dayrange   $conference] daymin   daymax   daylast
    lassign [tutorial trackrange $conference] trackmin trackmax tracklast

    set start [dict get [details $conference] xstart]

    # Table header
    # 
    # - | morning | afternoon | evening |
    # 
    append text |  ;# empty header cell, top left corner
    append sep  |- ;# empty header cell, top left corner
    db do eval {
	SELECT id   AS half,
	text AS dhalf
	FROM   dayhalf
	ORDER  BY id
    } {
	append text |[string totitle $dhalf]
	append sep |-
    }
    append text |\n $sep |\n

    # tutorial - TODO - future opt: drop empty columns from output -
    # determine which above, during header generation, and skip below,
    # during content assembly.

    # Table content.
    # One row per day and track.
    # Day only named for the first track.

    # Iterate days
    for {set day $daymin} {$day < $daymax} {incr day} {
	set date  [clock add $start $day days]
	set wday  [hwday $date]

	# Iterate tracks
	for {set track $trackmin} {$track < $trackmax} {incr track} {
	    append text |$wday

	    # Iterate day-halfs, append to current row.
	    db do eval {
		SELECT id   AS half,
		       text AS dhalf
		FROM   dayhalf
		ORDER  BY id
	    } {
		set tutorial [tutorial cell $conference $day $half $track]

		if {$tutorial eq {}} {
		    append text |
		    continue
		}

		set tdetails [tutorial get $tutorial]
		set title    [dict get $tdetails xtitle]
		set desc     [dict get $tdetails xdescription]
		set req      [dict get $tdetails xprereq]

		set speaker  [dict get $tdetails xspeaker]
		set sdetails [contact get $speaker]
		set speaker  [dict get $sdetails xdname]
		set stag     [dict get $sdetails xtag]
		set tag      ${stag}:[dict get $tdetails xtag]

		append text | [link $title {} $tag]

		# Keep information to make assembly of the next
		# section easier, no need to query the databse again.
		dict set map $tutorial [list $title $tag $speaker $stag $desc $req]
	    }	    
	    append text |\n ;# close row of current track
	    set wday ""     ;# clear prefix following tracks
	}
    }
    append text \n\n

    append text "# Tutorial Information" \n\n

    db do eval {
	SELECT tutorial
	FROM   tutorial_schedule S,
	       tutorial          T,
	       contact           C
	WHERE  S.conference = :conference
	AND    T.id         = S.tutorial
	AND    C.id         = T.speaker
	ORDER BY C.dname, T.title
    } {
	lassign [dict get $map $tutorial] title tag speaker stag desc req

	# Anchor for table above to link to
	append text [anchor $tag] \n

	# Section header for tutorial, title and speaker link
	append text "\#\# " $title " &mdash; " [link $speaker bios.html $stag] \n\n

	# Requirements, if any.
	if {$req ne {}} {
	    append text "__Required__: " $req \n\n
	}

	# Block holding the tutorial's description.
	append text $desc \n\n
    }
    #append text </table>

    return $text
}

proc ::cm::conference::make_schedule {} {
    # make-schedule - TODO: Move text into a configurable template
    # make-schedule - TODO: data driven on schedule data

    return [util undent {
	The schedule will be finalized and put up after
	all the notifications to authors have been sent
	out on @c:t:authornote@.

	Please check back after.
    }]
}

proc ::cm::conference::make_abstracts_none {} {
    debug.cm/conference {}
    return [template use www-abstracts.none]
}

proc ::cm::conference::make_abstracts {conference} {
    debug.cm/conference {}

    set text [template use www-abstracts]

    # per talk: title, speakers, abstract ...
    # keynotes first, then general presentations...

    foreach {talk title abstract} [keynote-abstracts $conference] {
	if {[string trim $abstract] eq {}} {
	    set abstract "__Missing abstract__"
	}
	set speakers [join [link-speakers [talk-speakers $talk]] {, }]
	append text [anchor T$talk] \n
	append text "\#\# Keynote &mdash; $title\n\n$speakers\n\n$abstract\n\n"
    }

    foreach {talk title abstract} [general-abstracts $conference] {
	if {[string trim $abstract] eq {}} {
	    set abstract "__Missing abstract__" 
	}
	set speakers [join [link-speakers [talk-speakers $talk]] {, }]
	append text [anchor T$talk] \n
	append text "\#\# $title\n\n$speakers\n\n$abstract\n\n"
    }
    return $text
}

proc ::cm::conference::link-speakers {speakers} {
    set r {}
    foreach {dname tag} $speakers {
	lappend r [link $dname bios.html $tag]
    }
    return $r
}

proc ::cm::conference::cmd_debug_speakers {config} {
    debug.cm/conference {}
    Setup
    db show-location

    if {[$config @mail]} {
	puts [mail-speaker-listing [current]]
    } else {
	puts [speaker-listing [current]]
    }
    return
}

proc ::cm::conference::keynotes {conference} {
    debug.cm/conference {}

    return [db do eval {
	SELECT C.dname     AS dname
	,      C.tag       AS tag
	,      C.biography AS biography
	FROM contact    C  -- (id)
	,    talker     TR -- (id, talk, contact)
	,    talk_type  TT -- (id, text)
	,    talk       T  -- (id, submission, type)
	,    submission S  -- (id, conference)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   TR.talk      = T.id
	AND   TR.contact   = C.id
	AND   T.type       = TT.id
	AND   TT.text      = 'keynote'
	ORDER BY dname
    }]
}

proc ::cm::conference::general-talks {conference} {
    debug.cm/conference {}

    return [db do eval {
	SELECT C.dname     AS dname
	,      C.tag       AS tag
	,      C.biography AS biography
	FROM contact    C  -- (id)
	,    talker     TR -- (id, talk, contact)
	,    talk_type  TT -- (id, text)
	,    talk       T  -- (id, submission, type)
	,    submission S  -- (id, conference)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   TR.talk      = T.id
	AND   TR.contact   = C.id
	AND   T.type       = TT.id
	AND   TT.text     != 'keynote'
	ORDER BY dname
    }]
}

proc ::cm::conference::talk-speakers {talk} {
    return [db do eval {
	SELECT dname, tag
	FROM   contact
	WHERE  id IN (SELECT contact
		      FROM   talker
		      WHERE  talk = :talk)
	ORDER BY dname
    }]
}

proc ::cm::conference::keynote-abstracts {conference} {
    debug.cm/conference {}

    return [db do eval {
	SELECT T.id       AS id
	,      S.title    AS title
	,      S.abstract AS abstract
	FROM talk_type  TT -- (id, text)
	,    talk       T  -- (id, submission, type)
	,    submission S  -- (id, conference)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   T.type       = TT.id
	AND   TT.text      = 'keynote'
	ORDER BY title
    }]
}

proc ::cm::conference::general-abstracts {conference} {
    debug.cm/conference {}

    return [db do eval {
	SELECT T.id       AS id
	,      S.title    AS title
	,      S.abstract AS abstract
	FROM talk_type  TT -- (id, text)
	,    talk       T  -- (id, submission, type)
	,    submission S  -- (id, conference)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   T.type       = TT.id
	AND   TT.text     != 'keynote'
	ORDER BY title
    }]
}

proc ::cm::conference::tutorials-of {conference speakertag} {
    debug.cm/conference {}

    return [db do eval {
	SELECT T.tag
	,      T.title
	FROM tutorial          T
	,    tutorial_schedule TS
	,    contact           C
	WHERE TS.conference = :conference
	AND   TS.tutorial   = T.id
	AND   T.speaker     = C.id
	AND   C.tag         = :speakertag
	ORDER BY T.title
    }]
}

proc ::cm::conference::keynotes-of {conference speakertag} {
    debug.cm/conference {}

    return [db do eval {
	SELECT T.id       AS id
	,      S.title    AS title
	FROM talk_type  TT -- (id, text)
	,    talk       T  -- (id, submission, type)
	,    talker     TR -- (id, talk, contact)
	,    submission S  -- (id, conference)
	,    contact    C  -- (id, tag)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   T.type       = TT.id
	AND   TT.text      = 'keynote'
	AND   TR.talk      = T.id
	AND   TR.contact   = C.id
	AND   C.tag        = :speakertag
	ORDER BY title
    }]
}

proc ::cm::conference::talks-of {conference speakertag} {
    debug.cm/conference {}

    return [db do eval {
	SELECT T.id       AS id
	,      S.title    AS title
	FROM talk_type  TT -- (id, text)
	,    talk       T  -- (id, submission, type)
	,    talker     TR -- (id, talk, contact)
	,    submission S  -- (id, conference)
	,    contact    C  -- (id, tag)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   T.type       = TT.id
	AND   TT.text     != 'keynote'
	AND   TR.talk      = T.id
	AND   TR.contact   = C.id
	AND   C.tag        = :speakertag
	ORDER BY title
    }]
}

proc ::cm::conference::the-speakers {conference} {
    debug.cm/conference {}
    set map {}
    foreach {dname tag bio} [keynotes $conference] {
	dict set map $dname $tag
    }
    foreach {dname tag bio} [tutorial speakers* $conference] {
	dict set map $dname $tag
    }
    foreach {dname tag bio} [general-talks $conference] {
	dict set map $dname $tag
    }

    dict unset map [dict get [contact get [dict get [details $conference] xmanagement]] xdname]
    return $map
}

proc ::cm::conference::the-presenters {conference} {
    debug.cm/conference {}
    set map {}
    foreach {dname tag bio} [keynotes $conference] {
	dict set map $dname $tag
    }
    foreach {dname tag bio} [general-talks $conference] {
	dict set map $dname $tag
    }

    dict unset map [dict get [contact get [dict get [details $conference] xmanagement]] xdname]
    return $map
}

proc ::cm::conference::speaker-listing {conference} {
    debug.cm/conference {}
    # speaker-listing - TODO - general presenters

    set mgmt [dict get [contact get [dict get [details $conference] xmanagement]] xdname]

    # Keynotes...
    set first 1
    foreach {dname tag bio} [keynotes $conference] {
	if {$dname eq $mgmt} continue
	if {$first} {
	    append text "## Keynotes\n\n"
	    set first 0
	}

	# Data is ordered by dname
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for keynote speaker '$dname'"] }
	append text [fmt-speakers $dname $tag [keynotes-of $conference $tag] T abstracts.html]
    }
    if {!$first} { append text \n }

    # Tutorials...
    set first 1
    foreach {dname tag bio} [tutorial speakers* $conference] {
	if {$dname eq $mgmt} continue
	if {$first} {
	    append text "## Tutorials\n\n"
	    set first 0
	}
	# Data is ordered by dname
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for tutorial speaker '$dname'"] }
	append text [fmt-speakers $dname $tag [tutorials-of $conference $tag] ${tag}: tutorials.html]
    }
    if {!$first} { append text \n }

    # Presenters...
    set first 1
    foreach {dname tag bio} [general-talks $conference] {
	if {$dname eq $mgmt} continue
	if {$first} {
	    append text "## Presentations\n\n"
	    set first 0
	}

	# Data is ordered by dname
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for general speaker '$dname'"] }
	append text [fmt-speakers $dname $tag [talks-of $conference $tag] T abstracts.html]
    }
    if {!$first} { append text \n }

    return $text
}

proc ::cm::conference::mail-speaker-listing {conference} {
    debug.cm/conference {}
    # speaker-listing - TODO - general presenters

    set mgmt [dict get [contact get [dict get [details $conference] xmanagement]] xdname]

    append text "\[\[ Known Speakers\n"

    # Keynotes...
    set first 1
    foreach {dname tag bio} [keynotes $conference] {
	if {$dname eq $mgmt} continue
	if {$first} {
	    append text "-- Keynotes\n\n"
	    set first 0
	}

	# Data is ordered by dname
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for keynote speaker '$dname'"] }
	append text [fmt-mail-speakers $dname $tag [keynotes-of $conference $tag] T abstracts.html]
    }
    #if {!$first} { append text \n }

    # Tutorials...
    set first 1
    foreach {dname tag bio} [tutorial speakers* $conference] {
	if {$dname eq $mgmt} continue
	if {$first} {
	    append text "-- Tutorials\n\n"
	    set first 0
	}
	# Data is ordered by dname
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for tutorial speaker '$dname'"] }
	append text [fmt-mail-speakers $dname $tag [tutorials-of $conference $tag] ${tag}: tutorials.html]
    }
    #if {!$first} { append text \n }

    # Presenters...
    set first 1
    foreach {dname tag bio} [general-talks $conference] {
	if {$dname eq $mgmt} continue
	if {$first} {
	    append text "-- Presentations\n\n"
	    set first 0
	}

	# Data is ordered by dname
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for general speaker '$dname'"] }
	append text [fmt-mail-speakers $dname $tag [talks-of $conference $tag] T abstracts.html]
    }
    #if {!$first} { append text \n }

    append text \]\]\n
    return $text
}

proc ::cm::conference::fmt-speakers {dname tag talks tpfx tlink} {
    # talks = (tag title...)

    append text "  * "
    append text [link $dname bios.html $tag]

    if {[llength $talks]} {
	append text " &mdash;"
	set pre " ("
	foreach {ttag title} $talks {
	    append text $pre [link $title $tlink $tpfx$ttag]
	    set pre ", "
	}
	append text ")"
    }
    append text \n
    return $text
}

proc ::cm::conference::fmt-mail-speakers {dname tag talks tpfx tlink} {
    # talks = (tag title...)

    append text "  * "

    set blank [string repeat { } [string length $dname]]

    if {[llength $talks]} {
	set pre "$dname - "
	foreach {ttag title} $talks {
	    set title [string map {&mdash; ---} $title]
	    append text $pre $title \n
	    set pre "    $blank   "
	}
	append text \n
    } else {
	append text $dname \n
    }
    return $text
}

proc ::cm::conference::have-speakers {conference} {
    debug.cm/conference {}
    # have-speakers: tutorials or any talks (keynotes, general)
    return [expr {[llength [tutorial speakers $conference]] || [db do exists {
	SELECT TR.contact
	FROM talker     TR -- (id, talk, contact)
	,    talk       T  -- (id, submission, type)
	,    submission S  -- (id, conference)
	WHERE S.conference = :conference
	AND   S.id         = T.submission
	AND   TR.talk      = T.id
    }]}]
}

proc ::cm::conference::make_speakers_none {} {
    debug.cm/conference {}
    return [template use www-speakers.none]
}

proc ::cm::conference::make_speakers {conference} {
    debug.cm/conference {}
    # bio page for
    # - tutorials speakers,
    # - keynote speakers,
    # - general presenters.

    set text [template use www-speakers]

    set map  {} ; # name -> (tag, bio)
    set type {} ; # name -> list(types), type in T, K, P

    foreach {dname tag bio} [tutorial speakers* $conference] {
	if {$bio eq {}} { set bio "__No biography known__" }
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for speaker '$dname'"] }
	dict set     map  $dname [list $tag $bio]
	dict lappend type $dname T
    }
    foreach {dname tag bio} [keynotes $conference] {
	if {$bio eq {}} { set bio "__No biography known__" }
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for speaker '$dname'"] }
	dict set     map  $dname [list $tag $bio]
	dict lappend type $dname K
    }
    foreach {dname tag bio} [general-talks $conference] {
	if {$bio eq {}} { set bio "__No biography known__" }
	if {$tag eq {}} { puts \t\t[color bad "Tag missing for speaker '$dname'"] }
	dict set     map  $dname [list $tag $bio]
	dict lappend type $dname P
    }

    # Generate the page contents from the collected information.
    foreach dname [lsort -dict [dict keys $map]] {
	lassign [dict get $map $dname] tag bio

	set types [join [lsort -dict [string map \
					  {T Tutorial K Keynote P Presenter} \
					  [dict get $type $dname]]] {, }]

	append text [anchor $tag] \n
	append text "## " $dname " &mdash; " $types \n\n
	append text $bio \n\n
    }

    return $text
}

proc ::cm::conference::make_contact {} {
    debug.cm/conference {}
    # No content, the information is in the footer.
    return
}

proc ::cm::conference::make_disclaimer {} {
    debug.cm/conference {}
    # make-abstracts - TODO: Move text into a configurable template
    return [util undent {
	This is the disclaimer and copyright.
    }]
}

proc ::cm::conference::make_proceedings {} {
    debug.cm/conference {}
    # make-proceedings - TODO: Move text into a configurable template
    # make-proceedings - TODO: flag/data controlled
    return [util undent {
	Our proceedings will be made public next year,
	as part of the next conference.

	Please check back.
    }]
}

proc ::cm::conference::make_admin {conference} {
    debug.cm/conference {}
    upvar 1 dstdir dstdir

    set issues [issues [details $conference]]

    if {[llength $issues]} {
	append text "* " [link Issues      {} issues] \n
    }

    append text "* " [link Registered   {} registered] \n
    append text "* " [link Booked       {} booked] \n
    append text "* " [link Accepted    {} accepted] \n
    append text "* " [link Submissions {} submissions] \n
    append text "* " [link Campaign    {} campaign] \n
    append text "* " [link Events      {} events] \n
    append text \n

    if {[llength $issues]} {
	append text \n
	append text [anchor issues] \n
	append text "# Issues\n\n"
	append text [util fmt-issues-web $issues]
	append text \n
    }

    make_admin_registered  $conference text registered
    make_admin_booked      $conference text booked
    make_admin_accepted    $conference text accepted
    make_admin_submissions $conference text submissions
    make_admin_campaign    $conference text campaign
    make_admin_timeline    $conference text events

    # What else ...

    debug.cm/conference {/done}
    return $text
}

proc ::cm::conference::make_admin_registered {conference textvar tag} {
    debug.cm/conference {}
    upvar 1 $textvar text
    # People booked to a hotel

    append text \n
    append text [anchor $tag] \n
    append text "# Registered\n\n"

    set first 1
    foreach {dname walkin ta tb tc td} [registered listing $conference] {
	if {$first} {
	    append text |Who|Walkin|1-Morning|1-Afternoon|2-Morning|2-Afternoon|\n|-|-|-|-|-|-|\n
	    set first 0
	}
	append text | $dname | $walkin | $ta | $tb | $tc | $td |\n
    }

    if {$first} {
	append text "__No registrations__"
    }

    append text \n
    return
}

proc ::cm::conference::make_admin_booked {conference textvar tag} {
    debug.cm/conference {}
    upvar 1 $textvar text
    # People booked to a hotel

    append text \n
    append text [anchor $tag] \n
    append text "# Booked\n\n"

    set first 1
    foreach {dname _ locname _ _ cityname state nation} [booked listing $conference] {
	if {$first} {
	    append text |Who|Hotel|City|\n|-|-|-|\n
	    set first 0
	}
	append text | $dname | $locname | [city label $cityname $state $nation] |\n
    }

    if {$first} {
	append text "__No bookings__"
    }

    append text \n
    return
}

proc ::cm::conference::make_admin_timeline {conference textvar tag} {
    debug.cm/conference {}
    upvar 1 $textvar textresult
    # Full timeline, including the non-public events.

    set now [clock seconds]
    set pastnow 0

    append textresult \n
    append textresult [anchor $tag] \n
    append textresult "# Events\n\n"

    set sql [TimelineSQL $conference]

    set first 1
    db do eval $sql {
	if {$first} {
	    append textresult |Done|What|When|\n|-|-|-|\n
	    set first 0
	}

	if {!$pastnow && ($date > $now)} {
	    set pastnow yes
	    append textresult ||||\n||__Today__| [hdate $now] |\n||||\n
	}

	set date [hdate $date]
	set done [expr {$done
			? "&check;"
			: ""}]

	if {$ispublic} {
	    set date __${date}__
	    set text __${text}__
	}

	append textresult | $done | $date | $text |\n
    }

    if {$first} {
	append textresult "__No events defined__"
    }

    append textresult \n

    debug.cm/conference {/done}
    return
}

proc ::cm::conference::make_admin_campaign {conference textvar tag} {
    package require cm::campaign

    debug.cm/conference {}
    upvar 1 $textvar text
    # Status of the email campaign (see 'campaign status')

    append text \n
    append text [anchor $tag] \n
    append text "# Campaign Status\n\n"

    set campaign [cm campaign for-conference $conference]
    if {$campaign eq {}} {
	append text "__Conference \"$clabel\" has no campaign__"
	return
    }

    set destinations [cm campaign destinations $campaign]

    set first 1
    foreach {mailrun date name} [cm campaign runs $campaign] {
	if {$first} {
	    append text |When|Template|Reached|Unreached|\n|-|-|-|-|\n
	    set first 0
	}
	set date [clock format $date -format {%Y-%m-%d %H:%M:%S}]

	set reached [cm campaign run-reach $mailrun]
	set unreached [struct::set difference $destinations $reached]
	set unreached [llength $unreached]
	set reached   [llength $reached]

	if {$unreached} {
	    set unreached __${unreached}__
	}

	append text | $date | $name | $reached | $unreached |\n
    }

    if {$first} {
	append text "Campaign has not been run yet" \n
    }

    append text \n
    return
}

proc ::cm::conference::make_admin_accepted {conference textvar tag} {
    debug.cm/conference {}
    upvar 1 dstdir dstdir $textvar text

    # Table of accepted submissions aka talks, plus one side page per to
    # hold the larger associated texts.

    append text \n
    append text [anchor $tag] \n
    append text "# Accepted Talks\n\n"

    set first 1
    db do eval {
	SELECT S.id         AS id,
	       S.submitdate AS submitdate,
	       S.invited    AS invited,
	       S.abstract   AS abstract,
	       S.summary    AS summary,
	       S.title      AS title
	FROM   submission S
	WHERE  conference = :conference
	AND    0 < (SELECT count (T.id)
		    FROM   talk T
		    WHERE  T.submission = S.id)
	ORDER BY submitdate, id
    } {
	if {$first} {
	    append text |When||Invited|By|Title|\n|-|-|-|-|-|\n
	    set first 0
	}

	set submitters [db do eval {
	    SELECT C.dname, S.note
	    FROM   submitter S,
	           contact   C
	    WHERE  S.submission = :id
	    AND    C.id = S.contact
	    ORDER BY C.dname
	}]

	# Side page per submission, holding the entire data.
	make_internal_page $title __s$id \
	    make_submission $id $submitters $submitdate $invited $abstract $summary

	set invited    [expr {$invited ? "__yes__" : ""}]
	set submitters [join [dict keys $submitters] {, }]

	set issue {}
	if {([string trim $abstract] eq {}) &&
	    ([string trim $summary] eq {})} {
	    set issue "__Missing abstract/summary__"
	}

	append text | [hdate $submitdate] | $issue | $invited | $submitters | [link $title __s${id}.html] |\n
    }

    if {$first} {
	append text "No accepted talks" \n
    }

    append text \n
    return
}

proc ::cm::conference::make_admin_submissions {conference textvar tag} {
    debug.cm/conference {}
    upvar 1 dstdir dstdir $textvar text

    # Table of submissions received so far, plus one side page per to
    # hold the larger associated texts.

    append text \n
    append text [anchor $tag] \n
    append text "# Submissions\n\n"

    set first 1
    db do eval {
	SELECT S.id         AS id,
	       S.submitdate AS submitdate,
	       S.invited    AS invited,
	       S.abstract   AS abstract,
	       S.summary    AS summary,
	       S.title      AS title
	FROM   submission S
	WHERE  conference = :conference
	AND    0 = (SELECT count (T.id)
		    FROM   talk T
		    WHERE  T.submission = S.id)
	ORDER BY submitdate, id
    } {
	if {$first} {
	    append text |When||Invited|By|Title|\n|-|-|-|-|-|\n
	    set first 0
	}

	set submitters [db do eval {
	    SELECT C.dname, S.note
	    FROM   submitter S,
	           contact   C
	    WHERE  S.submission = :id
	    AND    C.id = S.contact
	    ORDER BY C.dname
	}]

	# Side page per submission, holding the entire data.
	make_internal_page $title __s$id \
	    make_submission $id $submitters $submitdate $invited $abstract $summary

	set invited    [expr {$invited ? "__yes__" : ""}]
	set submitters [join [dict keys $submitters] {, }]

	set issue {}
	if {([string trim $abstract] eq {}) &&
	    ([string trim $summary] eq {})} {
	    set issue "__Missing abstract/summary__"
	}

	append text | [hdate $submitdate] | $issue | $invited | $submitters | [link $title __s${id}.html] |\n
    }

    if {$first} {
	append text "No submissions yet" \n
    }

    append text \n
    return
}

proc ::cm::conference::make_submission {submission submitters date invited abstract summary} {
    debug.cm/conference {}
    upvar 1 dstdir dstdir

    append text "\# Submitted\n\n"
    if {$invited} { set invited " (by invitation)" } else { set invited {} }

    set talk [db do onecolumn {
	SELECT id
	FROM   talk
	WHERE  submission = :submission
    }]

    append text |||\n|-|-|\n
    append text |On| [hdate $date] $invited |\n
    set prefix By
    foreach {name note} $submitters {
	append text | $prefix | $name
	if {$note ne {}} {
	    append text " &mdash; " $note
	}
	append text |\n
	set prefix {}
    }

    if {$talk ne {}} {
	append text |__Accepted__||\n

	set speakers [db do eval {
	    SELECT C.dname
	    FROM   talker  T,
	           contact C
	    WHERE  T.talk = :talk
	    AND    C.id   = T.contact
	    ORDER BY C.dname
	}]

	set prefix Speaker
	foreach name $speakers {
	    append text | $prefix | $name |\n
	    set prefix {}
	}

	set attachments [db do eval {
	    SELECT id, type
	    FROM   attachment
	    WHERE  talk = :talk
	    ORDER BY type
	}]
	set prefix Attachment
	foreach {aid title} $attachments {
	    file mkdir $dstdir/static/asset

	    # TODO: some way of getting the mime-type associated to the asset-file ?

	    set in  [db do incrblob -readonly attachment data $aid]
	    set out [open $dstdir/static/asset/attachment$aid w]

	    fconfigure $in  -encoding binary -translation binary
	    fconfigure $out -encoding binary -translation binary
	    fcopy $in $out

	    close $in
	    close $out

	    append text | $prefix | [link $title asset/attachment$aid] |\n
	    set prefix {}
	}
    }
    append text \n

    if {[string trim $abstract] eq {}} { set abstract "__No abstract__" }
    if {[string trim $summary]  eq {}} { set summary  "__No summary__"  }

    append text "\# Abstract\n\n"
    append text $abstract
    append text \n

    append text "\# Summary\n\n"
    append text $summary
    append text \n

    return $text
}

proc ::cm::conference::make_sidebar {conference} {
    debug.cm/conference {}

    append sidebar <table>
    # -- styling makes the table too large -- append sidebar "<table class='table table-condensed'>"
    append sidebar "\n<tr><th colspan=2>" "Important Information &mdash; Timeline" </th></tr>
    #append sidebar <tr><td> "Email contact" </td><td> "<a href='mailto:@c:contact@'>" @c:contact@</a></td></tr>

    append sidebar [[table t {Event When} {
	$t style cmdr/table/html
	$t noheader

	switch -exact -- [set m [registration-mode $conference]] {
	    pending {
		set sql [sidebar_reg_show $conference]
	    }
	    open - closed {
		set r Registration
		if {$m eq "open"} { set r "<a href='register.html'>$r</a>" }
		append sidebar "\n<tr><th colspan=2>" "Registration is $m" </th></tr>
		set sql [sidebar_reg_excluded $conference]
	    }
	}
	#append sidebar "\n<tr><td colspan=2><hr/></strong></td></tr>"
	db do eval $sql {
	    set text [string map {{Public Room} {Hotel Room}} $text]

	    $t add "$text" [hdate $date]
	}
    }] show return]
    append sidebar </table>
    return [insert $conference $sidebar]
}

proc ::cm::conference::link {name page {tag {}}} {
    debug.cm/conference {}
    append link \[ $name \]( $page
    if {$tag ne {}} { append link \# $tag }
    append link )
    return $link
}

proc ::cm::conference::anchor {key} {
    debug.cm/conference {}
    return "<a name='$key'></a>"
}

proc ::cm::conference::sidebar_reg_excluded {conference} {
    debug.cm/conference {}

    lappend mapa \
	{AND   T.type = E.id} \
	{AND   T.type = E.id AND E.key != 'regopen'}
    lappend mapb @@@ [string map $mapa [TimelineSQL $conference]]

    return [string map $mapb {
	SELECT date, text
	FROM (@@@)
	WHERE ispublic
    }]
}

proc ::cm::conference::sidebar_reg_show {conference} {
    debug.cm/conference {}

    lappend map @@@ [TimelineSQL $conference]
    return [string map $map {
	SELECT date, text
	FROM (@@@)
	WHERE ispublic
    }]
}

proc ::cm::conference::have-talks {conference} {
    debug.cm/conference {}
    Setup

    return [db do exists {
	SELECT T.id
	FROM   talk T, submission S
	WHERE  S.conference = :conference
	AND    T.submission = S.id
    }]
}

proc ::cm::conference::cdefault {attr dcmd} {
    upvar 1 config config
    if {[$config $attr set?]} { return [$config $attr] }
    return [uplevel 1 $dcmd]
}


proc ::cm::conference::timeline-clear {conference} {
    debug.cm/conference {}
    Setup
    # clear the timeline ...

    db do eval {
	DELETE
	FROM  timeline
	WHERE con = :conference
    }
    return
}

proc ::cm::conference::timeline-init {conference} {
    debug.cm/conference {}
    Setup
    # Compute an initial timeline based on the conference start date.

    set details [details $conference]
    dict with details {}

    puts "Proposed timeline ..."
    [table t {Item Date} {
	db do eval {
	    SELECT id, offset, text, ispublic
	    FROM timeline_type
	    ORDER BY offset
	} {
	    set new [clock add $xstart $offset days]

	    if {$ispublic} {
		$t add [color note $text] [color note [hdate $new]]
	    } else {
		$t add $text [hdate $new]
	    }
	    db do eval {
		INSERT INTO timeline
		VALUES (NULL, :conference, :new, :id, 0)
	    }
	}
    }] show
    return
}

proc ::cm::conference::insert {id text} {
    debug.cm/conference {}
    Setup

    set details [details $id]

    # Basic conference information

    set xstart [dict get $details xstart]
    set xend   [dict get $details xend]
    set xmgmt  [dict get $details xmanagement]

    +map @c:name@            [get $id]
    +map @c:year@            [dict get $details xyear]
    +map @c:contact@         [contact 2name-email [dict get $details xsubmission]]
    +map @c:management@      [contact 2name-plain $xmgmt]
    +map @c:management:link@ [contact the-link $xmgmt]
    +map @c:start@           [hdate $xstart]
    +map @c:end@             [hdate $xend]
    +map @c:when@            [when $xstart $xend]
    +map @c:talklength@      [dict get $details xtalklen]
    # NOTE: xsesslen == 'talks per session' ignored - not relevant in any page, so far.

    # City information

    +map @c:city@ [city 2name [dict get $details xcity]]

    # Hotel information, if available.
    # insert - TODO: Facility information, and hotel != facility.

    set xhotel [dict get $details xhotel]
    if {$xhotel ne {}} {
	set hdetails [location get $xhotel]

	set xlocalphone [dict get $hdetails xlocalphone]
	set xlocalfax   [dict get $hdetails xlocalfax]
	set xlocallink  [dict get $hdetails xlocallink]
	set xbookphone  [dict get $hdetails xbookphone]
	set xbookfax    [dict get $hdetails xbookfax]
	set xbooklink   [dict get $hdetails xbooklink]
	set xhname      [dict get $hdetails xname]
	set xhstreet    [dict get $hdetails xstreet]
	set xhzipcode   [dict get $hdetails xzipcode]
	set xhtransport [dict get $hdetails xtransport]
	set xhcity      [city 2name [dict get $hdetails xcity]]
    } else {
	set xlocalphone __Missing__
	set xlocalfax   __Missing__
	set xlocallink  __Missing__
	set xbookphone  __Missing__
	set xbookfax    __Missing__
	set xbooklink   __Missing__
	set xhname      __Missing__
	set xhstreet    __Missing__
	set xhzipcode   __Missing__
	set xhtransport __Missing__
	set xhcity      __Missing__
    }

    +map @h:hotel@      $xhname
    +map @h:city@       $xhcity
    +map @h:street@     "$xhstreet, $xhzipcode"
    +map @h:transport@  $xhtransport
    +map @h:bookphone@  [ifempty $xbookphone $xlocalphone]
    +map @h:bookfax@    [ifempty $xbookfax   $xlocalfax]
    +map @h:booklink@   [ifempty $xbooklink  $xlocallink]
    +map @h:localphone@ $xlocalphone
    +map @h:localfax@   $xlocalfax
    +map @h:locallink@  $xlocallink

    # Room rate information, if available

    if {$xhotel ne {}} {
	set rdetails [get-rate $id $xhotel]
	if {![dict size $rdetails]} {
	    set rdetails {
		rate      __Missing__
		currency  __Missing__
		begin     __Missing__
		end       __Missing__
		pdeadline __Missing__
		group     __Missing__
	    }
	}
    } else {
	set rdetails {
	    rate      __Missing__
	    currency  __Missing__
	    begin     __Missing__
	    end       __Missing__
	    pdeadline __Missing__
	    group     __Missing__
	}
    }

    +map @r:rate@     [dict get $rdetails rate]
    +map @r:currency@ [dict get $rdetails currency]
    +map @r:begin@    [dict get $rdetails begin]
    +map @r:end@      [dict get $rdetails end]
    +map @r:deadline@ [dict get $rdetails pdeadline]
    +map @r:group@    [dict get $rdetails group]

    # Conference timeline (only public events)

    db do eval {
	SELECT E.key  AS key,
	       T.date AS date
	FROM   timeline      T,
	       timeline_type E
	WHERE  T.type = E.id
	AND    T.con = :id
	AND    E.ispublic
    } {
	+map @c:t:${key}@ [hdate $date]
    }

    # Program committee ...
    # Subset of conference staff ...
    # Multiple variants, for mail and website.

    +map @c:committee@    [mail-committee $id]
    +map @c:committee:md@ [web-committee  $id]

    # Sponsors ...
    # Multiple variants...
    # - mail, website (bullet list, inline list)
    # - mail contains can contain management as sponsor.
    # - web excludes manager from list, see above for separate keys.

    +map @c:sponsors@          [mail-sponsors $id]
    +map @c:sponsors:md@       [web-sponsors-bullet $id $xmgmt]
    +map @c:sponsors:md:short@ [web-sponsors-inline $id $xmgmt]

    if {[have-speakers $id]} {
	+map @c:speakers@ [mail-speaker-listing $id]
    } else {
	+map @c:speakers@ {}
    }

    # Execute the accumulated substitutions

    set text [string map $map $text]
    return $text
}

proc ::cm::conference::web-sponsors-inline {id mgmt} {
    debug.cm/conference {}
    Setup

    set sponsors {}
    dict for {label sponsor} [known-sponsor-select $id] {
	# Exclude managing org from the enumeration
	if {$sponsor == $mgmt} continue

	set link [contact the-link $sponsor]
	if {$link ne {}} {
	    set label [link $label $link]
	}
	lappend sponsors $label
    }

    if {[llength $sponsors] > 1} {
	set sponsors [string map {and, and} [join [linsert $sponsors end-1 and] {, }]]
    } else {
	set sponsors [join $sponsors {}]
    }

    return $sponsors
}

proc ::cm::conference::web-sponsors-bullet {id mgmt} {
    debug.cm/conference {}
    Setup

    set sponsors {}
    dict for {label sponsor} [known-sponsor-select $id] {
	# Exclude managing org from the enumeration
	if {$sponsor == $mgmt} continue

	set link [contact the-link $sponsor]
	if {$link ne {}} {
	    set label [link $label $link]
	}
	lappend sponsors $label
    }

    return [util indent [join [lsort -dict $sponsors] \n] \
		"   * "]
}

proc ::cm::conference::mail-sponsors {id} {
    debug.cm/conference {}
    Setup

    set sponsors [known-sponsor-select $id]
    set sponsors [lsort -dict [dict keys $sponsors]]
    set sponsors [join $sponsors \n]

    return [util indent $sponsors "   * "]
}

proc ::cm::conference::web-committee {id} {
    debug.cm/conference {}
    Setup

    set cdata  [committee $id]
    set cnames [lsort -dict [dict keys $cdata]]

    set mdcommittee {}
    foreach cname $cnames {
	# Get full details of person, and pull affiliations, if any.
	# Get link for affiliation, if any.
	set contact     [dict get $cdata $cname]
	set affiliation {}
	foreach {aid aname} [contact affiliations $contact] {
	    set alink [contact the-link $aid]
	    if {$alink ne {}} {
		set aname [link $aname $alink]
	    }
	    lappend affiliation $aname
	}
	set affiliation [join $affiliation {, }]

	lappend mdcommittee |$cname|$affiliation|
    }

    return |||\n|-|-|\n[join $mdcommittee \n]
}

proc ::cm::conference::mail-committee {id} {
    debug.cm/conference {}
    Setup

    set cdata  [committee $id]
    # name -> id(contact)

    set cnames [lsort -dict [dict keys $cdata]]
    # Need mainly the names.

    set committee {}
    foreach c $cnames clabel [util padr $cnames] {
	# Iterating over names instead of dict to have proper padded
	# names for proper tabular alignment in the generated text.

	# Get full details, and pull the affiliation, if any.

	set contact     [dict get $cdata $c]
	set affiliation {}
	set prefix      "   * "

	foreach {aid aname} [contact affiliations $contact] {
	    lappend affiliation $aname
	}

	if {![llength $affiliation]} {
	    lappend committee $prefix[string trim $clabel]
	} else {
	    foreach a $affiliation {
		lappend committee "$prefix$clabel $a"
		set prefix "     "
		regsub -all {[^	]} $clabel { } clabel
	    }
	}
    }

    return [join $committee \n]
}

proc ::cm::conference::+map {key value} {
    debug.cm/conference {}
    upvar 1 map map
    lappend map $key $value
    return
}

proc ::cm::conference::hbool {x} {
    expr {$x ? "yes" : "no"}
}

proc ::cm::conference::ifempty {x y} {
    if {$x ne {}} { return $x }
    return $y
}

proc ::cm::conference::hdate {x} {
    clock format $x -format {%B %d, %Y}
}

proc ::cm::conference::isodate {x} {
    clock format $x -format %Y-%m-%d
}

proc ::cm::conference::hmday {x} {
    clock format $x -format {%B %d}
}

proc ::cm::conference::hwday {x} {
    clock format $x -format {%A}
}

proc ::cm::conference::hmon {x} {
    clock format $x -format %B
}

proc ::cm::conference::hyear {x} {
    clock format $x -format %Y
}

proc ::cm::conference::when {s e} {
    lassign [clock format $s -format {%Y %m %d}] sy sm sd
    lassign [clock format $e -format {%Y %m %d}] ey em ed

    if {$sy != $ey} {
	# Across years, show full dates
	return "[hdate $s] - [hdate $e]"
    }

    # Same year.
    if {$sm != $em} {
	# Across months
	return "[hmday $s] - [hmday $e], $sy"

    }

    # Same year, same month.
    return "[hmon $s] $sd - $ed, $sy"
}

proc ::cm::conference::known-sponsor {} {
    debug.cm/conference {}
    Setup

    set conference [the-current]
    if {$conference < 0} {
	return {}
    }

    set sponsors [db do eval {
	SELECT contact
	FROM   sponsors
	WHERE  conference = :conference
    }]
    if {![llength $sponsors]} {
	return {}
    }

    return [cm::contact::KnownLimited $sponsors]
}

proc ::cm::conference::known-speaker {p} {
    debug.cm/conference {}
    Setup

    set submission [$p config @submission]

    set talkers [db do eval {
	SELECT contact
	FROM   talker
	WHERE  talk IN (SELECT id
			FROM   talk
			WHERE  submission = :submission)
    }]
    if {![llength $talkers]} {
	return {}
    }

    return [cm::contact::KnownLimited $talkers]
}

proc ::cm::conference::known-submitter {p} {
    debug.cm/conference {}
    Setup

    set submission [$p config @submission]

    set submitters [db do eval {
	SELECT contact
	FROM   submitter
	WHERE  submission = :submission
    }]
    if {![llength $submitters]} {
	return {}
    }

    return [cm::contact::KnownLimited $submitters]
}

proc ::cm::conference::get-attachment {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT type
	FROM   attachment
	WHERE   id = :id
    }]
}

proc ::cm::conference::known-attachment {p} {
    debug.cm/conference {}
    Setup

    set submission [$p config @submission]

    return [db do eval {
	SELECT type, id
	FROM   attachment
	WHERE  talk IN (SELECT id
			FROM   talk
			WHERE  submission = :submission)
    }]
}

proc ::cm::conference::known-sponsor-select {conference} {
    debug.cm/conference {}
    Setup

    if {($conference eq {}) ||
	($conference < 0)} {
	return {}
    }

    set sponsors [db do eval {
	SELECT contact
	FROM   sponsors
	WHERE  conference = :conference
    }]
    if {![llength $sponsors]} {
	return {}
    }

    return [cm::contact::KnownSelectLimited $sponsors]
}

proc ::cm::conference::known-staff {} {
    debug.cm/conference {}
    Setup

    set conference [the-current]
    if {$conference < 0} {
	return {}
    }

    set staff [db do eval {
	SELECT contact
	FROM   conference_staff
	WHERE  conference = :conference
    }]
    if {![llength $staff]} {
	return {}
    }

    # Find the contact information for the staff
    set known [cm::contact::KnownLimited $staff]

    # Compute map for staff from contact to complete role+contact.
    db do eval {
	SELECT R.text  AS role,
	       C.dname AS name,
	       R.id    AS rid,
	       C.id    AS cid
	FROM   conference_staff S,
	       staff_role       R,
	       contact          C
	WHERE  S.conference = :conference
	AND    S.role       = R.id
	AND    S.contact    = C.id
	ORDER BY role, name
    } {
	dict set map $cid [list $rid $cid]
    }

    # Remap the contact information in known to role+contact
    dict for {key id} $known {
	dict set known $key [dict get $map $id]
    }

    return $known
}

proc ::cm::conference::known-staff-select {conference} {
    debug.cm/conference {}
    Setup

    if {($conference eq {}) ||
	($conference < 0)} {
	return {}
    }

    # Not going through contact here. We need role information as
    # well.

    set known {}
    db do eval {
	SELECT R.text  AS role,
	       C.dname AS name,
	       R.id    AS rid,
	       C.id    AS cid
	FROM   conference_staff S,
	       staff_role       R,
	       contact          C
	WHERE  S.conference = :conference
	AND    S.role       = R.id
	AND    S.contact    = C.id
	ORDER BY role, name
    } {
	dict set known "$role/$name" [list $rid $cid]
    }
    return $known
}

proc ::cm::conference::committee {conference} {
    debug.cm/conference {}
    Setup

    return [db do eval {
	SELECT C.dname, C.id
	FROM   conference_staff S,
	       staff_role       R,
	       contact          C
	WHERE  S.conference = :conference
	AND    S.role       = R.id
	AND    R.text       = 'Program committee'
	AND    S.contact    = C.id
    }]
}

proc ::cm::conference::known {} {
    debug.cm/conference {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, title
	FROM   conference
    } {
	dict set known $title $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::issues {details} {
    debug.cm/conference {}
    dict with details {}
    # xconference 
    # xyear       
    # xmanagement 
    # xsubmission 
    # xcity       
    # xhotel      
    # xfacility   
    # xstart      
    # xend        
    # xalign      
    # xlength     
    # xtalklen    
    # xsesslen    
    # xrstatus

    set issues {}

    foreach {var message} {
	xcity      "Location is not known"
	xhotel     "Hotel is not known"
	xfacility  "Facility is not known"
	xstart     "Start date is not known"
	xend       "End date is not known"
	xpschedule "No schedule defined"
    } {
	if {[set $var] ne {}} continue
	+issue $message
    }

    if {![db do exists {
	SELECT id
	FROM   timeline
	WHERE  con = :xconference
    }]} {
	+issue "Undefined timeline"
    }

    if {![db do exists {
	SELECT id
	FROM   rate
	WHERE  conference = :xconference
	AND    location   = :xhotel
    }]} {
	+issue "No rate information"
    }

    if {![db do exists {
	SELECT id
	FROM   sponsors
	WHERE  conference = :xconference
    }]} {
	+issue "No sponsors"
    }

    # Staff check. Separate by role, as we need one per, at least.
    if 0 {db do eval {
	SELECT R.text            AS role,
	       count (S.contact) AS nstaff
	FROM      staff_role       R
	LEFT JOIN conference_staff S ON (R.id = S.role)
	WHERE S.conference = :xconference
	GROUP BY R.id
    } {
	if {$nstaff} continue
	+issue "Staff trouble: No one is \"$role\""
    }} ;# Trouble getting the sql right.

    # The explicit coding below does work.
    db do eval {
	SELECT id AS role, text
	FROM   staff_role
    } {
	set nstaff [db do eval {
	    SELECT count(contact)
	    FROM   conference_staff
	    WHERE  conference = :xconference
	    AND    role       = :role
	}]

	if {$nstaff} continue
	+issue "Staff trouble: No one is \"$text\""
    }

    if {![tutorial scheduled $xconference]} {
	+issue "No tutorials lined up"
    }

    if {![db do exists {
	SELECT id
	FROM   submission
	WHERE  conference = :xconference
    }]} {
	+issue "No submissions"
    } else {
	db do eval {
	    SELECT abstract, summary
	    FROM   submission
	    WHERE  conference = :xconference
	} {
	    if {[string trim $abstract] ne {}} continue
	    if {[string trim $summary]  ne {}} continue
	    +issue "Have submissions without abstract, nor summary"
	    break
	}
    }

    set presenters [the-presenters $xconference]
    foreach {dname _ _ _ _ _} [registered listing $xconference] {
	dict unset presenters $dname
    }
    foreach dname [lsort -dict [dict keys $presenters]] {
	+issue "Presenter \"$dname\" not registered"
    }

    set speakers [the-speakers $xconference]
    foreach {dname _ _ _ _ _ _ _} [booked listing $xconference] {
	dict unset speakers $dname
    }
    foreach dname [lsort -dict [dict keys $speakers]] {
	+issue "Speaker \"$dname\" not booked (to a hotel)"
    }


    if {![llength $issues]} return
    return $issues
}

proc ::cm::conference::+issue {text} {
    debug.cm/conference {}
    upvar 1 issues issues
    lappend issues $text
    return
}

proc ::cm::conference::get {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT title
	FROM  conference
	WHERE id = :id
    }]
}

proc ::cm::conference::details {id} {
    debug.cm/conference {}
    Setup

    return [db do eval {
	SELECT 'xconference', id,
	       'xyear',       year,
	       'xmanagement', management,
	       'xsubmission', submission,
	       'xcity',       city,
	       'xhotel',      hotel,
	       'xfacility',   facility,
	       'xstart',      startdate,
	       'xend',        enddate,
	       'xalign',      alignment,
	       'xlength',     length,
	       'xtalklen',    talklength,
	       'xsesslen',    sessionlen,
	       'xrstatus',    rstatus,
	       'xpschedule',  pschedule
	FROM  conference
	WHERE id = :id
    }]
}

proc ::cm::conference::write {id details} {
    debug.cm/conference {}
    Setup

    dict with details {}
    db do eval {
	UPDATE conference
	SET    year       = :xyear,
	       management = :xmanagement,
	       submission = :xsubmission,
	       city       = :xcity,
	       hotel      = :xhotel,
	       facility   = :xfacility,
	       startdate  = :xstart,
	       enddate    = :xend,
	       alignment  = :xalign,
	       length     = :xlength,
	       talklength = :xtalklen,
	       sessionlen = :xsesslen,
	       rstatus    = :xrstatus
	WHERE id = :id
    }
}

proc ::cm::conference::the-current {} {
    debug.cm/conference {}

    try {
	set id [config get @current-conference]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	return -1
    }
    if {[has $id]} { return $id }
    return -1
}

proc ::cm::conference::current {} {
    debug.cm/conference {}

    try {
	set id [config get @current-conference]
    } trap {CM CONFIG GET UNKNOWN} {e o} {
	util user-error "No conference chosen, please \"select\" a conference"
    }
    if {[has $id]} { return $id }

    util user-error "Bad conference index, please \"select\" a conference"
}

proc ::cm::conference::has {id} {
    debug.cm/conference {}
    Setup

    return [db do exists {
	SELECT title
	FROM   conference
	WHERE  id = :id
    }]
}

proc ::cm::conference::select {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set conferences [known]
    set choices     [lsort -dict [dict keys $conferences]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $conferences 1]
	}
    }

    set choice [ask menu "" "Which conference: " $choices]

    # Map back to id
    return [dict get $conferences $choice]
}

proc ::cm::conference::select-sponsor {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set sponsors [known-sponsor-select [the-current]]
    set choices  [lsort -dict [dict keys $sponsors]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $sponsors 1]
	}
    }

    set choice [ask menu "" "Which sponsor: " $choices]

    # Map back to id
    return [dict get $sponsors $choice]
}

proc ::cm::conference::select-staff {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
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

    # Map back to id
    return [dict get $staff $choice]
}

proc ::cm::conference::get-rate {conference location} {
    debug.cm/conference {}
    Setup

    db do eval {
	SELECT rate, decimal, currency, groupcode, begindate, enddate, deadline, pdeadline
	FROM   rate
	WHERE  conference = :conference
	AND    location   = :location
    } {
	set factor 10e$decimal
	set rate [format %.${decimal}f [expr {$rate / $factor}]]

	set begindate [expr {($begindate ne {})
			     ? [hdate $begindate]
			     : "Undefined"}]
	set enddate [expr {($enddate ne {})
			   ? [hdate $enddate]
			   : "Undefined"}]
	set deadline [expr {($deadline ne {})
			    ? [hdate $deadline]
			    : "Undefined"}]
	set pdeadline [expr {($pdeadline ne {})
			     ? [hdate $pdeadline]
			     : "Undefined"}]
	return [dict create \
		    rate      $rate \
		    currency  $currency \
		    begin     $begindate \
		    end       $enddate \
		    deadline  $deadline \
		    pdeadline $pdeadline \
		    group     $groupcode]
    }
}

proc ::cm::conference::get-submission-handle {id} {
    return S${id}_
}

proc ::cm::conference::get-submission {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT title
	FROM   submission
	WHERE  id = :id
    }]
}

proc ::cm::conference::known-submissions-vt {} {
    debug.cm/conference {}
    Setup

    set conference [the-current]

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, title
	FROM   submission
	WHERE  conference = :conference
    } {
	dict set known $title                        $id
	dict set known "[get-submission-handle $id]" $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::known-submissions {conference} {
    debug.cm/conference {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, title
	FROM   submission
	WHERE  conference = :conference
    } {
	dict set known $title $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::select-submission {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set submissions [known-submissions [the-current]]
    set choices     [lsort -dict [dict keys $submissions]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $submission 1]
	}
    }

    set choice [ask menu "" "Which submission: " $choices]

    # Map back to id
    return [dict get $submissions $choice]
}

proc ::cm::conference::known-talks-vt {} {
    debug.cm/conference {}
    Setup

    set conference [the-current]

    # dict: label -> id
    set known {}

    db do eval {
	SELECT T.id    AS id
	,      S.id    AS sid
	,      S.title AS title
	FROM   submission S
	,      talk       T
	WHERE  S.conference = :conference
	AND    S.id         = T.submission
    } {
	dict set known $title                         $id
	dict set known "[get-submission-handle $sid]" $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::get-talk-title {talk} {
    debug.cm/conference {}
    Setup
    return [db do onecolumn {
	SELECT title
	FROM   submission
	WHERE  id IN (SELECT submission
		      FROM   talk
		      WHERE  id = :talk)
    }]
}


# # ## ### ##### ######## ############# ######################

proc ::cm::conference::TimelineSQL {conference} {
    set details [details $conference]
    dict with details {}

    if {$xhotel eq {}} {
	# No rate information available. Generate only the basic core
	# timeline.

	set sql {
	    SELECT T.date     AS date,
	           E.text     AS text,
	           E.ispublic AS ispublic,
	           T.done     AS done
	    FROM   timeline      T,
	           timeline_type E
	    WHERE T.con  = :conference
	    AND   T.type = E.id
	    ORDER BY T.date
	}
    } else {
	# Rate information is present, this includes the room
	# deadlines.  Generate fake timeline entries for these and
	# merge with the core timeline.

	set sql [string map [list :xhotel $xhotel] {
	    SELECT date, text, ispublic, done
	    FROM (SELECT T.date     AS date
		  ,      E.text     AS text
		  ,      E.ispublic AS ispublic
		  ,      T.done     AS done
		  FROM   timeline      T,
		  timeline_type E
		  WHERE T.con  = :conference
		  AND   T.type = E.id
		UNION
		  SELECT deadline       AS date
		  ,      'Room Release' AS text
		  ,      0              AS ispublic
		  ,      0              AS done
		  FROM   rate R
		  WHERE  R.conference = :conference
		  AND    R.location   = :xhotel
		UNION
		  SELECT pdeadline             AS date
		  ,      'Public Room Release' AS text
		  ,      1                     AS ispublic
		  ,      0                     AS done
		  FROM   rate R
		  WHERE  R.conference = :conference
		  AND    R.location   = :xhotel)
	    ORDER BY date
	}]
    }

    return $sql
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::Setup {} {
    debug.cm/conference {}

    db use contact
    db use city
    db use config
    db use dayhalf
    db use location
    db use rstatus
    db use staff-role
    db use talk-state
    db use talk-type
    db use template
    db use timeline
    db use tutorial
    db use booked
    db use registered

    if {![dbutil initialize-schema ::cm::db::do error conference {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    title	TEXT	NOT NULL UNIQUE,
	    year	INTEGER NOT NULL,

	    management	INTEGER	NOT NULL REFERENCES contact,	-- Org/company/person managing the conference
	    submission	INTEGER	NOT NULL REFERENCES email,	-- Email to receive submissions.

	    city	INTEGER REFERENCES city,
	    hotel	INTEGER REFERENCES location, -- We do not immediately know where we will be
	    facility	INTEGER REFERENCES location, -- While sessions are usually at the hotel, they may not be.

	    startdate	INTEGER,		-- [*], date [epoch]
	    enddate	INTEGER,		--	date [epoch]
	    alignment	INTEGER NOT NULL,	-- iso8601 weekday (1:mon...7:sun), or -1 (no alignment)
	    length	INTEGER NOT NULL,	-- length in days

	    talklength	INTEGER NOT NULL,	-- minutes	  here we configure
	    sessionlen	INTEGER NOT NULL,	-- in #talks max  basic scheduling parameters.
						-- 		  shorter talks => longer sessions.
						-- 		  standard: 30 min x3
	    rstatus	INTEGER NOT NULL REFERENCES rstatus,

	    pschedule   INTEGER REFERENCES pschedule

	    -- future expansion columns:
	    -- -- max day|range for tutorials
	    -- -- max number of tracks for tutorials
	    -- -- max number of tracks for sessions

	    -- Constraints:
	    -- * (city == facility->city) WHERE facility IS NOT NULL
	    -- * (city == hotel->city)    WHERE facility IS NULL AND hotel IS NOT NULL
	    --   Note: This covers the possibility of hotel->city != session->city
	    --   In that case we expect the conference to be in the city where the sessions are.
	    --
	    -- * year      == year-of    (start-date)
	    -- * alignment == weekday-of (start-date) WHERE alignment > 0.
	    -- * enddate   == startdate + length days

	    -- [Ad *] from this we can compute a basic timeline
	    --	for deadlines and actions (cfp's, submission
	    --	deadline, material deadline, etc)
	    --	Should possibly save it in a table, and allow
	    --	for conversion into ical and other calender formats.
	    --
	    -->	Google Calendar of the Conference, Mgmt + Public
	} {
	    {id			INTEGER 1 {} 1}
	    {title		TEXT    1 {} 0}
	    {year		INTEGER 1 {} 0}
	    {management		INTEGER 1 {} 0}
	    {submission		INTEGER 1 {} 0}
	    {city		INTEGER 0 {} 0}
	    {hotel		INTEGER 0 {} 0}
	    {facility		INTEGER 0 {} 0}
	    {startdate		INTEGER	0 {} 0}
	    {enddate		INTEGER	0 {} 0}
	    {alignment		INTEGER	1 {} 0}
	    {length		INTEGER	1 {} 0}
	    {talklength		INTEGER	1 {} 0}
	    {sessionlen		INTEGER	1 {} 0}
	    {rstatus		INTEGER	1 {} 0}
	    {pschedule		INTEGER	0 {} 0}
	} {}
    }]} {
	db setup-error conference $error
    }

    if {![dbutil initialize-schema ::cm::db::do error timeline {
	{
	    -- conference timeline/calendar of action items, deadlines, etc.

	    id	 INTEGER NOT NULL PRIMARY KEY,
	    con	 INTEGER NOT NULL REFERENCES conference,
	    date INTEGER NOT NULL,		-- when this happens [epoch]
	    type INTEGER NOT NULL REFERENCES timeline_type,
	    done INTEGER NOT NULL
	} {
	    {id   INTEGER 1 {} 1}
	    {con  INTEGER 1 {} 0}
	    {date INTEGER 1 {} 0}
	    {type INTEGER 1 {} 0}
	    {done INTEGER 1 {} 0}
	} {con}
    }]} {
	db setup-error timeline $error
    }

    if {![dbutil initialize-schema ::cm::db::do error sponsors {
	{
	    -- sponsors (contacts) for the conference
	    -- mailing lists are not allowed, only people and companies.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER	NOT NULL REFERENCES conference,
	    contact	INTEGER	NOT NULL REFERENCES contact,
	    UNIQUE (conference,contact)
	} {
	    {id		INTEGER 1 {} 1}
	    {conference	INTEGER 1 {} 0}
	    {contact	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error sponsors $error
    }

    if {![dbutil initialize-schema ::cm::db::do error conference_staff {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER NOT NULL REFERENCES conference,
	    contact	INTEGER NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk
	    role	INTEGER NOT NULL REFERENCES staff_role,
	    UNIQUE (conference, contact, role)
	    -- Multiple people can have the same role (ex: program commitee)
	    -- One person can have multiple roles (ex: prg.chair, prg. committee)
	} {
	    {id		INTEGER 1 {} 1}
	    {conference	INTEGER 1 {} 0}
	    {contact	INTEGER 1 {} 0}
	    {role	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error conference_staff $error
    }

    if {![dbutil initialize-schema ::cm::db::do error rate {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER	NOT NULL REFERENCES conference,
	    location	INTEGER	NOT NULL REFERENCES location,
	    rate	INTEGER	NOT NULL,	-- per night
	    decimal	INTEGER	NOT NULL,	-- number of digits stored after the decimal point
	    currency	TEXT	NOT NULL,	-- name of the currency the rate is in
	    groupcode	TEXT,
	    begindate	INTEGER,		-- date [epoch] the discount begins
	    enddate	INTEGER,		-- date [epoch] the discount ends
	    deadline	INTEGER,		-- date [epoch] registration deadline
	    pdeadline	INTEGER,		-- date [epoch] same, but publicly known
						-- show a worse deadline public for grace period
	    -- Constraints: begin- and end-dates should cover the entire conference, at least.
	    -- deadline should not be in the past on date of entry.
	    UNIQUE (conference, location)
	    -- We are sort of ready here for a future where we might have multiple hotels
	    -- and associated rates. If so 'conference.hotel' would become bogus.
	} {
	    {id			INTEGER 1 {} 1}
	    {conference		INTEGER 1 {} 0}
	    {location		INTEGER 1 {} 0}
	    {rate		INTEGER 1 {} 0}
	    {decimal		INTEGER 1 {} 0}
	    {currency		TEXT    1 {} 0}
	    {groupcode		TEXT    0 {} 0}
	    {begindate		INTEGER 0 {} 0}
	    {enddate		INTEGER 0 {} 0}
	    {deadline		INTEGER 0 {} 0}
	    {pdeadline		INTEGER 0 {} 0}
	} {}
    }]} {
	db setup-error rate $error
    }

    if {![dbutil initialize-schema ::cm::db::do error submission {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    conference	INTEGER	NOT NULL REFERENCES conference,
	    title	TEXT	NOT NULL,
	    abstract	TEXT	NOT NULL,
	    summary	TEXT,
	    invited	INTEGER	NOT NULL,	-- keynotes are a special submission made by mgmt
	    submitdate	INTEGER	NOT NULL,	-- date of submission [epoch].
	    UNIQUE (conference, title)

	    -- acceptance is implied by having a talk referencing the submission.
	} {
	    {id		INTEGER 1 {} 1}
	    {conference	INTEGER 1 {} 0}
	    {title	TEXT    1 {} 0}
	    {abstract	TEXT    1 {} 0}
	    {summary	TEXT    0 {} 0}
	    {invited	INTEGER 1 {} 0}
	    {submitdate	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error submission $error
    }

    if {![dbutil initialize-schema ::cm::db::do error submitter {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    submission	INTEGER	NOT NULL REFERENCES submission,
	    contact	INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk||can_submit
	    note	TEXT,					-- distinguish author, co-author, if wanted
	    UNIQUE (submission, contact)
	} {
	    {id		INTEGER 1 {} 1}
	    {submission	INTEGER 1 {} 0}
	    {contact	INTEGER 1 {} 0}
	    {note	TEXT    0 {} 0}
	} {contact}
    }]} {
	db setup-error submitter $error
    }

    if {![dbutil initialize-schema ::cm::db::do error talk {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    submission	INTEGER	NOT NULL REFERENCES submission,	-- implies conference
	    type	INTEGER	NOT NULL REFERENCES talk_type,
	    state	INTEGER	NOT NULL REFERENCES talk_state,
	    isremote	INTEGER	NOT NULL,			-- hangout, skype, other ? => TEXT?

	    UNIQUE (submission) -- Not allowed to have the same submission in multiple conferences.

	    -- constraint: talk.conference == talk.submission.conference
	} {
	    {id		INTEGER 1 {} 1}
	    {submission	INTEGER 1 {} 0}
	    {type	INTEGER 1 {} 0}
	    {state	INTEGER 1 {} 0}
	    {isremote	INTEGER 1 {} 0}
	} {}
    }]} {
	db setup-error talk $error
    }

    if {![dbutil initialize-schema ::cm::db::do error talker {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    talk	INTEGER	NOT NULL REFERENCES talk,
	    contact	INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk||can_submit

	    UNIQUE (talk, contact)

	    -- We allow multiple speakers => panels, co-presentation
	    -- Note: Presenter is not necessarily any of the submitters of the submission behind the talk
	} {
	    {id		INTEGER 1 {} 1}
	    {talk	INTEGER 1 {} 0}
	    {contact	INTEGER 1 {} 0}
	} {contact}
    }]} {
	db setup-error talker $error
    }

    if {![dbutil initialize-schema ::cm::db::do error attachment {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    talk	INTEGER	NOT NULL REFERENCES talk,
	    type	TEXT	NOT NULL,	-- Readable type/label
	    mime	TEXT	NOT NULL,	-- mime type for downloads and the like?
	    data	BLOB	NOT NULL,
	    UNIQUE (talk, type)
	} {
	    {id		INTEGER 1 {} 1}
	    {talk	INTEGER 1 {} 0}
	    {type	TEXT    1 {} 0}
	    {mime	TEXT    1 {} 0}
	    {data	BLOB    1 {} 0}
	} {}
    }]} {
	db setup-error attachment $error
    }

    # Shortcircuit further calls
    proc ::cm::conference::Setup {args} {}
    return
}

proc ::cm::conference::Dump {} {
    debug.cm/conference {}

    db do eval {
	SELECT id, title, year, management, submission,
	       city, hotel, facility,
	       startdate, enddate, alignment, length,
	       talklength, sessionlen, rstatus, pschedule
	FROM   conference
	ORDER BY title
    } {
	set management [contact 2name-plain $management]
	set submission [contact 2name-email $submission]
	set startdate  [isodate $startdate]
	if {$alignment > 0} {
	    set alignment  [weekday 2external $alignment]
	} else {
	    # TODO: extended weekday validator, allow empty string for -1
	    set alignment {}
	}
	# enddate - implied (start+length)
	# talklength, sessionlen - fixed, currently

	cm dump save \
	    conference create $title $year $alignment $startdate $length \
	    $management $submission
	# auto-select conference as current

	if {$hotel ne {}} {
	    cm dump save  \
		conference hotel [location 2name* $hotel]
	}
	if {$facility ne {}} {
	    cm dump save   \
		conference facility [location 2name* $facility]
	}
	# city is implied by the facility/hotel

	cm dump save \
	    conference registration [rstatus 2name $rstatus]

	# timeline
	cm dump step 
	cm dump save \
	    conference timeline-init
	db do eval {
	    SELECT T.date AS date,
	           E.key  AS text,
	           T.done AS done
	    FROM   timeline      T,
                   timeline_type E
	    WHERE  T.con  = :id
	    AND    T.type = E.id
	    ORDER BY T.date
	} {
	    cm dump save \
		conference timeline-set $text [isodate $date]
	    if {$done} {
		cm dump save \
		    conference timeline-done $text
	    }
	}

	# rate
	db do eval {
	    SELECT rate, decimal, currency, groupcode, begindate, enddate, deadline, pdeadline
	    FROM   rate
	    WHERE  conference = :id
	    AND    location   = :hotel
	} {
	    set factor 10e$decimal
	    set rate [format %.${decimal}f [expr {$rate / $factor}]]

	    cm dump step 
	    cm dump save \
		conference rate \
		-G $groupcode \
		-F [isodate $begindate] \
		-T [isodate $enddate] \
		-D [isodate $deadline] \
		-P [isodate $pdeadline] \
		$rate $currency $decimal
	}

	# staff
	set first 1
	db do eval {
	    SELECT C.dname AS name,
	           R.text  AS role
	    FROM   conference_staff S,
	           contact          C,
	           staff_role       R
	    WHERE  S.conference = :id
	    AND    S.contact    = C.id
	    AND    S.role       = R.id
	    ORDER BY role, name
	} {
	    if {$first} { cm dump step ; set first 0 }
	    cm dump save \
		conference add-staff $role $name
	}

	# sponsors
	set first 1
	db do eval {
	    SELECT C.dname AS name
	    FROM   sponsors S,
	           contact  C
	    WHERE  S.conference = :id
	    AND    S.contact    = C.id
	    ORDER BY C.dname
	} {
	    if {$first} { cm dump step  ; set first 0 }
	    cm dump save \
		conference add-sponsor $name
	}

	# tutorial schedule
	set first 1
	db do eval {
	    SELECT S.day   AS day,
	           H.text  AS half,
	           S.track AS track,
	           T.title AS tutorial,
	           C.dname AS speaker
	    FROM   tutorial_schedule S,
	           tutorial          T,
	           dayhalf           H,
	           contact           C
	    WHERE  S.conference = :id
	    AND    S.tutorial   = T.id
	    AND    S.half       = H.id
	    AND    T.speaker    = C.id
	    ORDER BY day, track, H.id
	} {
	    if {$first} { cm dump step  ; set first 0 }
	    incr day ;# move to the external 1-based day offset.
	    cm dump save \
		conference add-tutorial $day $half $track $speaker/$tutorial
	}

	# submissions
	set first 1
	db do eval {
	    SELECT id AS sid, title, invited, submitdate, abstract, summary
	    FROM   submission
	    WHERE  conference = :id
	    ORDER BY submitdate, sid
	} {
	    if {$first} { cm dump step  ; set first 0 }

	    set authors [db do eval {
		SELECT dname
		FROM   contact
		WHERE  id IN (SELECT contact
			      FROM   submitter
			      WHERE  submission = :sid)
		ORDER BY dname
	    }]

	    if {$invited} {
		cm dump save \
		    submit \
		    --on [isodate $submitdate] --invited $title \
		    {*}$authors
	    } else {
		cm dump save \
		    submit \
		    --on [isodate $submitdate] $title {*}$authors
	    }

	    if {$summary ne {}} {
		cm dump save \
		    submission set-summary $title \
		    < [cm dump write submission-summary${sid} $summary]
	    }

	    if {$abstract ne {}} {
		cm dump save \
		    submission set-abstract $title \
		    < [cm dump write submission-abstract${sid} $abstract]
	    }
	    cm dump step
	}

	# talks
	set first 1
	db do eval {
	    SELECT T.id AS tid, S.title AS title, X.text AS type
	    FROM   talk       T,
	           submission S,
	           talk_type  X
	    WHERE  T.submission = S.id
	    AND    T.type = X.id
	    ORDER BY S.title
	} {
	    if {$first} { cm dump step  ; set first 0 }

	    cm dump save \
		submission accept -type $type $title

	    db do eval {
		SELECT dname
		FROM   contact
		WHERE  id IN (SELECT contact
			  FROM   talker
			  WHERE  talk = :tid)
		ORDER BY dname
	    } {
		cm dump save \
		    submission add-speaker $title $dname
	    }

	    db do eval {
		SELECT id AS aid, type, mime
		FROM   attachment
		WHERE  talk = :tid
		ORDER BY type
	    } {
		set ch [db do incrblob -readonly attachment data $aid]
		fconfigure $ch -encoding binary -translation binary
		set value [read $ch]
		close $ch

		cm dump save \
		    submission attach $title $type $mime \
		    < [cm dump write attachment$aid $value \
			   -encoding binary \
			   -translation binary]
	    }
	}

	booked     dump $id
	registered dump $id

	# logical schedule
	# A - linked physical schedule

	if {$pschedule ne {}} {
	    cm dump step
	    cm dump save \
		configure schedule [pschedule piece $pschedule dname]

	    # logical schedule B - schedule entries
	    set first 1
	    db do eval {
		SELECT label
		,      talk
		,      tutorial
		,      session
		FROM   schedule
		WHERE  conference = :id
		ORDER BY label
	    } {
		if {$first} { cm dump step  ; set first 0 }

		if {$talk ne {}} {
		    set type  talk
		    set value [get-talk-title $talk]
		} elseif {$tutorial ne {}} {
		    set type  tutorial
		    set value [tutorial 2name-from-schedule $tutorial]
		} elseif {$session ne {}} {
		    set type  fixed
		    set value $session
		} else {
		    set type  fixed
		    set value {}
		}

		cm dump save \
		    conference schedule-edit $label $type $value
	    }
	}

	# Campaign for the conference.
	cm::campaign::Dump $id

	cm dump step 
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::conference 0
return
