## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::mailgen 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require struct::matrix
package require textutil::adjust
package require clock::iso8601
package require http
package require html ;# We peek into the insides, using the entities variable.

debug level  cm/mailgen
debug prefix cm/mailgen {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export mailgen
    namespace ensemble create
}
namespace eval ::cm::mailgen {
    namespace export testmail call
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## The generator commands match the artifact types, not the
## timeline event types. For attachments we have a context
## which tells the type of change artifact (ticket, wiki, event)
## to configure the mail in detail.

proc ::cm::mailgen::testmail {sender header footer} {
    debug.cm/mailgen {}
    Begin
    Headers \
	"CM mail configuration test mail" \
	[clock seconds]
    Body $sender $header
    + "Testing ... 1, 2, 3 ..."
    Done $sender $footer
}

proc ::cm::mailgen::call {sender name text} {
    debug.cm/mailgen {}

    # First line is the subject header.
    # Remainder is body.
    #
    # Note: Conference specific information has already been inserted
    # into the text.

    set body [join [lassign [split $text \n] subject] \n]

    lappend map @mg:sender@ $sender
    lappend map @mg:name@   $name

    debug.cm/mailgen {}
    Begin
    Headers [string map $map $subject] [clock seconds]
    Body    $sender {}
    +       [string map $map $body]
    Done    $sender {}
}

# # ## ### ##### ######## ############# ######################

proc ::cm::mailgen::limit {n text {suffix ...}} {
    if {($n > 0) && ([string length $text]) > $n} {
	set text [string range $text 0 $n]$suffix
    }
    return $text
}

# # ## ### ##### ######## ############# ######################

proc ::cm::mailgen::Begin {} {
    upvar 1 lines lines
    set     lines {}
    return
}

proc ::cm::mailgen::Done {sender footer} {
    upvar 1 lines lines T T
    catch { $T destroy }

    if {$footer ne {}} {
	# separate footer from mail body
	lappend map @sender@ $sender
	lappend map @sender  $sender
	lappend map @cmd@    [file tail $::argv0]

	+ ""
	+ [string repeat - 60]
	+ [string map $map $footer]
	+ [string repeat - 60]
    }

    + ""
    return -code return [join $lines \n]
}

proc ::cm::mailgen::+T {field value} {
    upvar 1 T T
    variable flimit
    variable flsuffix
    set value [limit $flimit $value $flsuffix]

    if {![info exists T]} {
	# Note: Even without T a TABLE instance may be left over from
	# a previous generator call which failed with an error and
	# thus did not clean up properly.
	catch { TABLE destroy }
	set T [struct::matrix TABLE]
	$T add columns 2
    }
    $T add row [list $field $value]
    return
}

proc ::cm::mailgen::=T {} {
    upvar 1 T T lines lines
    if {![info exists T]} return

    if {[$T rows]} {
	+ [textutil::adjust::indent [$T format 2string] {  }]
    }
    $T destroy
    unset T
    return
}

proc ::cm::mailgen::+ {line} {
    upvar 1 lines lines
    lappend lines [Unentify $line]
    return
}

proc ::cm::mailgen::Subject {{prefix {}}} {
    upvar 1 project project ecomment ecomment
    # Strip html tags out of the ecomment, bad for the mail.
    regsub -all {<([^>]+)>} $ecomment {} ecomment
    # Reduce to first line.
    set subj [lindex [split $ecomment \n] 0]
    return "\[$project\] $prefix$subj"
}

proc ::cm::mailgen::Unentify {text} {
    # Convert HTML artifacts (entities) into regular characters.
    variable emap
    return [string map $emap $text]
}

proc ::cm::mailgen::Headers {subject epoch} {
    set date  [clock format $epoch -format {%d %b %Y %H:%M:%S %z}]

    upvar 1 lines lines
    + "Subject: $subject"
    + "Date:    $date"
    + "X-CM-Note:"
    + "X-Tool-Origin: http://core.tcl.tk/akupries/cm" ; # TODO make this ready
    return
}

proc ::cm::mailgen::Body {sender header} {
    upvar 1 lines lines
    + ""
    if {$header ne {}} {
	lappend map @sender@ $sender
	lappend map @sender  $sender
	lappend map @cmd@    [file tail $::argv0]
	+ [string map $map $header]
	+ ""
    }
    return
}

proc ::cm::mailgen::Reformat {s} {
    # split into paragraphs. may contain sequences of
    # empty paragraphs.
    set paragraphs {}
    set p {}
    foreach l [split $s \n] {
	if {[string trim $l] eq {}} {
	    lappend paragraphs $p
	    set p {}
	} else {
	    append p $l\n
	}
    }
    lappend paragraphs $p

    # format paragraphs, ignoring empty ones.
    set s {}
    foreach p $paragraphs {
	if {$p eq {}} continue
	append s [textutil::adjust::adjust $p \
		      -strictlength 1 \
		      -length       70] \n\n
    }

    # done
    return [string trimright $s]
}

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::mailgen {
    # Limit for table fields in generated mail, and
    # Limit marker to use when truncating.
    # TODO: Make the limits configurable
    variable flimit   2048
    variable flsuffix "\n...((truncated))"
    variable context  {}
    variable emap     {}
}

apply {{} {
    # Invert the mapping from chars to entities
    variable emap {}
    variable ::html::entities
    foreach {c e} $entities {
	lappend emap $e $c
    }
} ::cm::mailgen}

# # ## ### ##### ######## ############# ######################
package provide cm::mailgen 0
return
