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
package require debug
package require debug::caller
package require cmdr::color
package require textutil::adjust
package require linenoise

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export util
    namespace ensemble create
}

namespace eval ::cm::util {
    namespace export padr padl dictsort reflow indent undent \
	max-length strip-prefix open user-error highlight-current \
	tspace adjust
    namespace ensemble create

    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# #####################

debug define cm/util
debug level  cm/util
debug prefix cm/util {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::cm::util::tspace {sub {tmax -1}} {
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
    upvar 1 $xvar cid [lindex $args 0] current
    if {$cid != $id} {
	set current {}
	return 
    }
    set current *
    foreach v $args {
	upvar 1 $v str
	set str [color bold $str]
    }
    return
}

# # ## ### ##### ######## ############# #####################

proc ::cm::util::user-error {msg args} {
    return -code error -errorcode [list CM USER {*}$args] $msg
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
