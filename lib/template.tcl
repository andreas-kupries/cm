## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::template 0
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
package require cmdr::ask
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::db::template
package require cm::table
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export template
    namespace ensemble create
}
namespace eval ::cm::template {
    namespace export create remove update list-all show
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask
    namespace import ::cm::db
    namespace import ::cm::db::template
    namespace import ::cm::util

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/template
debug prefix cm/template {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::template::show {config} {
    debug.cm/template {}
    template setup
    db show-location

    set template [$config @name]

    puts "Template \"[color name [template 2name $template]]\":"
    puts [template value $template]
    return
}

proc ::cm::template::list-all {config} {
    debug.cm/template {}
    template setup
    db show-location

    # TODO: compute and show issues with templates (missing place holders)

    [table t {Name} {
	foreach {template name} [template all] {
	    $t add $name
	}
    }] show
    return
}

proc ::cm::template::create {config} {
    debug.cm/template {}
    template setup
    db show-location

    # try to insert, report failure as user error

    set name [$config @name]
    set text [util text-stdin $config @text]

    # TODO: compute and show issues with templates (missing place holders)
    # Warn, ask for progress...

    puts -nonewline "Creating new template \"[color name $name]\" ... "

    try {
	template new $name $text
    } on error {e o} {
	# Report insert failure as user error
	# TODO: trap only proper insert error, if possible.
	util user-error $e TEMPLATE CREATE
	return
    }

    puts [color good OK]
    return
}

proc ::cm::template::remove {config} {
    debug.cm/template {}
    template setup
    db show-location

    set template [$config @name]

    # TODO: prevent removal if used in campaigns

    puts -nonewline "Deleting template \"[color name [template 2name $template]]\" ... "
    flush stdout

    template delete $template

    puts [color good OK]
    return
}

proc ::cm::template::update {config} {
    debug.cm/template {}
    template setup
    db show-location

    set template [$config @name]
    set text     [util text-stdin $config @text]

    puts -nonewline "Updating template \"[color name [template 2name $template]]\" ... "
    flush stdout

    template update $template $text

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::template 0
return
