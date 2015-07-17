## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::contact 0
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
package require cmdr::ask
package require debug
package require debug::caller
package require dbutil
package require try

package require cm::db
package require cm::db::contact-type
package require cm::db::contact
package require cm::util

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export contact
    namespace ensemble create
}
namespace eval ::cm::contact {
    namespace export \
	create-person create-mlist create-company \
	add-mail add-link list-all show merge \
	disable enable disable-mail squash-mail \
	add-affiliation add-representative \
	remove-affiliation remove-representative \
	tag= bio= type= name= mail_fix \
	test-known test-select

    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::cmdr::ask

    namespace import ::cm::db
    namespace import ::cm::db::contact-type
    namespace import ::cm::db::contact
    namespace import ::cm::util

    namespace import ::cmdr::table::general ; rename general table
    namespace import ::cmdr::table::dict    ; rename dict    table/d
}

# # ## ### ##### ######## ############# ######################

debug level  cm/contact
debug prefix cm/contact {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::show {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [string trim [$config @name]]

    set w [util tspace [expr {[string length {Can Receive Mail}]+7}] 60]

    [table/d t {
	set details [contact get $contact]
	set issues  [contact issues $details]

	# TODO: use "dict with" and adapt users
	set tag   [dict get $details xtag]
	set type  [dict get $details xtype]
	set name  [dict get $details xdname]
	set bio   [dict get $details xbiography]
	set crecv [dict get $details xcan_recvmail]
	set creg  [dict get $details xcan_register]
	set cbook [dict get $details xcan_book]
	set ctalk [dict get $details xcan_talk]
	set csubm [dict get $details xcan_submit]

	if {$issues ne {}} {
	    $t add [color bad Issues] $issues
	    $t add {} {}
	}

	set flags {}
	if {$crecv} { lappend flags Receive  }
	if {$creg } { lappend flags Register }
	if {$cbook} { lappend flags Book     }
	if {$ctalk} { lappend flags Talk     }
	if {$csubm} { lappend flags Submit   }

	$t add Tag                $tag
	$t add Name               [color name $name]
	$t add Type               $type
	$t add Flags              [join $flags {, }]
	$t add Biography          [util adjust $w $bio]

	# Coded left self-joins for various relations...

	# Emails for the contact
	set first 1
	foreach emailaddr [contact email-addrs $contact] {
	    if {$first} { $t add Emails {} }
	    set first 0
	    $t add - $emailaddr
	}

	# Links for the contact
	set first 1
	foreach link [contact links $contact] {
	    if {$first} { $t add Links {} }
	    set first 0
	    $t add - $link
	}

	# Affiliations. Expected for persons, to list companies, their, well, affiliations
	set first 1
	foreach {_ dname} [contact affiliations $contact] {
	    if {$first} { $t add Affiliations {} }
	    set first 0
	    $t add - [color name $dname]
	}

	# Representatives/Liaisons. Expected for companies, to list persons, their representatives
	set first 1
	foreach {_ dname} [contact representatives $contact] {
	    if {$first} { $t add Representatives {} }
	    set first 0
	    $t add - [color name $dname]
	}

	# Reverse affiliations. Expected for companies, to list persons, the affiliated
	set first 1
	foreach {_ dname} [contact affiliated $contact] {
	    if {$first} { $t add Affiliated {} }
	    set first 0
	    $t add - [color name $dname]
	}

	# Reverse liaisons. Expected for persons, to list the companies they represent
	set first 1
	foreach {_ dname} [contact represents $contact] {
	    if {$first} { $t add Representing {} }
	    set first 0
	    $t add - [color name $dname]
	}
    }] show
    return
}

proc ::cm::contact::list-all {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set pattern  [string trim [$config @pattern]]
    set withmail [$config @with-mails]
    set types    [$config @only] ;# type-codes!

    set titles {\# Type Tag Name Mails Flags Relations}

    set counter 0
    [table t $titles {
	foreach {contact tag name typecode type crecv creg cbook ctalk csubm} [contact all $pattern] {
	    if {[llength $types] && ($typecode ni $types)} continue

	    incr counter

	    set related [contact relations-formatted $contact $typecode]

	    set    flags {}
	    append flags [expr {$crecv ? "M" :"-"}]
	    append flags [expr {$creg  ? "R" :"-"}]
	    append flags [expr {$cbook ? "B" :"-"}]
	    append flags [expr {$ctalk ? "T" :"-"}]
	    append flags [expr {$csubm ? "S" :"-"}]

	    if {$withmail} {
		set mails {}
		foreach {email inactive} [contact email-addrs+state $contact] {
		    lappend mails "[expr {$inactive ? "-":" "}] $email"
		}
		set mails [join $mails \n]
		$t add $counter $type $tag $name $mails $flags $related
	    } else {
		set mails [contact email-count $contact]
		if {!$mails} { set mails [color bad None] }
		$t add $counter $type $tag $name $mails $flags $related
	    }
	}
    }] show
    return
}

proc ::cm::contact::create-mlist {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set name [string trim [$config @name]]
    set mail [string trim [$config @mail]]

    # TODO: FIXME: Existing contact -> replace the mailing address - only one email allowed for lists.

    db do transaction {
	if {![contact has-mlist $name]} {
	    # Unknown contact. Create it, then add mail
	    puts -nonewline "Create list \"[color name $name]\" with mail \"[color name $mail]\" ... "
	    flush stdout

	    set contact [contact new-mlist $name]
	} else {
	    # Contact exists. Find it, then add mail

	    puts -nonewline "Extend list \"[color name $name]\" with mail \"[color name $mail]\" ... "
	    flush stdout

	    set contact [contact find-mlist $name]
	}

	contact new-mail  $contact $mail
	contact add-links $contact [$config @link]
    }
    # TODO: handle conflict with non list contacts

    puts [color good OK]
    return
}

proc ::cm::contact::create-company {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set name [string trim [$config @name]]

    db do transaction {
	if {![contact has-company $name]} {
	    # Unknown contact. Create it, then add mails and links
	    puts -nonewline "Create company \"[color name $name]\" ... "
	    flush stdout

	    set contact [contact new-company $name]
	} else {
	    # Contact exists. Find it, then add mails and links

	    puts -nonewline "Extend company \"[color name $name]\" ... "
	    flush stdout

	    set contact [contact find-company $name]
	}

	contact add-mails $contact [$config @email]
	contact add-links $contact [$config @link]
    }

    # TODO: Handle conflict with non company contacts

    puts [color good OK]
    return
}

proc ::cm::contact::create-person {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set name [string trim [$config @name]]

    db do transaction {
	if {![contact has-person $name]} {
	    # Unknown contact. Create it, then add mail
	    puts -nonewline "Create person \"[color name $name]\" ... "
	    flush stdout

	    set contact [contact new-person $name]
	} else {
	    # Contact exists. Find it, then add mail

	    puts -nonewline "Extend person \"[color name $name]\" ... "
	    flush stdout

	    set contact [contact find-person $name]
	}

	contact add-mails $contact [$config @email]
	contact add-links $contact [$config @link]

	if {[$config @tag set?]} {
	    contact tag= $contact [string trim [$config @tag]]
	}
    }

    # TODO: Handle conflict with non person contacts

    puts [color good OK]
    return
}

proc ::cm::contact::add-mail {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]

    puts -nonewline "Add mails to \"[color name [contact 2label $contact]]\" ... "
    flush stdout

    contact add-mails $contact [$config @email]

    puts [color good OK]
    return
}

proc ::cm::contact::add-link {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]

    puts -nonewline "Add links to \"[color name [contact 2label $contact]]\" ... "
    flush stdout

    contact add-links $contact [$config @link]

    puts [color good OK]
    return
}

proc ::cm::contact::disable {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    foreach contact [$config @name] {
	puts -nonewline "Disabling contact \"[color name [contact 2label $contact]]\" ... "
	flush stdout

	contact recv= $contact 0

	puts [color good OK]
    }
    return
}

proc ::cm::contact::enable {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    foreach contact [$config @name] {
	puts -nonewline "Enabling contact \"[color name [contact 2label $contact]]\" ... "
	flush stdout

	contact recv= $contact 1

	puts [color good OK]
    }
    return
}

proc ::cm::contact::disable-mail {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    foreach email [$config @email] {
	puts -nonewline "Disabling email \"[color name [contact 2name-email $email]]\" ... "
	flush stdout

	contact disable-email $email

	puts [color good OK]
    }
    return
}

proc ::cm::contact::squash-mail {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    foreach email [$config @email] {
	puts -nonewline "Deleting email \"[color name [contact 2name-email $email]]\" ... "
	flush stdout

	contact squash-email $email

	puts [color good OK]
    }
    return
}

proc ::cm::contact::type= {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set type   [$config @type]
    set tlabel [contact-type 2name $type]

    foreach contact [$config @name] {
	puts -nonewline "Changing contact \"[color name [contact 2label $contact]]\" to \"$tlabel\" ... "
	flush stdout

	contact type= $contact $type

	puts [color good OK]
    }
    return
}

proc ::cm::contact::name= {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]
    set dnew    [$config @newname]
    set new     [string tolower $dnew]

    puts -nonewline "Renaming contact \"[color name [contact 2label $contact]]\" to \"[color name $new]\" ... "
    flush stdout

    contact name= $contact $dnew

    puts [color good OK]
    return
}

proc ::cm::contact::tag= {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]
    set tag     [$config @tag]

    puts -nonewline "Set tag of \"[color name [contact 2label $contact]]\" to \"$tag\" ... "
    flush stdout

    contact tag= $contact $tag

    puts [color good OK]
    return
}

proc ::cm::contact::bio= {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]
    set bio     [read stdin]

    puts -nonewline "Set biography of \"[color name [contact 2label $contact]]\" ... "
    flush stdout

    contact bio= $contact $bio

    puts [color good OK]
    return
}

proc ::cm::contact::merge {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set primary [$config @primary]

    foreach secondary [$config @secondary] {
	puts -nonewline "Merging contact \"[color name [contact 2label $primary]]\" with \"[color name [contact 2label $secondary]]\" ... "
	flush stdout

	contact merge $primary $secondary

	puts [color good OK]
    }

    return
}

proc ::cm::contact::add-affiliation {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]

    db do transaction {
	puts "Extend affiliations of \"[color name [contact 2label $contact]]\" ... "

	foreach company [$config @company] {
	    puts -nonewline "+ \"[color name [contact 2label $company]]\" ... "
	    flush stdout

	    contact add-affiliation $contact $company

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact:remove-affiliation {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set contact [$config @name]

    db do transaction {
	puts "Reduce affiliations of \"[color name [contact 2label $contact]]\" ... "

	foreach company [$config @company] {
	    puts -nonewline "- \"[color name [contact 2label $company]]\" ... "
	    flush stdout

	    contact drop-affiliation $contact $company

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::add-representative {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set company [$config @company]

    db do transaction {
	puts "Extend representatives of \"[color name [contact 2label $company]]\" ..."

	foreach contact [$config @name] {
	    puts -nonewline "+ \"[color name [contact 2label $contact]]\" ... "
	    flush stdout

	    contact add-representative $company $contact

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::remove-representative {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    set company [$config @company]

    db do transaction {
	puts "Reduce representatives of \"[color name [contact 2label $company]]\" ..."

	foreach contact [$config @name] {
	    puts -nonewline "- \"[color name [contact 2label $contact]]\" ... "
	    flush stdout

	    contact drop-representative $company $contact

	    puts [color good OK]
	}
    }
    return
}

proc ::cm::contact::mail_fix {config} {
    debug.cm/contact {}
    contact setup
    db show-location

    puts -nonewline "Fixing mails, forcing lowercase ... "
    flush stdout

    foreach {email addr} [contact emails] {
	contact email= $email [string tolower $addr]
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::contact::test-known {config} {
    debug.cm/contact {}
    contact setup
    util pdict [contact known validate]
    return
}

proc ::cm::contact::test-select {config} {
    debug.cm/contact {}
    contact setup
    util pdict [contact known select]
    return
}

# # ## ### ##### ######## ############# ######################
package provide cm::contact 0
return
