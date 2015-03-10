## -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package cm::debug 0
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
package require debug

package require cm::table

# # ## ### ##### ######## #############

namespace eval ::cm {
    namespace export debug
    namespace ensemble create
}
namespace eval ::cm::debug {
    namespace export cmd_levels
    namespace export thelevels
    namespace ensemble create

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## #############

proc ::cm::debug::cmd_levels {config} {
    [table t {Level} {
	foreach level [lsort -dict [thelevels]]  {
	    $t add $level
	}
    }] show
    return
}

# # ## ### ##### ######## #############

proc ::cm::debug::thelevels {} {
    # First ensure that all possible cm packages are loaded, so that
    # all possible debug levels are declared and known.

    #package require cm::
    package require cm::campaign
    package require cm::city
    package require cm::conference
    package require cm::contact
    package require cm::enum
    package require cm::hotel
    package require cm::mailer
    package require cm::table
    package require cm::util
    package require cm::validate::colormode
    package require cm::validate::config
    package require cm::validate::contact
    package require cm::validate::contact-type
    package require cm::validate::debug
    package require cm::validate::email
    package require cm::validate::mail-address
    package require cm::validate::nottemplate
    package require cm::validate::template

    package require cmdr::ask
    package require cmdr::color
    package require cmdr::tty
    package require cmdr::validate::date
    package require cmdr::validate::posint
    package require cmdr::validate::weekday
    package require cmdr::validate::year

    return [debug names]
}

# # ## ### ##### ######## #############
package provide cm::debug 0
