## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::config 0
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
package require cmdr::table
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::db::config
package require cm::validate::config

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::config {
    namespace export update undef get listall
    namespace ensemble create

    namespace import ::cm::validate::config
    rename config vt-config

    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::db::config

    namespace import ::cmdr::table::general ; rename general table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/config
debug prefix cm/config {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::config::listall {config} {
    debug.cm/config {}
    config setup
    db show-location

    [table t {Property Value} {
	foreach key [lsort -dict [vt-config all]] {
	    set v [config get* \
		       [vt-config internal   $key] \
		       [vt-config default-of $key]]
	    $t add $key $v
	}
	# And internals...
	db do eval {
	    SELECT key, value
	    FROM config
	    WHERE key GLOB '@*'
	    ORDER BY key
	} {
	    $t add $key $value
	}
    }] show
    return
}

proc ::cm::config::update {config} {
    debug.cm/config {}
    config setup
    db show-location

    set key   [$config @key]
    set value [$config @value]

    puts -nonewline "[color name $key] = $value ..."
    config assign $key $value

    puts [color good OK]
    return
}

proc ::cm::config::undef {config} {
    debug.cm/config {}
    config setup
    db show-location

    set key [$config @key]

    puts -nonewline "Unset [color name $key] ..."
    config drop $key

    puts [color good OK]
    return
}

proc ::cm::config::get {config} {
    debug.cm/config {}
    config setup
    db show-location

    set key [$config @key]

    # Current value, or default.
    puts [config get* $key [vt-config default-of $key]]
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

# # ## ### ##### ######## ############# ######################
package provide cm::config 0
return
