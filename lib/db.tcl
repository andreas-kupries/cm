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
package require debug
package require debug::caller
package require cm::atexit
package require cmd::color

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::cm {
    namespace export db
    namespace ensemble create
}

namespace eval ::cm::db {
    namespace export make do default-location show-location location
    namespace ensemble create

    namespace import ::cm::atexit
    namespace import ::cmdr::color
}

# # ## ### ##### ######## ############# #####################

debug define cm/db
debug level  cm/db
debug prefix cm/db {[debug caller] | }

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

# # ## ### ##### ######## ############# #####################

proc ::cm::db::default-location {p} {
    file mkdir ~/.cm
    return     ~/.cm/managed
}

# # ## ### ##### ######## ############# #####################

proc ::cm::db::make {p} {
    debug.cm/db {}
    variable location [$p config @database]
    return [sqlite3 ::cm::db::do $location]
}

# # ## ### ##### ######## ############# #####################

proc ::cm::db::do {args} {
    debug.fcm/db {1st call, create and short-circuit all following}
    # Drop the procedure.
    rename ::cm::db::do {}

    # And replace it with the database command.
    upvar 1 config config ;# Assumes that we are in a command implementation.
    $config @managed

    atexit add [list ::cm::db::Close [$config @database]]

    if {![llength $args]} return

    # Run the new database on the arguments.
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
