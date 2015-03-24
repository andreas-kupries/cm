## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::tutorial 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta tutorial    http:/core.tcl.tk/akupries/cm
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
package require struct::list

package require cm::contact
package require cm::db
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export tutorial
    namespace ensemble create
}
namespace eval ::cm::tutorial {
    namespace export \
	cmd_create cmd_list cmd_show \
	known known-tag known-title get details select
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::contact
    namespace import ::cm::util

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/tutorial
debug prefix cm/tutorial {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::tutorial::cmd_list {config} {
    debug.cm/tutorial {}
    Setup
    db show-location

    [table t {Speaker Tag Note Title} {
	db do eval {
	    SELECT C.dname     AS speaker,
	           C.tag       AS stag,
	           C.biography AS sbio,
	           T.tag       AS tag,
	           T.title     AS title
	    FROM   tutorial T,
	           contact  C
	    WHERE  C.id = T.speaker
	    ORDER BY C.dname, T.title
	} {
	    set notes {}
	    if {$stag eq {}} { lappend notes [color bad {No speaker tag}] }
	    if {$sbio eq {}} { lappend notes [color bad {No speaker biography}] }

	    $t add $speaker @${stag}_$tag [join $notes \n] $title
	}
    }] show
    return
}

proc ::cm::tutorial::cmd_create {config} {
    debug.cm/tutorial {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set prereq      [$config @requisites]
    set description [$config @description]
    set speaker     [$config @speaker]
    set tag         [$config @tag]
    set title       [$config @title]

    puts -nonewline "Creating \"[color name [contact get $speaker]]\" tutorial \"[color name $title]\" ... "

    try {
	db do transaction {
	    db do eval {
		INSERT INTO tutorial
		VALUES (NULL, :speaker, :tag, :title, :prereq, :description)
	    }
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

proc ::cm::tutorial::cmd_show {config} {
    debug.cm/tutorial {}
    Setup
    db show-location

    set tutorial [$config @name]
    set details  [details $tutorial]

    dict with details {}

    set w [util tspace [expr {[string length Description]+7}] 60]
    set xspeaker [contact get $xspeaker]

    puts "Details of [color name $xspeaker]'s tutorial \"[color name [get $tutorial]]\":"
    [table t {Property Value} {
	set issues [issues $details]
	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
	    $t add -------- -----
	}

	$t add Speaker      [color name $xspeaker]
	$t add Tag          $xtag
	$t add Title        $xtitle
	$t add Requisites   [util adjust $w $xprereq]
	$t add Description  [util adjust $w $xdescription]
    }] show
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::cm::tutorial::issues {details} {
    debug.cm/tutorial {}
    dict with details {}

    set sdetails [contact details $xspeaker]

    set issues {}
    if {[dict get $sdetails xtag]       eq {}} { +issue "Speaker tag missing" }
    if {[dict get $sdetails xbiography] eq {}} { +issue "Speaker biography missing" }

    if {[llength $issues]} {
	set issues [join $issues \n]
    }
    return $issues
}

proc ::cm::tutorial::+issue {text} {
    debug.cm/tutorial {}
    upvar 1 issues issues
    lappend issues "- [color bad $text]"
    return
}

proc ::cm::tutorial::select {p} {
    debug.cm/tutorial {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # dict: label -> id
    set tutorials [known-select]
    set choices   [lsort -dict [dict keys $tutorials]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $tutorials 1]
	}
    }

    set choice [ask menu "" "Which tutorial: " $choices]

    # Map back to id
    return [dict get $tutorials $choice]
}

proc ::cm::tutorial::known-select {} {
    debug.cm/contact {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	    SELECT T.id    AS id,
	           C.dname AS speaker,
	           C.tag   AS stag,
	           T.tag   AS tag,
	           T.title AS title
	    FROM   tutorial T,
	           contact  C
	    WHERE  C.id = T.speaker
    } {
	set key "(@${stag}_$tag) $speaker: $title"
	dict set known $key $id
    }

    return $known

}

proc ::cm::tutorial::known-tag {speaker} {
    debug.cm/tutorial {}
    Setup

    set known {}

    db do eval {
	SELECT id, tag
	FROM   tutorial
	WHERE  speaker = :speaker
    } {
	dict set known $tag $id
    }

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::known-title {speaker} {
    debug.cm/tutorial {}
    Setup

    set known {}

    db do eval {
	SELECT id, title
	FROM   tutorial
	WHERE  speaker = :speaker
    } {
	dict set known $title $id
    }

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::known {} {
    debug.cm/tutorial {}
    Setup

    # For validation.
    # See also contact.tcl for similar (helper) code.

    set map {}
    # dict: id -> labels. Will be inverted later.

    db do eval {
	SELECT T.id    AS id,
	       C.dname AS speaker,
	       C.tag   AS stag,
	       T.tag   AS tag, 
	       T.title AS title
	FROM  tutorial T,
	      contact  C
	WHERE C.id = T.speaker
    } {
	dict lappend map $id @${stag}_$tag
	dict lappend map $id $title
    }

    # Rekey by names
    set map [Invert $map]

    # Extend with key permutations which do not clash
    dict for {k vlist} $map {
	foreach p [struct::list permutations [split $k]] {
	    set p [join $p]
	    if {[dict exists $map $p]} continue
	    dict set map $p $vlist
	}
    }

    set known [DropAmbiguous $map]

    debug.cm/tutorial {==> ($known)}
    return $known
}

proc ::cm::tutorial::Invert {dict} {
    # invert TODO - coalesce with code in contact
    debug.cm/tutorial {}

    set r {}
    # Invert
    dict for {k vlist} $dict {
	foreach v $vlist {
	    dict lappend r $v $k
	}
    }
    # Drop duplicates
    dict for {k list} $r {
	dict set r $k [lsort -unique $list]
    }
    return $r
}

proc ::cm::tutorial::DropAmbiguous {dict} {
    # drop-ambiguous TODO - coalesce with code in contact
    debug.cm/tutorial {}

    dict for {k vlist} $dict {
	if {[llength $vlist] == 1} {
	    dict set dict $k [lindex $vlist 0]
	    continue
	}
	dict unset dict $k
    }
    return $dict
}

proc ::cm::tutorial::get {id} {
    debug.cm/tutorial {}
    Setup

    return [db do eval {
	SELECT title
	FROM  tutorial
	WHERE id = :id
    }]
}

proc ::cm::tutorial::details {id} {
    debug.cm/tutorial {}
    Setup

    set details [db do eval {
	SELECT 'xspeaker',     speaker,
               'xtag',         tag,
	       'xtitle',       title,
	       'xprereq',      prereq,
	       'xdescription', description
	FROM  tutorial
	WHERE id = :id
    }]

    return $details
}

proc ::cm::tutorial::write {id details} {
    debug.cm/tutorial {}
    Setup

    dict with details {}

    db do eval {
	UPDATE tutorial
	SET    speaker     = :xspeaker,
	       tag         = :xtag,
	       title       = :xtitle,
	       prereq      = :xprereq,
	       description = :xdescription
	WHERE id = :id
    }
}

# # ## ### ##### ######## ############# ######################

proc ::cm::tutorial::Setup {} {
    debug.cm/tutorial {}

    ::cm::contact::Setup

    if {![dbutil initialize-schema ::cm::db::do error tutorial {
	{
	    id		INTEGER	NOT NULL PRIMARY KEY AUTOINCREMENT,
	    speaker	INTEGER	NOT NULL REFERENCES contact,	-- can_register||can_book||can_talk
	    tag		TEXT	NOT NULL,			-- for html anchors
	    title	TEXT	NOT NULL,
	    prereq	TEXT,
	    description	TEXT	NOT NULL,
	    UNIQUE (speaker, tag),
	    UNIQUE (speaker, title)
	} {
	    {id			INTEGER 1 {} 1}
	    {speaker		INTEGER 1 {} 0}
	    {tag		TEXT    1 {} 0}
	    {title		TEXT    1 {} 0}
	    {prereq		TEXT    0 {} 0}
	    {description	TEXT	1 {} 0}
	} {}
    }]} {
	db setup-error tutorial $error
    }

    # Shortcircuit further calls
    proc ::cm::tutorial::Setup {args} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::tutorial 0
return
