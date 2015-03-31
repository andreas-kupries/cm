## -*- tcl -*-
# # ## ### ##### ######## #############
## Dump the database contents as a series of Tcl commands which can be
## used to load the information into another CM database. Also a
## readable backup.

# @@ Meta Begin
# Package cm::dump 0
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
package require debug::caller
package require cm::db

debug level  cm/dump
debug prefix cm/dump {[debug caller] | }

# # ## ### ##### ######## #############

namespace eval ::cm {
    namespace export dump
    namespace ensemble create
}
namespace eval ::cm::dump {
    namespace export cmd step save comment
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## #############

proc ::cm::dump::cmd {config} {
    debug.cm/dump {}
    db do version
    db show-location

    set dst [$config @destination]

    file mkdir [file dirname $dst]
    set chan [open $dst w]

    Header  $chan
    Dump    $chan config::core
    Dump    $chan template
    Dump    $chan city
    Dump    $chan location
    Dump    $chan contact
    Dump    $chan tutorial
    Dump    $chan conference
    #       - rate, t-schedule, timeline,
    #       - submissions, talks, schedule
    #       - staff, sponsors
    # TODO dump campaign
    Trailer $chan

    close $chan
    return
}

proc ::cm::dump::step {chan} {
    puts $chan ""
}

proc ::cm::dump::comment {chan args} {
    puts $chan "# $args"
    return
}

proc ::cm::dump::save {chan args} {
    puts $chan "cm $args"
    return
}

proc ::cm::dump::Header {chan} {
    puts $chan "#!/usr/bin/env tclsh"
    puts $chan [Separator]
    puts $chan "## Save script for CM '[db location]'\n"
    puts $chan [list proc cm {args} {catch { exec 2>@ stderr >@ stdout cm {*}$args }}]
    return
}

proc ::cm::dump::Trailer {chan} {
    puts $chan \n[Separator]\n
    puts $chan "## Done"
    puts $chan exit
    return
}

proc ::cm::dump::Separator {} {
    return "# # ## ### ##### ########"
}

proc ::cm::dump::Dump {chan area} {
    debug.cm/dump {}

    puts $chan \n[Separator]
    puts $chan "## -- $area --\n"

    package require cm::${area}
    cm::${area}::Setup
    cm::${area}::Dump $chan

    return
}

# # ## ### ##### ######## #############

package provide cm::dump 0
