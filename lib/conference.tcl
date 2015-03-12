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
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export conference
    namespace ensemble create
}
namespace eval ::cm::conference {
    namespace export \
	cmd_create cmd_list cmd_select cmd_show cmd_facility cmd_hotel \
	cmd_timeline_init cmd_timeline_clear cmd_timeline_show \
	cmd_timeline_shift cmd_sponsor_show cmd_sponsor_link cmd_sponsor_unlink \
	cmd_staff_show cmd_staff_link cmd_staff_unlink cmd_rate_set \
	select label current get insert known-sponsor cmd_rate_show \
	select-sponsor select-staff-role select-staff known-staff \
	get-role select-timeline get-timeline
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cmdr::validate::date
    namespace import ::cmdr::validate::weekday
    namespace import ::cm::city
    namespace import ::cm::contact
    namespace import ::cm::db
    namespace import ::cm::location
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

	if {$xcity     ne {}} { set xcity     [city  get $xcity] }
	if {$xhotel    ne {}} { set xhotel    [location get $xhotel] }
	if {$xfacility ne {}} { set xfacility [location get $xfacility] }

	$t add Year          $xyear
	$t add Start         $xstart
	$t add End           $xend
	$t add Aligned       $xalign
	$t add Days          $xlength
	$t add {} {}
	$t add In            $xcity
	$t add @Hotel        $xhotel
	$t add @Facility     $xfacility
	$t add {} {}
	$t add Minutes/Talk  $xtalklen
	$t add Talks/Session $xsesslen

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
	db do eval {
	    SELECT T.date AS date,
	           E.text AS text
	    FROM   timeline      T,
	           timeline_type E
	    WHERE T.con  = :conference
	    AND   T.type = E.id
	    ORDER BY T.date
	} {
	    $t add "$text" [hdate $date]
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

proc ::cm::conference::cmd_sponsor_show {config} {
    debug.cm/conference {}
    Setup
    db show-location

    set conference [current]

    puts "Sponsors of \"[color name [get $conference]]\":"
    [table t {Sponsor} {
	# TODO: sponsors - mail/link/notes ?
	db do eval {
	    SELECT C.dname AS name
	    FROM   sponsors S,
	           contact  C
	    WHERE  S.conference = :conference
	    AND    S.contact    = C.id
	    ORDER BY C.dname
	} {
	    $t add $name
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


# # ## ### ##### ######## ############# ######################
## Internal import support commands.

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
    dict with details {}
    set xtitle [get $id]

    set clabel [city get $xcity]

    set hotel  [location details $xhotel]
    dict with hotel {} ;# overwrites conference city
    set hclabel [city get $xcity]

    # con-insert TODO - hotel != facilities

    #array set _ $details ; parray _ ; unset _
    #array set _ $hotel ; parray _ ; unset _

    set sponsors [join [lsort -dict [dict keys [known-sponsor-select $id]]] \n]
    set sponsors [util indent $sponsors "   * "]

    # Staff names, roles and affiliations, limit to the committee
    set cdata  [committee $id]
    set cnames [lsort -dict [dict keys $cdata]]
    set committee {}
    foreach c $cnames clabel [util padr $cnames] {
	set contact [dict get $cdata $c]
	set contact [contact details $contact]

	#debug.cm/conference {c.member = ($contact)}
	#debug.cm/conference {[util indent [debug pdict $contact] "  "]}

	set a [dict get $contact xaffiliation]
	if {$a ne {}} {
	    set a [contact get-name $a]
	    append clabel " " $a
	}
	lappend committee [string trim $clabel]
    }
    set committee [util indent [join $committee \n] "   * "]

    # Needs:
    # - conference information
    #   - year
    #   - title
    #   - start-date
    #   - end-end
    #   - timeline
    #   - location-references
    #     - location info (phone, fax, link)
    #   - sponsors
    #   - comittee
    #
    # --> insertion into template

    lappend map @h:hotel@      $xname
    lappend map @h:city@       $hclabel
    lappend map @h:street@     "$xstreet, $xzipcode"
    lappend map @h:transport@  $xtransport

    lappend map @h:bookphone   [ifempty $xbookphone $xlocalphone]
    lappend map @h:bookfax     [ifempty $xbookfax   $xlocalfax]
    lappend map @h:booklink    [ifempty $xbooklink  $xlocallink]

    lappend map @h:localphone  $xlocalphone
    lappend map @h:localfax    $xlocalfax
    lappend map @h:locallink   $xlocallink

    lappend map @c:name@       $xtitle
    lappend map @c:city@       $clabel
    lappend map @c:year@       $xyear
    lappend map @c:start@      [hdate $xstart]
    lappend map @c:end@        [hdate $xend]
    lappend map @c:when@       [when $xstart $xend]
    lappend map @c:contact@    tclconference@googlegroups.com ;# TODO configurable
    lappend map @c:sponsors@   $sponsors
    lappend map @c:committee@  $committee
    lappend map @c:talklength@ $xtalklen

    db do eval {
	SELECT E.key  AS key,
	       T.date AS date
	FROM   timeline      T,
	       timeline_type E
	WHERE  T.type = E.id
	AND    E.ispublic
	AND    T.con = :id
    } {
	lappend map @c:t:${key}@ [hdate $date]
    }

    set text [string map $map $text]
    return $text
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
	SELECT "xconference", id,
	       "xyear",       year,
	       "xcity",       city,
	       "xhotel",      hotel,
	       "xfacility",   facility,
	       "xstart",      startdate,
	       "xend",        enddate,
	       "xalign",      alignment,
	       "xlength",     length,
	       "xtalklen",    talklength,
	       "xsesslen",    sessionlen
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
	       city       = :xcity,
	       hotel      = :xhotel,
	       facility   = :xfacility,
	       startdate  = :xstart,
	       enddate    = :xend,
	       alignment  = :xalign,
	       length     = :xlength,
	       talklength = :xtalklen,
	       sessionlen = :xsesslen
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

	    city	INTEGER REFERENCES city,
	    hotel	INTEGER REFERENCES location, -- We do not immediately know where we will be
	    facility	INTEGER REFERENCES location, -- While sessions are usually at the hotel, they may not be.

	    startdate	INTEGER,		-- [*], date [epoch]
	    enddate	INTEGER,		--	date [epoch]
	    alignment	INTEGER NOT NULL,	-- iso8601 weekday (1:mon...7:sun), or -1 (no alignment)
	    length	INTEGER NOT NULL,	-- length in days

	    talklength	INTEGER NOT NULL,	-- minutes	  here we configure
	    sessionlen	INTEGER NOT NULL	-- in #talks max  basic scheduling parameters.
						-- 		  shorter talks => longer sessions.
						-- 		  standard: 30 min x3

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
	    {city		INTEGER 0 {} 0}
	    {hotel		INTEGER 0 {} 0}
	    {facility		INTEGER 0 {} 0}
	    {startdate		INTEGER	0 {} 0}
	    {enddate		INTEGER	0 {} 0}
	    {alignment		INTEGER	1 {} 0}
	    {length		INTEGER	1 {} 0}
	    {talklength		INTEGER	1 {} 0}
	    {sessionlen		INTEGER	1 {} 0}
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
	    INSERT OR IGNORE INTO timeline_type VALUES ( 6,1, -49,'authornote','Notifications to Authors');    --   -7w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 7,1, -21,'writedead', 'Author Materials due');        --   -3w (4w)+1w grace
	    INSERT OR IGNORE INTO timeline_type VALUES ( 8,0, -14,'procedit',  'Edit proceedings');            --   -2w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES ( 9,0,  -7,'procship',  'Ship proceedings');            --   -1w (1w)
	    INSERT OR IGNORE INTO timeline_type VALUES (10,1,   0,'begin-t',   'Tutorial Start');              --  <=>
	    INSERT OR IGNORE INTO timeline_type VALUES (11,1,   2,'begin-s',   'Session Start');               --  +2d
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

    # Shortcircuit further calls
    proc ::cm::conference::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::conference 0
return
