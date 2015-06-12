## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## CM - Validation Type - Color modi

# @@ Meta Begin
# Package cm::validate::colormode 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate

debug level  validate/colormode
debug prefix validate/colormode {[debug caller] | }

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export colormode
    namespace ensemble create
}
namespace eval ::cm::validate::colormode {
    namespace export default validate complete release process-early
    namespace ensemble create

    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::cmdr::validate::common::fail-unknown-thing

    variable legalvalues {always auto never}
}

proc ::cm::validate::colormode::process-early {argv} {
    # Process all --color flags we can find. Do before cmdr gets hold
    # of the command line to enable the deactivation of --debug
    # colorization as early as we can.

    set copy $argv
    while {[llength $copy]} {
	set copy [lassign $copy first]
	switch -exact -- $first {
	    --color {
		set copy [lassign $copy mode]
		switch -exact -- $mode {
		    auto   {
			# Nothing to do, system default, already in place.
		    }
		    always { cmdr color activate 1 }
		    never  { cmdr color activate 0 }
		}
	    }
	    --color=auto {
		# Nothing to do, system default, already in place.
	    }
	    --color=always { cmdr color activate 1 }
	    --color=never  { cmdr color activate 0 }
	    default {}
	}
    }
    return
}

proc ::cm::validate::colormode::default  {p}   { return auto }
proc ::cm::validate::colormode::release  {p x} { return }
proc ::cm::validate::colormode::complete {p x} {
    variable legalvalues
    complete-enum $legalvalues 0 $x
}

proc ::cm::validate::colormode::validate {p x} {
variable legalvalues
    debug.validate/colormode {}

    if {$x in $legalvalues} {
	debug.validate/colormode {OK}
	return $x
    }
    debug.validate/colormode {FAIL}
    fail-unknown-thing $p COLORMODE "color-mode" $x
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide cm::validate::colormode 0
