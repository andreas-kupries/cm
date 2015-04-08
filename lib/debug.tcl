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
    package require cm::atexit
    package require cm::campaign
    package require cm::city
    package require cm::conference
    package require cm::config
    package require cm::contact
    package require cm::db
    package require cm::db::city
    package require cm::db::config
    package require cm::db::contact-type
    package require cm::db::dayhalf
    package require cm::db::location
    package require cm::db::rstatus
    package require cm::db::staffrole
    package require cm::db::talk-state
    package require cm::db::talk-type
    package require cm::db::template
    package require cm::db::timeline
    package require cm::db::tutorial
    #package require cm::debug ;#-- self
    package require cm::location
    package require cm::mailer
    package require cm::mailgen
    package require cm::table
    package require cm::template
    package require cm::tutorial
    package require cm::util
    package require cm::validate::attachment
    package require cm::validate::city
    package require cm::validate::colormode
    package require cm::validate::conference-staff
    package require cm::validate::config
    package require cm::validate::contact
    package require cm::validate::contact-type
    package require cm::validate::dayhalf
    package require cm::validate::debug
    package require cm::validate::email
    package require cm::validate::location-staff
    package require cm::validate::mail-address
    package require cm::validate::nottemplate
    package require cm::validate::nottutorial
    package require cm::validate::nottutorialtag
    package require cm::validate::rstatus
    package require cm::validate::speaker
    package require cm::validate::sponsor
    package require cm::validate::staffrole
    package require cm::validate::submission
    package require cm::validate::submitter
    package require cm::validate::talkstate
    package require cm::validate::talktype
    package require cm::validate::template
    package require cm::validate::timeline
    package require cm::validate::tutorial

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
