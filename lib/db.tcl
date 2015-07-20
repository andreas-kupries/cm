## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## CM - Database utilities
## Notes

# @@ Meta Begin
# Package cm::db 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/cm
# Meta platform tcl
# Meta summary     Internal. Database utilities.
# Meta description Internal. Database utilities.
# Meta subject {command line}
# Meta require {Tcl 8.5-}
# Meta require debug
# Meta require debug::caller
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require cmdr::color
package require debug
package require debug::caller
package require sqlite3

package require cm::atexit
package require cm::util

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}

namespace eval ::cm::db {
    namespace export \
	do err setup-error \
	default-location show-location location setup use
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cm::atexit
}

# # ## ### ##### ######## ############# #####################

debug define cm/db
debug level  cm/db
debug prefix cm/db {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::cm::db::setup {name script} {
    debug.cm/db {}
    # Define the setup code for the module, to be run once fully.
    uplevel 1 [list ::cm::util::once ::${name}::setup {} $script]
    return
}

proc ::cm::db::use {name} {
    debug.cm/db {}
    # Activate the requested database layer.
    package require cm::db::${name}
    # Import its ensemble into the calling module
    uplevel 1 [list namespace import ::cm::db::${name}]
    # And run the setup
    uplevel 1 [list $name setup]
    return
}

# # ## ### ##### ######## ############# #####################

proc ::cm::db::setup-error {table msg args} {
    err "Table \"$table\" setup error: $msg" SETUP [string toupper $table] {*}$args
}

proc ::cm::db::err {msg args} {
    return -code error -errorcode [list CM DB {*}$args] $msg
}

# # ## ### ##### ######## ############# #####################

proc ::cm::db::show-location {{suffix {}}} {
    variable location
    puts "[color note $location]$suffix"
    return
}

proc ::cm::db::location {} {
    variable location
    return  $location
}

proc ::cm::db::default-location {p} {
    file mkdir ~/.cm
    return     ~/.cm/managed
}

# # ## ### ##### ######## ############# #####################

proc ::cm::db::do {args} {
    debug.cm/db {1st call, create and short-circuit all following}

    # Get the config of currently running command. Provides us with the
    # inherited global options as well. Here our particular interest
    # is the @database location.
    variable location [[cm::cm get *config*] @database]

    # Drop ourselves to make way for the database command.
    rename ::cm::db::do {}

    # And replace it with the actual database command.
    sqlite3 ::cm::db::do $location

    # Remember to close when ending the application.
    atexit add [list ::cm::db::Close $location]

    # End early when nothing to do.
    if {![llength $args]} return

    # Run the __new__ command on the arguments.
    # This is __not__ a recursion into this proc.
    try {
        set r [uplevel 1 [list ::cm::db::do {*}$args]]
    } on return {e o} {
        # tricky code here. We have to rethrow with -code return to
        # keep the semantics in case we are called with the
        # 'transaction' method here, which passes a 'return' of the
        # script as its own 'return', and we must do the same here.
        return {*}$o -code return $e
    }
    return $r
}

proc ::cm::db::Close {location} {
    debug.cm/db {AtExit}
    do close
    return
}

# # ## ### ##### ######## ############# #####################

namespace eval ::cm::db {
    variable location
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide cm::db 0
