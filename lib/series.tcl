## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::series 0
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
package provide cm::series 0

package require Tcl 8.5
package require cmdr::color
package require cmdr::table
package require dbutil
package require debug
package require debug::caller
package require struct::set
package require struct::matrix
package require try

package require cm::db
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export series
    namespace ensemble create
}
namespace eval ::cm::series {
    namespace export \
	cmd_create cmd_list cmd_show cmd_rename cmd_redirect \
	cmd_remove known test-known get get-index
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cm::db
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
}

# # ## ### ##### ######## ############# ######################

debug level  cm/series
debug prefix cm/series {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::series::test-known {config} {
    debug.cm/series {}
    Setup
    db show-location
    util pdict [known]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::series::cmd_list {config} {
    debug.cm/series {}
    Setup
    db show-location
    
    # FUTURE: Options to sort by
    # - indexpage

    [table t {Name Index} {
	db do eval {
	    SELECT title
	    ,      indexpage
	    FROM series
	    ORDER BY title
	} {
	    $t add $title $indexpage
	}
    }] show
    return
}

proc ::cm::series::cmd_create {config} {
    debug.cm/series {}
    Setup
    db show-location
    # try to insert, report failure as user error

    set title [$config @title]     ; debug.cm/series {title     = $title}
    set ipage [$config @indexpage] ; debug.cm/series {indexpage = $ipage}

    puts -nonewline "Creating series \"[color name $title]\" @ \"[color name $ipage]\" ... "
    flush stdout

    try {
	db do transaction {
	    db do eval {
		INSERT INTO series
		VALUES (NULL,     -- id, auto-assigned
			:title,
			:ipage
	        )
	    }
	}
    } on error {e o} {
	# TODO: trap only proper insert error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

proc ::cm::series::cmd_show {config} {
    debug.cm/series {}
    Setup
    db show-location

    set id      [$config @title]
    set details [details $id]

    puts "Details of \"[color name [get $id]]\":"
    [table t {Key Value} {
	$t headers 0
	dict with details {}
	$t add Index $xindexpage
    }] show
    return
}

proc ::cm::series::cmd_rename {config} {
    debug.cm/series {}
    Setup
    db show-location
    set id       [$config @title]
    set newtitle [$config @new]

    puts -nonewline "Renaming series \"[color name [get $id]]\" to \"[color name $newtitle]\" ... "
    flush stdout
    
    db do transaction {
	set details [details $id]
	dict set details xtitle $newtitle
	write $id $details
    }

    puts [color good OK]
    return
}

proc ::cm::series::cmd_redirect {config} {
    debug.cm/series {}
    Setup
    db show-location
    set id       [$config @title]
    set newindex [$config @new]

    puts -nonewline "Redirecting series \"[color name [get $id]]\" to \"[color name $newindex]\" ... "
    flush stdout

    db do transaction {
	set details [details $id]
	dict set details xindexpage $newindex
	write $id $details
    }

    puts [color good OK]
    return
}

proc ::cm::series::cmd_remove {config} {
    debug.cm/series {}
    Setup
    db show-location

    set id [$config @title]
    puts -nonewline "Removing series \"[color name [get $id]]\" ... "

    try {
	remove $id
    } on error {e o} {
	# TODO: trap only proper delete error, if possible.
	puts [color bad $e]
	return
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::series::remove {id} {
    debug.cm/series {}
    Setup

    db do transaction {
	db do eval {
	    DELETE
	    FROM series
	    WHERE id = :id
--	    ;
--	    UPDATE conference
--	    SET series = NULL
--	    WWHERE series = :id
	}
    }
    return
}

proc ::cm::series::known {} {
    debug.cm/series {}
    Setup

    # dict: label -> id
    set known {}

    db do eval {
	SELECT id, title, indexpage
	FROM   series
    } {
	dict set known $title     $id
	dict set known $indexpage $id
    }

    debug.cm/series {==> ($known)}
    return $known
}

proc ::cm::series::get {id} {
    debug.cm/series {}
    Setup

    return [db do onecolumn {
	SELECT title
	FROM  series
	WHERE id = :id
    }]
}

proc ::cm::series::get-index {id} {
    debug.cm/series {}
    Setup

    return [db do onecolumn {
	SELECT indexpage
	FROM  series
	WHERE id = :id
    }]
}

proc ::cm::series::details {id} {
    debug.cm/series {}
    Setup

    return [db do eval {
	SELECT 'xseries',    id,
	       'xtitle',     title,
	       'xindexpage', indexpage
	FROM  series
	WHERE id = :id
    }]
}

proc ::cm::series::write {id details} {
    debug.cm/series {}
    Setup

    dict with details {}
    db do eval {
	UPDATE series
	SET    title      = :xtitle,
	       indexpage  = :xindexpage
	WHERE id = :id
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::series::Setup {} {
    debug.cm/series {}

    if {![dbutil initialize-schema ::cm::db::do error series {
	{
	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    title	TEXT	NOT NULL UNIQUE, -- Name of the series of conferences
	    indexpage   TEXT	NOT NULL UNIQUE  -- Page holding the index of all conferences in the series
	} {
	    {id			INTEGER 1 {} 1}
	    {title		TEXT    1 {} 0}
	    {indexpage		TEXT    1 {} 0}
	} {}
    }]} {
	db setup-error series $error
    }

    # Shortcircuit further calls
    proc ::cm::series::Setup {args} {}
    return
}


proc ::cm::series::Dump {} {
    debug.cm/series {}

    db do eval {
	SELECT id, title, indexpage
	FROM   series
	ORDER BY title
    } {
	cm dump save \
	    series create $title $indexpage
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::series 0
return
