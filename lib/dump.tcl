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
package require fileutil
package require cm::db

debug level  cm/dump
debug prefix cm/dump {[debug caller] | }

# # ## ### ##### ######## #############

namespace eval ::cm {
    namespace export dump
    namespace ensemble create
}
namespace eval ::cm::dump {
    namespace export cmd write step save comment
    namespace ensemble create

    namespace import ::cm::db
}

# # ## ### ##### ######## #############

proc ::cm::dump::cmd {config} {
    debug.cm/dump {}
    db do version
    db show-location

    variable dst  ;# Local state, namespace.
    variable chan ;#

    set dst [$config @destination]
    file mkdir [file dirname ${dst}__main]
    set chan [open ${dst}__main w]

    Header
    Dump    config::core
    DumpDB    template
    DumpDB    city
    Dump    location
    Dump    contact
    Dump    tutorial
    Dump    conference
    #       - talks, schedule
    # TODO dump campaign
    Trailer

    close $chan
    return
}

proc ::cm::dump::write {suffix data args} {
    variable dst
    fileutil::writeFile {*}$args ${dst}$suffix $data
    return [file tail ${dst}$suffix]
}

proc ::cm::dump::step {} {
    variable chan
    puts $chan ""
}

proc ::cm::dump::comment {args} {
    variable chan
    puts $chan "# $args"
    return
}

proc ::cm::dump::save {args} {
    variable chan
    puts $chan "cm $args"
    return
}

proc ::cm::dump::Header {} {
    variable chan
    puts $chan "#!/usr/bin/env tclsh"
    puts $chan [Separator]
    puts $chan "## Save script for CM '[db location]'\n"
    puts $chan [list proc cm {args} {catch { exec 2>@ stderr >@ stdout cm {*}$args }}]
    return
}

proc ::cm::dump::Trailer {} {
    variable chan
    puts $chan \n[Separator]\n
    puts $chan "## Done"
    puts $chan exit
    return
}

proc ::cm::dump::Separator {} {
    return "# # ## ### ##### ########"
}

proc ::cm::dump::Dump {area} {
    debug.cm/dump {}
    variable chan

    puts ...$area

    puts $chan \n[Separator]
    puts $chan "## -- $area --\n"

    package require cm::${area}
    cm::${area}::Setup
    cm::${area}::Dump

    return
}

proc ::cm::dump::DumpDB {area} {
    debug.cm/dump {}
    variable chan

    puts ...$area

    puts $chan \n[Separator]
    puts $chan "## -- $area --\n"

    package require cm::db::${area}
    cm db ${area} setup
    cm db ${area} dump
    return
}

# # ## ### ##### ######## #############

package provide cm::dump 0
