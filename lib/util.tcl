## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## CM - Util - General utilities
## Notes
## - Snarfed from Cmdr.


# @@ Meta Begin
# Package cm::util 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/cm
# Meta platform tcl
# Meta summary     Internal. General utilities.
# Meta description Internal. General utilities.
# Meta subject {command line}
# Meta require {Tcl 8.5-}
# Meta require textutil::adjust
# Meta require debug
# Meta require debug::caller
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::ask
package require cmdr::color
package require cmdr::validate::common
package require debug
package require debug::caller
package require linenoise
package require struct::list
package require textutil::adjust

package require cm::table

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export util
    namespace ensemble create
}

namespace eval ::cm::util {
    namespace export padr padl dictsort reflow indent undent \
	max-length strip-prefix open user-error highlight-current \
	tspace adjust dict-invert dict-drop-ambiguous dict-fill-permute \
	dict-fill-permute* dict-join-keys initials select text-stdin \
	match-substr match-enum fmt-issues-cli fmt-issues-web pdict
    namespace ensemble create

    namespace import ::cmdr::ask
    namespace import ::cmdr::color
    namespace import ::cmdr::validate::common::complete-substr
    namespace import ::cmdr::validate::common::complete-enum

    namespace import ::cm::table::dict
    rename dict table/d
}

# # ## ### ##### ######## ############# #####################

debug define cm/util
debug level  cm/util
debug prefix cm/util {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::cm::util::pdict {dict} {
    debug.cm/util {}
    [table/d t {
	foreach k [lsort -dict [dict keys $dict]] {
	    set v [dict get $dict $k]
	    $t add $k $v
	}
    }] show
    return
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::fmt-issues-web {issues} {
    debug.cm/util {}
    set result {}
    foreach issue $issues {
	lappend result "* $issue"
    }
    return [join $result \n]
}

proc ::cm::util::fmt-issues-cli {issues} {
    debug.cm/util {}
    set result {}
    foreach issue $issues {
	lappend result "- [color bad $issue]"
    }
    return [join $result \n]
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::text-stdin {config attr} {
    debug.cm/util {}

    if {![$config $attr set?]} {
	puts {Reading stdin...}
	return [read stdin]
    } else {
	return [$config $attr]
    }
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::select {p label mapcmd} {
    debug.cm/util {}

    if {![cmdr interactive?]} {
	$p undefined!
    }

    # map: label -> id
    set map     [uplevel 1 $mapcmd]
    set choices [lsort -dict [dict keys $map]]

    switch -exact [llength $choices] {
	0 { $p undefined! }
	1 {
	    # Single choice, return
	    # TODO: print note about single choice
	    return [lindex $map 1]
	}
    }

    set choice [ask menu "" "Which ${label}: " $choices]

    return [dict get $map $choice]
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::match-substr {iv known nocase x} {
    debug.cm/util {}

    upvar 1 $iv id

    if {($nocase eq "nocase") || $nocase} { set x [string tolower $x] }

    # Check for exact match first, this trumps substring matching,
    # especially if substring matching would be ambiguous.
    if {[dict exists $known $x]} {
	set id [dict get $known $x]
	return ok
    }

    # Check for substring matches. Convert to ids and deplicate before
    # deciding if the mismatch was due to ambiguity of the input.

    set matches [complete-substr [dict keys $known] $nocase $x]
    set n [llength $matches]
    if {!$n} {
	return fail
    }

    set ids {}
    foreach m $matches {
	lappend ids [dict get $known $m]
    }
    set ids [lsort -unique $ids]
    set n [llength $ids]

    if {$n > 1} {
	return ambiguous
    }

    # Uniquely identified, success
    set id [lindex $ids 0]
    return ok
}

proc ::cm::util::match-enum {iv known nocase x} {
    debug.cm/util {}

    upvar 1 $iv id

    if {($nocase eq "nocase") || $nocase} { set x [string tolower $x] }

    # Check for exact match first, this trumps prefix matching,
    # especially if prefix matching would be ambigous.
    if {[dict exists $known $x]} {
	set id [dict get $known $x]
	return ok
    }

    # Check for prefix matches. Convert to ids and deplicate before
    # deciding if the mismatch was due to ambiguity of the input.

    set matches [complete-enum [dict keys $known] $nocase $x]
    set n [llength $matches]
    if {!$n} {
	return fail
    }

    set ids {}
    foreach m $matches {
	lappend ids [dict get $known $m]
    }
    set ids [lsort -unique $ids]
    set n [llength $ids]

    if {$n > 1} {
	return ambiguous
    }

    # Uniquely identified, success
    set id [lindex $ids 0]
    return ok
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::tspace {sub {tmax -1}} {
    debug.cm/util {}

    set max [linenoise columns]
    incr max -$sub
    if {$max < 0} {
	set max 10
    }
    if {($tmax > 0) &&
	($max > $tmax)} {
	set max $tmax
    }
    return $max
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::highlight-current {xvar id args} {
    debug.cm/util {}
    upvar 1 $xvar cid [lindex $args 0] current
    if {$cid != $id} {
	set current {}
	return 
    }
    set current ->
    foreach v $args {
	upvar 1 $v str
	set str [color bold $str]
    }
    return
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::user-error {msg args} {
    debug.cm/util {}
    return -code error -errorcode [list CM USER {*}$args] $msg
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::dict-invert {dict} {
    debug.cm/util {}

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

proc ::cm::util::dict-drop-ambiguous {dict} {
    debug.cm/util {}

    dict for {k vlist} $dict {
	if {[llength $vlist] == 1} {
	    dict set dict $k [lindex $vlist 0]
	    continue
	}
	dict unset dict $k
    }
    return $dict
}

proc ::cm::util::dict-fill-permute {dict} {
    debug.cm/util {}

    # Extend with key permutations which do not clash
    dict for {k vlist} $dict {
	foreach p [struct::list permutations $k] {
	    if {[dict exists $dict $p]} continue
	    dict set dict $p $vlist
	}
    }

    return $dict
}

proc ::cm::util::dict-fill-permute* {dict} {
    debug.cm/util {}

    # Extend with key permutations which do not clash
    dict for {k vlist} $dict {
	foreach p [struct::list permutations [split $k]] {
	    set p [join $p]
	    if {[dict exists $dict $p]} continue
	    dict set dict $p $vlist
	}
    }

    return $dict
}

proc ::cm::util::dict-join-keys {dict {separator { }}} {
    debug.cm/util {}

    # Rewrite the dict keys (assumed to be lists) into plain strings
    # to squash Tcl list syntax.

    set r {}
    dict for {k v} $dict {
	dict set r [join $k $separator] $v
    }
    return $r
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::initials {text} {
    debug.cm/util {}

    set r {}
    foreach w [split $text] {
	append r [string toupper [string index $w 0]]
    }
    return $r
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::strip-prefix {prefix words} {
    # DANGER: A prefix containing glob/regex meta characters will not
    # work properly (unwanted matches, missing matches, bad removal).
    set results {}
    foreach w $words {
	if {![string match ${prefix}* $w]} continue
	regsub ^${prefix} $w {} w
	lappend results $w
    }
    return $results
}

proc ::cm::util::padr {words} {
    debug.cm/util {}
    if {[llength $words] <= 1} {
	return $words
    }
    set maxl [max-length $words]
    set res {}
    foreach str $words { lappend res [format "%-*s" $maxl $str] }
    return $res
}

proc ::cm::util::padl {words} {
    debug.cm/util {}
    if {[llength $words] <= 1} {
	return $words
    }
    set maxl [max-length $words]
    set res {}
    foreach str $words { lappend res [format "%*s" $maxl $str] }
    return $res
}

proc ::cm::util::dictsort {dict} {
    debug.cm/util {}

    set r {}
    foreach k [lsort -dict [dict keys $dict]] {
	lappend r $k [dict get $dict $k]
    }
    return $r
}

proc ::cm::util::adjust {width text} {
    # 1. split text into paragraphs separated by empty lines.
    # 2. Adjust each paragraph separately.
    # 3. Rejoin into whole text.
    set para {}
    set buf  {}
    foreach line [split $text \n] {
	if {[string trim $line] eq {}} {
	    if {$buf ne {}} {
		set buf [textutil::adjust::adjust $buf -length $width]
		lappend para $buf
	    }
	    set buf {}
	} else {
	    append buf \n$line
	}
    }
    if {$buf ne {}} {
	set buf [textutil::adjust::adjust $buf -length $width]
	lappend para $buf
    }
    return [join $para \n\n]
}

proc ::cm::util::reflow {text {prefix {    }}} {
    return [indent [undent [string trim $text \n]] $prefix]
}

proc ::cm::util::indent {text prefix} {
    set text [string trimright $text]
    set res {}
    foreach line [split $text \n] {
	if {[string trim $line] eq {}} {
	    lappend res {}
	} else {
	    lappend res $prefix[string trimright $line]
	}
    }
    return [join $res \n]
}

proc ::cm::util::undent {text} {
    if {$text eq {}} { return {} }

    set lines [split $text \n]
    set ne {}
    foreach l $lines {
	if {[string length [string trim $l]] == 0} continue
	lappend ne $l
    }

    set lcp [LCP $ne]
    if {$lcp eq {}} { return $text }

    regexp "^(\[\t \]*)" $lcp -> lcp
    if {$lcp eq {}} { return $text }

    set len [string length $lcp]

    set res {}
    foreach l $lines {
	if {[string trim $l] eq {}} {
	    lappend res {}
	} else {
	    lappend res [string range $l $len end]
	}
    }
    return [join $res \n]
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::max-length {words} {
    ::set max 0 
    foreach w $words {
	set l [string length $w]
	if {$l <= $max} continue
	set max $l
    }
    return $max
}

proc ::cm::util::LCP {list} {
    if {[llength $list] <= 1} {
	return [lindex $list 0]
    }

    set list [lsort $list]
    set min [lindex $list 0]
    set max [lindex $list end]

    # Min and max are the two strings which are most different. If
    # they have a common prefix, it will also be the common prefix for
    # all of them.

    # Fast bailouts for common cases.

    set n [string length $min]
    if {$n == 0}      { return "" }
    if {$min eq $max} { return $min }

    set prefix ""
    set i 0
    while {[string index $min $i] eq [string index $max $i]} {
	append prefix [string index $min $i]
	if {[incr i] > $n} {break}
    }
    return $prefix
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::open {path} {
    file mkdir [file dirname $path]
    return [::open $path w]
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide cm::util 0
