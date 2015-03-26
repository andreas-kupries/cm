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
package require cmdr::validate::date
package require cmdr::validate::weekday
package require dbutil
package require debug
package require debug::caller
package require try

package provide cm::conference 0 ;# circular via contact, campaign

package require cm::city
package require cm::config::core
package require cm::contact
package require cm::db
package require cm::location
package require cm::mailer
package require cm::mailgen
package require cm::table
package require cm::template
package require cm::tutorial
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
	cmd_sponsor_show cmd_sponsor_link cmd_sponsor_unlink cmd_sponsor_ping \
	cmd_committee_ping cmd_website_make cmd_end_set cmd_rate_show \
	cmd_rate_set cmd_staff_show cmd_staff_link cmd_staff_unlink \
	cmd_submission_add cmd_submission_drop cmd_submission_show cmd_submission_list \
	cmd_submission_setsummary cmd_submission_setabstract cmd_registration \
	cmd_tutorial_show cmd_tutorial_link cmd_tutorial_unlink \
	select label current get insert known-sponsor \
	select-sponsor select-staff-role select-staff known-staff known-rstatus \
	get-role select-timeline get-timeline select-submission get-submission \
	get-submission-handle known-submissions-vt
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cmdr::validate::date
    namespace import ::cmdr::validate::weekday
    namespace import ::cm::city
    namespace import ::cm::contact
    namespace import ::cm::db
    namespace import ::cm::location
    namespace import ::cm::mailer
    namespace import ::cm::mailgen
    namespace import ::cm::template
    namespace import ::cm::tutorial
    namespace import ::cm::util

    namespace import ::cm::config::core
    rename core config

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/conference
debug prefix cm/conference {[debug caller] | }

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
	    if {$issues ne {}} {
		append title \n $issues
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

    set title  [$config @title]
    set year   [$config @year]
    set align  [$config @alignment]
    set start  [$config @start]
    set length [$config @length]

    puts -nonewline "Creating conference \"[color name $title]\" ... "

    # move start-date into alignment
    if {$align > 0} {
	while {[clock format $start -format %u] != $align} {
	    set start [clock add $start -1 days]
	}
    }

    # check year-of start-date vs year
    if {[clock format $start -format %Y] != $year} {
	util user-error "Start date does not match conference year" YEAR MISMATCH
    }

    # calculate end-date (= start + (length - 1))
    incr length -1
    set end [clock add $start $length days]

    # defaults for talk-length and session-length - see sql below
    try {
	db do transaction {
	    db do eval {
		INSERT INTO conference
		VALUES (NULL, :title, :year, NULL, NULL, NULL,
			:start, :end, :align, :length, 30, 3)
		-- 30 minutes per talk, at 3 talks per session - defaults
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

    puts -nonewline "Setting as current conference ... "
    config assign @current-conference $id
    puts [color good OK]

    puts [color warning {Please remember to set the location information}]
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
	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
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

	if {$xcity     ne {}} { set xcity     [city     get $xcity] }
	if {$xhotel    ne {}} { set xhotel    [location get $xhotel] }
	if {$xfacility ne {}} { set xfacility [location get $xfacility] }

	set xmanagement [contact get       $xmanagement]
	set xsubmission [contact get-email $xsubmission]

	$t add Year             $xyear
	$t add Management       $xmanagement
	$t add {Submissions To} $xsubmission
	$t add Registrations    [get-rstatus $xrstatus] ;# TODO: colorize the status
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

	$t add {} {}

	if {[db do exists {
	    SELECT *
	    FROM   rate
	    WHERE  conference = :conference
	    AND    location   = :xhotel
	}]} {
	    $t add [color note bad Rate] "[color bad Undefined]\n(=> conference rate)"
	} else {
	    $t add [color note Rate]     "[color note ok]\n(=> conference rates)"
	}

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

	# And the sponsors, if any.
	set scount [db do eval {
	    SELECT count (id)
	    FROM   sponsors
	    WHERE  conference = :id
	}]
	if {!$scount} {
	    set tcount None
	    set color  bad
	    set suffix "\n(=> conference add-sponsor)"
	} else {
	    set color  note
	    set suffix "\n(=> conference sponsors)"
	}
	$t add [color $color Sponsors] [color $color $scount]$suffix

	# Do not forget the staff
	set scount [db do eval {
	    SELECT count (id)
	    FROM   conference_staff
	    WHERE  conference = :id
	}]
	if {!$scount} {
	    set tcount None
	    set color  bad
	    set suffix "\n(=> conference add-staff)"
	} else {
	    set color  note
	    set suffix "\n(=> conference staff)"
	}
	$t add [color $color Staff] [color $color $scount]$suffix

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
    set flabel   [location get $facility]
    set city     [dict get [location details $facility] xcity]
    set clabel   [city get $city]

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
    set hlabel  [location get $hotel]
    set city    [dict get [location details $hotel] xcity]
    set clabel  [city get $city]

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

    puts "Shift \"[get-timeline $entry]\"\nOf    \"[color name [get $conference]]\"\nBy    $shift days"

    db do transaction {
	set old [db do onecolumn {
	    SELECT date 
	    FROM   timeline
	    WHERE  con  = :conference
	    AND    type = :entry
	}]

	set new [clock add $old $shift days]

	puts -nonewline "To    [hdate $new] ... "

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

proc ::cm::conference::cmd_timeline_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Timeline of \"[color name [get $conference]]\":"
    [table t {Event When} {
	#$t style table/html ;# quick testing
	db do eval {
	    SELECT T.date     AS date,
	           E.text     AS text,
	           E.ispublic AS ispublic
	    FROM   timeline      T,
	           timeline_type E
	    WHERE T.con  = :conference
	    AND   T.type = E.id
	    ORDER BY T.date
	} {
	    if {$ispublic} {
		$t add [color note $text] [color note [hdate $date]]
	    } else {
		$t add $text [hdate $date]
	    }
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
    set template   [$config @template]
    set tlabel     [template get $template]

    puts "Mailing the committee of \"[color name [get $conference]]\":"
    puts "Using template: [color name $tlabel]"

    set template     [template details $template]
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

    if {![ask yn "Send mail ? " no]} {
	puts [color note Aborted]
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

	    $t add Id        [get-submission-handle $id]
	    $t add Submitted [hdate $submitdate]
	    $t add Title     $title

	    if {$invited} {
		$t add [color note Invited] yes
	    } else {
		$t add Invited  no
	    }

	    $t add Authors  $authors
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

    puts "Submissions for \"[color name [get $conference]]\""
    [table t {Id Date Authors {} Title} {
	db do eval {
	    SELECT id, title, invited, submitdate
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

	    $t add [get-submission-handle $id] $submitdate $authors $invited $title
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::cmd_registration {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set newstatus  [$config @status] 

    puts -nonewline "Conference \"[color name [get $conference]]\" registration = [get-rstatus $newstatus] ... "
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
    set template   [$config @template]
    set tlabel     [template get $template]

    puts "Mailing the sponsors of \"[color name [get $conference]]\":"
    puts "Using template: [color name $tlabel]"

    set template     [template details $template]
    set destinations [db do eval {
	SELECT id, email
	FROM   email
	WHERE  contact IN (SELECT person
			   FROM   liaison
			   WHERE  company IN (SELECT contact
					      FROM   sponsors
					      WHERE  conference = :conference))
    }]

    debug.cm/conference {destinations = ($destinations)}

    set addresses    [lsort -dict [dict values $destinations]]
    set destinations [dict keys $destinations]

    debug.cm/conference {addresses    = ($addresses)}
    debug.cm/conference {destinations = ($destinations)}

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

    if {![ask yn "Send mail ? " no]} {
	puts [color note Aborted]
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

	    set related [contact related-formatted $contact $type]

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
	puts -nonewline "  \"[color name [cm contact get $contact]]\" ... "
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
	puts -nonewline "  \"[color name [cm contact get $contact]]\" ... "
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
	    FROM conference_staff S,
	         contact          C,
	         staff_role       R
	    WHERE S.conference = :conference
	    AND   S.contact    = C.id
	    AND   S.role       = R.id
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

    puts "Adding [get-role $role] to conference \"[color name [get $conference]]\" ... "

    foreach contact [$config @name] {
	puts -nonewline "  \"[color name [cm contact get $contact]]\" ... "
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

    puts -nonewline "  [get-role $role] \"[color name [cm contact get $contact]]\" ... "
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

    lassign [cm::tutorial dayrange   $conference] daymin   daymax   daylast
    lassign [cm::tutorial trackrange $conference] trackmin trackmax tracklast

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
		    set tutorial [cm::tutorial cell $conference $day $half $track]

		    if {$tutorial ne {}} {
			set    tdetails [tutorial details $tutorial]
			set    title    [dict get $tdetails xtitle]
			set    tag      @
			append tag      [dict get [contact details [dict get $tdetails xspeaker]] xtag] :
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

    puts "Adding \"[color name [cm::tutorial get $tutorial]]\" to conference \"[color name [get $conference]]\" ... "
    set details [details $conference]
    set clen    [dict get $details xlength]

    if {$day > $clen} {
	util user-error "Bad day $day, conference is only $clen days long" DAY-OUT-OF-RANGE $day $clen
    }

    puts "@ day $day [cm::tutorial get-half $half], track $track"
    flush stdout

    incr day -1 ;# convert to the internal 0-based storage
    db do eval {
	INSERT INTO tutorial_schedule
	VALUES (NULL, :conference, :day, :half, :track, :tutorial)
    }

    puts [color good OK]
    return
}

proc ::cm::conference::cmd_tutorial_unlink {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set tutorial [$config @tutorial]

    puts -nonewline "Removing \"[color name [cm::tutorial get $tutorial]]\" from conference \"[color name [get $conference]]\" ... "
    flush stdout

    db do eval {
	DELETE
	FROM  tutorial_schedule
	WHERE conference = :conference
	AND   tutorial   = :tutorial
    }

    puts [color good OK]
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

    [table t {Property Value} {
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

    # Limit to the chosen umber of digits after the decimal point, we
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
	           decimal    = :decimal
	           currency   = :currency
	           groupcode  = :group
	           begindate  = :begin
	           enddate    = :end
	           deadline   = :dead
	           pdeadline  = :pdead
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

proc ::cm::conference::cmd_website_make {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]
    set dstdir     [$config @destination]

    # # ## ### ##### ######## #############
    puts "Remove old..."
    file delete -force  $dstdir ${dstdir}_out

    # # ## ### ##### ######## #############
    puts "Initialization..."
    ssg init $dstdir ${dstdir}_out ;# TODO Use a tmp dir for this
    file delete -force $dstdir/pages/blog

    # # ## ### ##### ######## #############
    puts "Filling in..."
    lappend navbar {*}[make_page Overview          index       make_overview]
    lappend navbar {*}[make_page {Call For Papers} cfp         make_callforpapers]
    lappend navbar {*}[make_page Location          location    make_location]

    set rstatus [registration-mode $conference]
    puts "Registration: $rstatus"
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

    if {[cm::tutorial have-some $conference]} {
	puts "Tutorials: [color good Yes]"
	lappend navbar {*}[make_page Tutorials         tutorials   make_tutorials $conference]
    } else {
	puts "Tutorials: [color bad None]"
	lappend navbar {*}[make_page Tutorials         tutorials   make_tutorials_none]
    }


    lappend navbar {*}[make_page Schedule          schedule    make_schedule]
    make_page                    Abstracts         abstracts   make_abstracts
    make_page                    Speakers          bios        make_speakers
    lappend navbar {*}[make_page Proceedings       proceedings make_proceedings]
    lappend navbar {*}[make_page Contact           contact     make_contact]
    make_page                    Disclaimer        disclaimer  make_disclaimer

    # # ## ### ##### ######## #############
    # Configuration file.
    puts "\tWebsite configuration"

    # NOTE: website.conf TODO - treat template as the semi-dict it is, prog access.
    #       Do programmatic access, instead of text manipulation.

    set text [template use www-wconf]
    set text [insert $conference $text]
    #lappend map @wc:prelude@ {} ;# { <% interp-source shortcuts.tcl %> } ;# <%%%>
    lappend map @wc:nav@     $navbar
    lappend map @wc:sidebar@ [make_sidebar $conference]
    set    text [string map $map $text]
    #append text "\nenableMacrosInPages 1"
    unset map
    fileutil::writeFile $dstdir/website.conf $text

    # # ## ### ##### ######## #############
    # Helper macros, see <%%%>, pagePrelude of the config.
    if 0 {puts "\tWebsite Helper Macros"
    set text {
	proc md {text} {
	    #set text [string map [list \\t \t \\r \r \\n \n \\s { } \\\\ \\] $text]
	    return <p>[markdown-to-html $text]</p>
	}
    }
	fileutil::writeFile $dstdir/templates/shortcuts.tcl $text}

    # # ## ### ##### ######## #############
    puts "Generation..."
    ssg build $dstdir ${dstdir}_out ;# TODO from tmp dir, use actual destination => implied deployment

    return
    puts "Deploy..."
    ssg deploy-copy $dstdir
    # custom - use rsync - or directory swap
}

proc ::cm::conference::encode {text} {
    #set text [string map [list \t \\t \r \\r \n \\n { } \\s \\ \\\\] $text]
    set text [list $text]
    return $text
}

proc ::cm::conference::ssg {args} {
    # option to switch vebosity
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
	puts [color bad ERROR:]\t${title}\t([color bad $e])
	append text "\n__ERROR__\n\n" <pre>$::errorInfo</pre> \n\n
    }

    append text [make_page_footer]
    set    text [insert $conference $text]

    fileutil::writeFile $dstdir/pages/${fname}.md $text
    return [list $title "\$rootDirPath/${fname}.html"]
}

proc ::cm::conference::make_page_header {title} {
    debug.cm/conference {}
    # page-header - TODO: Separate hotel and facilities.
    # page-header - TODO: Move text into a configurable template? This one is a maybe.
    # page-header - TODO: Conditional text for link, phone, and fax, any could be missing.

    lappend map @@ $title
    return [string map $map [string trimleft [util undent {
	{
	    title {@@}
	}

	## @c:when@

	[@h:hotel@](@h:booklink@)		</br>
	[@h:city@](@h:booklink@)		</br>
	[@h:street@](@h:booklink@)		</br>
	[Phone: @h:bookphone@](@h:booklink@)	</br>
	[Fax: @h:bookfax@](@h:booklink@)

	---
    }]]]
}

proc ::cm::conference::make_page_footer {} {
    debug.cm/conference {}
    # page-footer - TODO: Move text into a configurable template
    return [util undent {
	# Contact information

	[@c:contact@](mailto:@c:contact@)
    }]
}

proc ::cm::conference::make_overview {} {
    debug.cm/conference {}
    return [template use www-main]
}

proc ::cm::conference::make_callforpapers {} {
    return [template use www-cfp]
}

proc ::cm::conference::make_location {} {
    debug.cm/conference {}
    # make-location - TODO: Move text into a configurable template
    # make-location - TODO: switch to a different text block when deadline has passed.
    return [util undent {
	We have negotiated a reduced room rate for attendees of the
	conference, of @r:rate@ @r:currency@ per night from @r:begin@ to @r:end@.

	To register for a room at the hotel you can use phone (@h:bookphone@),
	fax (@h:bookfax@), or their [website](@h:booklink@).
	Be certain to mention that you are with the Tcl/Tk Conference to
	get the Tcl/Tk Conference room rate. Our coupon code is __@r:group@__.

	These rooms will be released to the general public after __@r:deadline@__,
	so be sure to reserve your room before.

	@h:transport@
    }]
}

proc ::cm::conference::registration-mode {conference} {
    debug.cm/conference {}
    return [get-rstatus [dict get [details $conference] xrstatus]]
}

proc ::cm::conference::make_registration_pending {} {
    debug.cm/conference {}
    return [util undent {
	While it is planned to open registration on @c:t:regopen@
	it may happen earlier.

	Please check back frequently, and/or nag us at the contact below.
    }]
}

proc ::cm::conference::make_registration_closed {} {
    debug.cm/conference {}
    return [util undent {
	__Registration online has closed.__
    }]
}

proc ::cm::conference::make_registration_paper {} {
    debug.cm/conference {}
    return [util undent {
	Thank you for joining us.

	* Please go to the [Online form](https://www.tcl.tk/community/tcl@c:year@/regForm.html) and fill in the data.
	* __Print__ the form from your browser, instead of submitting it electronically.
	* Either fax the print to 734-449-8467, or mail it (if paying by cheque) to the address below

	```
	Tcl Community Association
	8888 Black Pine Ln
	Whitmore Lake, MI 48189
	```
    }]
}

proc ::cm::conference::make_registration_open {} {
    debug.cm/conference {}
    return [util undent {
	## How to register

	You may register for the conference by

	* [Online form](https://www.tcl.tk/community/tcl@c:year@/regForm.html)
	* [Hardcopy Mail/Fax](register_paper.html)
	* At the door. 

	If you register in advance, You will receive a $100 discount
	over the at-the-door conference rate.

	You can register at the door when you arrive at the @h:hotel@.

	Registration will be open daily from 08:30 until 17:00. 

	## Pricing schedules and discounts

	All prices are in US$.

	[Technical Sessions](schedule.html) (Wednesday to Friday) registration includes:

	   * Access to all conference technical sessions
	   * Access to the evening BOFs and community meetings
	   * One set of proceedings on USB memory stick.
	   * Breakfast and morning and evening snack breaks 

	Each tutorial is one half-day session (3 hours instruction time + one break).
	Tutorials have limited space. Registration is on a first-come, first-serve basis.
	[Tutorial Sessions](tutorials.html) (Monday, Tuesday) registration includes:

	   * Access to all registered tutorial sessions
	   * Complete course handouts
	   * Snack break during the tutorial 

	|Conference Fees|Regular Price|
	|-|-|
	|Technical Sessions			| $395|
	|Tutorials ([see sliding scale below](#tp))	| $195 - $650|
	|Extra Proceedings (Memory sticks)	| $5 per|
	|Extra Proceedings (Printed paper)	| $20 per|
	|Walk-in registration			| Add $100 to your total fees|

	<a name='tp'></a>
	### Tutorial Pricing

	We are offering tutorials on a Cheaper-By-The-(one-third)Dozen schedule.
	Rather than a flat rate, the tutorials become cheaper as you learn more.

	|Number of Tutorials| 	List Price| 	Actual Cost| 	Savings| 	Percent|
	|-|-|-|-|-|
	|1 	|$195 	|$195 	|$0 	|0%|
	|2 	|$390 	|$350 	|$40 	|10.3%|
	|3 	|$585 	|$500 	|$85 	|14.5%|
	|4 	|$780 	|$650 	|$130 	|16.7%|

	### Special Discounts

	|||
	|-|-|
	|Full Time Student |Attending the Technical Sessions is free for students, with proof of status, a copy of your student ID and class schedule. Technical Sessions plus three Meals is $50|
	|Presenters	   |Deduct $100 from your total fees if you are presenting a paper|

	### Cancellation Policy

	If for any reason you need to cancel your registration, please email
	[@c:contact@](mailto:@c:contact@).

	Registration fees for cancellations received before July 1st will be
	refunded after a $100 processing charge has been deducted. 
    }]
}

proc ::cm::conference::make_tutorials_none {} {
    debug.cm/conference {}
    return [template use www-tutorials.none]
}

proc ::cm::conference::make_tutorials {conference} {
    debug.cm/conference {}

    set    text [template use www-tutorials]
    append text \n "# Tutorial schedule" \n\n

    lassign [cm::tutorial dayrange   $conference] daymin   daymax   daylast
    lassign [cm::tutorial trackrange $conference] trackmin trackmax tracklast

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

    # tutorial - TODO - future optimization: drop empty columns from the output - determine above during header generation, and skip below, on content generation.

    # Table content.
    # One row per day and track.
    # Day only named for the first track.

    # Iterate days
    for {set day $daymin} {$day < $daymax} {incr day} {
	set date  [clock add $start $day days]
	set wday  [hwday $date]
	#set date  [hdate $date]

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
		set tutorial [cm::tutorial cell $conference $day $half $track]

		if {$tutorial eq {}} {
		    append text |
		    continue
		}

		set tdetails [tutorial details $tutorial]
		set title    [dict get $tdetails xtitle]
		set desc     [dict get $tdetails xdescription]
		set req      [dict get $tdetails xprereq]

		set speaker  [dict get $tdetails xspeaker]
		set sdetails [contact details $speaker]
		set speaker  [dict get $sdetails xdname]
		set stag     [dict get $sdetails xtag]
		set tag      ${stag}:[dict get $tdetails xtag]

		append text "|\[$title\](\#$tag)"

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

    # --- Trouble with table and full-blown md in cells.
    # --- Using basic sections instead.
    # We use inlined html here to allow for markdown inside
    # NOTE: We need a macro for that. (templates/shortcuts.tcl)
    #   See <%%%>, and pagePrelude (www-wconf template)
    #append text <table>\n

    #append text "\#\# "
    db do eval {
	SELECT tutorial
	FROM   tutorial_schedule S,
	       tutorial T,
	       contact  C
	WHERE  S.conference = :conference
	AND    T.id         = S.tutorial
	AND    C.id         = T.speaker
	ORDER BY C.dname, T.title
    } {
	lassign [dict get $map $tutorial] title tag speaker stag desc req

	#append text "<tr><th>" "<a name='" $tag "'></a>" $title " (<a href='bios.html#" $stag "'>" $speaker "</a>)"
	append text "<a name='" $tag "'></a>\n\#\# " $title " &mdash; \[" $speaker "\](bios.html#" $stag ")\n\n"
	if {$req ne {}} {
	    #append text " &mdash; " $req
	    append text "__Required__: " $req \n\n
	}
	#append text "</th></tr>\n"
	#append text "<tr><td><%!md " [encode $desc] "%></td></tr>\n"
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

proc ::cm::conference::make_abstracts {} {
    # make-abstracts - TODO: Move text into a configurable template
    # make-abstracts - TODO: data driven on schedule data
    return [util undent {
	The paper abstracts will be finalized and put up after
	all the notifications to authors have been sent out on
	@c:t:authornote@, as part of creating the schedule.

	Please check back after.
    }]
}

proc ::cm::conference::make_speakers {} {
    # make-speakers - TODO: Move text into a configurable template
    # make-speakers - TODO: data driven on schedule data

    # tutorials, keynotes, general presenters.


    return [util undent {
	The list of speakers and their biographies will be finalized
	and put up after all the notifications to authors have been
	sent out on @c:t:authornote@, as part of creating the schedule.

	Please check back after.
    }]
}

proc ::cm::conference::make_contact {} {
    # No content, the information is in the footer.
    return
}

proc ::cm::conference::make_disclaimer {} {
    # make-abstracts - TODO: Move text into a configurable template
    return [util undent {
	This is the disclaimer and copyright.
    }]
}

proc ::cm::conference::make_proceedings {} {
    # make-proceedings - TODO: Move text into a configurable template
    # make-proceedings - TODO: flag/data controlled
    return [util undent {
	Our proceedings will be made public next year,
	as part of the next conference.

	Please check back.
    }]
}

proc ::cm::conference::make_sidebar {conference} {
    append sidebar <table>
    # -- styling makes the table too large -- append sidebar "<table class='table table-condensed'>"
    append sidebar "\n<tr><th colspan=2>" "Important Information &mdash; Timeline" </th></tr>
    #append sidebar <tr><td> "Email contact" </td><td> "<a href='mailto:@c:contact@'>" @c:contact@</a></td></tr>

    append sidebar [[table t {Event When} {
	$t style table/html
	$t noheader

	switch -exact -- [set m [registration-mode $conference]] {
	    pending {
		set sql [sidebar_reg_show]
	    }
	    open - closed {
		set r Registration
		if {$m eq "open"} { set r "<a href='register.html'>$r</a>" }
		append sidebar "\n<tr><th colspan=2>" "Registration is $m" </th></tr>
		set sql [sidebar_reg_excluded]
	    }
	}
	#append sidebar "\n<tr><td colspan=2><hr/></strong></td></tr>"
	db do eval $sql {
	    $t add "$text" [hdate $date]
	}
    }] show return]
    append sidebar </table>
    return [insert $conference $sidebar]
}

proc ::cm::conference::sidebar_reg_excluded {} {
    return {
	SELECT T.date AS date,
	       E.text AS text
	FROM   timeline      T,
	       timeline_type E
	WHERE T.con  = :conference
	AND   T.type = E.id
	AND   E.ispublic
	AND   E.key != 'regopen'
	ORDER BY T.date
    }
}

proc ::cm::conference::sidebar_reg_show {} {
    return {
	SELECT T.date AS date,
	       E.text AS text
	FROM   timeline      T,
	       timeline_type E
	WHERE T.con  = :conference
	AND   T.type = E.id
	AND   E.ispublic
	ORDER BY T.date
    }
}

proc ::cm::conference::have-tutorials {conference} {
    debug.cm/conference {}
    Setup

    return [db do exists {
	SELECT id
	FROM   tutorial_schedule
	WHERE  conference = :conference
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
		VALUES (NULL, :conference, :new, :id)
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
    +map @c:contact@         [contact get-email [dict get $details xsubmission]]
    +map @c:management@      [contact get-name $xmgmt]
    +map @c:management:link@ [contact get-the-link $xmgmt]
    +map @c:start@           [hdate $xstart]
    +map @c:end@             [hdate $xend]
    +map @c:when@            [when $xstart $xend]
    +map @c:talklength@      [dict get $details xtalklen]
    # NOTE: xsesslen == 'talks per session' ignored - not relevant in any page, so far.

    # City information

    +map @c:city@ [city get [dict get $details xcity]]

    # Hotel information.
    # insert - TODO: Facility information, and hotel != facility.

    set xhotel   [dict get $details xhotel]
    set hdetails [location details $xhotel]

    set xlocalphone [dict get $hdetails xlocalphone]
    set xlocalfax   [dict get $hdetails xlocalfax]
    set xlocallink  [dict get $hdetails xlocallink]
    set xbookphone  [dict get $hdetails xbookphone]
    set xbookfax    [dict get $hdetails xbookfax]
    set xbooklink   [dict get $hdetails xbooklink]

    +map @h:hotel@      [dict get $hdetails xname]
    +map @h:city@       [city get [dict get $hdetails xcity]]
    +map @h:street@     "[dict get $hdetails xstreet], [dict get $hdetails xzipcode]"
    +map @h:transport@  [dict get $hdetails xtransport]
    +map @h:bookphone@  [ifempty $xbookphone $xlocalphone]
    +map @h:bookfax@    [ifempty $xbookfax   $xlocalfax]
    +map @h:booklink@   [ifempty $xbooklink  $xlocallink]
    +map @h:localphone@ $xlocalphone
    +map @h:localfax@   $xlocalfax
    +map @h:locallink@  $xlocallink

    # Room rate information

    set rdetails [get-rate $id $xhotel]

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

	set link [contact get-the-link $sponsor]
	if {$link ne {}} {
	    set label "\[$label\]($link)"
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

	set link [contact get-the-link $sponsor]
	if {$link ne {}} {
	    set label "\[$label\]($link)"
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
	foreach {aid aname} [contact affiliated $contact] {
	    set alink [contact get-the-link $aid]
	    if {$alink ne {}} {
		set aname "\[$aname\]($alink)"
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

	foreach {aid aname} [contact affiliated $contact] {
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

proc ::cm::conference::ifempty {x y} {
    if {$x ne {}} { return $x }
    return $y
}

proc ::cm::conference::hdate {x} {
    clock format $x -format {%B %d, %Y}
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
    return [cm::contact::KnownLimited [db do eval {
	SELECT contact
	FROM   sponsors
	WHERE  conference = :conference
    }]]
}

proc ::cm::conference::known-sponsor-select {conference} {
    debug.cm/conference {}
    Setup

    if {($conference eq {}) ||
	($conference < 0)} {
	return {}
    }
    return [cm::contact::KnownSelectLimited [db do eval {
	SELECT contact
	FROM   sponsors
	WHERE  conference = :conference
    }]]
}

proc ::cm::conference::known-staff {} {
    debug.cm/conference {}
    Setup

    set conference [the-current]
    if {$conference < 0} {
	return {}
    }
    return [cm::contact::KnownLimited [db do eval {
	SELECT contact
	FROM   conference_staff
	WHERE  conference = :conference
    }]]
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

proc ::cm::conference::known-staff-role {} {
    debug.cm/conference {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   staff_role
    } {
	dict set known $text $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::known-rstatus {} {
    debug.cm/conference {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   rstatus
    } {
	dict set known $text $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::issues {details} {
    debug.cm/conference {}
    dict with details {}

    set issues {}

    foreach {var message} {
	xcity     "Location is not known"
	xhotel    "Hotel is not known"
	xfacility "Facility is not known"
	xstart    "Start date is not known"
	xend      "End date is not known"
    } {
	if {[set $var] ne {}} continue
	+issue $message
    }

    if {![db do exists {
	SELECT id
	FROM   timeline
	WHERE con = :xconference
    }]} {
	+issue "Undefined timeline"
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

    if {![llength $issues]} return
    return [join $issues \n]
}

proc ::cm::conference::+issue {text} {
    debug.cm/conference {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
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
	       'xrstatus',    rstatus
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
	puts [color bad "No conference chosen, please \"select\" a conference"]
	::exit 0
    }
    if {[has $id]} { return $id }

    puts [color bad "Bad conference index, please \"select\" a conference"]
    ::exit 0
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

proc ::cm::conference::select-staff-role {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set staff   [known-staff-role]
    set choices [lsort -dict [dict keys $staff]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $staff 1]
	}
    }

    set choice [ask menu "" "Which staff role: " $choices]

    # Map back to id
    return [dict get $staff $choice]
}

proc ::cm::conference::get-role {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT text
	FROM   staff_role
	WHERE  id = :id
    }]
}

proc ::cm::conference::get-rstatus {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT text
	FROM   rstatus
	WHERE  id = :id
    }]
}

proc ::cm::conference::known-timeline {} {
    debug.cm/conference {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, text
	FROM   timeline_type
    } {
	dict set known $text $id
    }

    debug.cm/conference {==> ($known)}
    return $known
}

proc ::cm::conference::select-timeline {p} {
    debug.cm/conference {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set entries [known-timeline]
    set choices [lsort -dict [dict keys $entries]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $entries 1]
	}
    }

    set choice [ask menu "" "Which timeline entry: " $choices]

    # Map back to id
    return [dict get $entries $choice]
}

proc ::cm::conference::get-timeline {id} {
    debug.cm/conference {}
    Setup

    return [db do onecolumn {
	SELECT text
	FROM   timeline_type
	WHERE  id = :id
    }]
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

# # ## ### ##### ######## ############# ######################

proc ::cm::conference::Setup {} {
    debug.cm/conference {}

    ::cm::config::core::Setup
    ::cm::city::Setup
    ::cm::location::Setup
    ::cm::contact::Setup

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
	    rstatus	INTEGER NOT NULL REFERENCES rstatus

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
	    type INTEGER NOT NULL REFERENCES timeline_type
	} {
	    {id   INTEGER 1 {} 1}
	    {con  INTEGER 1 {} 0}
	    {date INTEGER 1 {} 0}
	    {type INTEGER 1 {} 0}
	} {con}
    }]} {
	db setup-error timeline $error
    }

    if {![dbutil initialize-schema ::cm::db::do error timeline_type {
	{
	    -- The possible types of action items in the conference timeline
	    -- public items are for use within mailings, the website, etc.
	    -- internal items are for the mgmt only.
	    -- the offset [in days] is used to compute the initial proposal
	    -- of a timeline for the conference. 

	    id		INTEGER NOT NULL PRIMARY KEY,
	    ispublic	INTEGER NOT NULL,
	    offset	INTEGER NOT NULL,	-- >0 => days after conference start
	    					-- <0 => days before start
	    key		TEXT    NOT NULL UNIQUE,	-- internal key for the type
	    text	TEXT    NOT NULL UNIQUE		-- human-readable
	} {
	    {id		INTEGER 1 {} 1}
	    {ispublic	INTEGER 1 {} 0}
	    {offset	INTEGER 1 {} 0}
	    {key	TEXT    1 {} 0}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error timeline_type $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO timeline_type VALUES ( 1,0,-196,'cfp1',      '1st Call for papers');         --  -28w (--)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 2,0,-140,'cfp2',      '2nd Call for papers');         --  -20w (8w) (~2m)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 3,0, -84,'cfp3',      '3rd Call for papers');         --  -12w (8w) (~2m)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 4,1, -84,'wipopen',   'WIP & BOF Reservations open'); --  -12w
	    INSERT OR IGNORE INTO timeline_type VALUES ( 5,1, -56,'submitdead','Submissions due');             --   -8w (4w) (~1m)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 6,1, -56,'regopen',   'Registration opens');          --   -8w same
	    INSERT OR IGNORE INTO timeline_type VALUES ( 7,1, -49,'authornote','Notifications to Authors');    --   -7w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 8,1, -21,'writedead', 'Author Materials due');        --   -3w (4w)+1w grace
	    INSERT OR IGNORE INTO timeline_type VALUES ( 9,0, -14,'procedit',  'Edit proceedings');            --   -2w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES (10,0,  -7,'procship',  'Ship proceedings');            --   -1w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES (11,1,   0,'begin-t',   'Tutorial Start');              --  <=>
	    INSERT OR IGNORE INTO timeline_type VALUES (12,1,   2,'begin-s',   'Session Start');               --  +2d
	}
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

    if {![dbutil initialize-schema ::cm::db::do error staff_role {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    text	TEXT	NOT NULL UNIQUE	-- chair, facilities chair, program chair, program committee,
						-- web admin, proceedings editor, hotel liason, ...
	} {
	    {id		INTEGER 1 {} 1}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error staff_role $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO staff_role VALUES (1,'Chair');
	    INSERT OR IGNORE INTO staff_role VALUES (2,'Facilities chair');
	    INSERT OR IGNORE INTO staff_role VALUES (3,'Program chair');
	    INSERT OR IGNORE INTO staff_role VALUES (4,'Program committee');
	    INSERT OR IGNORE INTO staff_role VALUES (5,'Hotel liaison');
	    INSERT OR IGNORE INTO staff_role VALUES (6,'Web admin');
	    INSERT OR IGNORE INTO staff_role VALUES (7,'Proceedings editor');
	}
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

    if {![dbutil initialize-schema ::cm::db::do error rstatus {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    text	TEXT	NOT NULL UNIQUE
	} {
	    {id		INTEGER 1 {} 1}
	    {text	TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error rstatus $error
    } else {
	db do eval {
	    INSERT OR IGNORE INTO rstatus VALUES (1,'pending');
	    INSERT OR IGNORE INTO rstatus VALUES (2,'open');
	    INSERT OR IGNORE INTO rstatus VALUES (3,'closed');
	}
    }

    # Shortcircuit further calls
    proc ::cm::conference::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::conference 0
return
