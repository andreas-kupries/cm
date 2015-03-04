## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## Cm - Validation Type - Client debug levels.

## To avoid having to load all packages and then query the debug
## package for the registered levels/tags this validation type loads
## the information from a generated file.
##
## TODO: Add the commands to generate/update this file to the wrapper
##       build code.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::validate
package require fileutil
package require cm::debug

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export validate
    namespace ensemble create
}
namespace eval ::cm::validate {
    namespace export debug
    namespace ensemble create
}
namespace eval ::cm::validate::debug {
    namespace export default validate complete release levels process-early
    namespace ensemble create

    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::cmdr::validate::common::fail-unknown-thing
}

proc ::cm::validate::debug::process-early {argv} {
    # Process all --debug flags we can find. Done before cmdr gets
    # hold of the command line to enable debugging the innards of
    # cmdr.
    set copy $argv
    while {[llength $copy]} {
	set copy [lassign $copy first]
	switch -glob -- $first {
	    --debug {
		set copy [lassign $copy tag]
		debug on $tag
	    }
	    --debug=* {
		regexp {^--debug=(.*)$} $first -> tag
		debug on $tag
	    }
	    default {}
	}
    }
    if {[info exists env(CM_DEBUG)]} {
	foreach tag [split $env(CM_DEBUG) ,] {
	    debug on $tag
	}
    }
}

proc ::cm::validate::debug::default  {p}   { error {No default} }
proc ::cm::validate::debug::release  {p x} { return }
proc ::cm::validate::debug::complete {p x} {
    return [complete-enum [cm debug thelevels] 0 $x]
}

proc ::cm::validate::debug::validate {p x} {
    if {$x in [cm debug thelevels]} { return $x }
    fail-unknown-thing $p DEBUG-LEVEL "debug level" $x
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide cm::validate::debug 0
