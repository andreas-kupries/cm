## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::mailer 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     conference management
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::color
package require tls
package require smtp
package require mime
package require cm::db
package require cm::db::config
package require cm::mailgen
package require cm::table
package require cm::validate::config

debug level  cm/mailer
debug prefix cm/mailer {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::cm {
    namespace export mailer
    namespace ensemble create
}
namespace eval ::cm::mailer {
    namespace export \
	cmd_test_address cmd_test_mail_config \
	good-address dedup-addresses drop-address \
	get-config get has send batch
    namespace ensemble create

    namespace import ::cmdr::color

    namespace import ::cm::db
    namespace import ::cm::mailgen

    namespace import ::cm::validate::config
    rename config vt-config

    namespace import ::cm::db::config

    namespace import ::cm::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::cm::mailer::cmd_test_mail_config {config} {
    debug.cm/mailer {}

    send \
	[get-config] \
	[list [$config @destination]] \
	[mailgen testmail \
	     [get sender] \
	     {} {}] on
    #TODO: re-add header, footer?
    return
}

proc ::cm::mailer::cmd_test_address {config} {
    debug.cm/mailer {}
    set address [$config @address]

    puts "Decoding \"[color name $address]\" :="
    [table t {Part Value Notes} {
	set address [string map {{;} {,}} $address]
	set first 1
	foreach parts [mime::parseaddress $address] {
	    if {!$first} { $t add ==== ===== ===== }
	    set first 0

	    # set parts [lindex 0]
	    set hasdomain 0
	    set haslocal  0

	    foreach k [lsort -dict [dict keys $parts]] {
		set v [dict get $parts $k]
		set notes {}
		switch -exact $k {
		    domain -
		    local {
			incr has$k
			if {$v eq {}} {
			    lappend notes [color note {** Empty **}]
			}
		    }
		    error {
			if {$v ne {}} {
			    set k [color bad $k]
			    set v [color bad $v]
			}
		    }
		    default {
			# Report on the missing pieces. Depends on the
			# parts sorted lexicographically (see lsort above)
			# to place the fakes at the correct locations.

			if {([string compare $k domain] > 0) && !$hasdomain} {
			    $t add [color bad $k] {} [color bad {** Missing **}]
			    incr hasdomain
			}
			if {([string compare $k local] > 0) && !$haslocal} {
			    $t add [color bad $k] {} [color bad {** Missing **}]
			    incr haslocal
			}
		    }
		}
		$t add $k $v [join $notes \n]
	    }
	}

    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::mailer::dedup-addresses {addrlist} {
    debug.cm/mailer {}
    # We assume that all addresses are good.
    # We keep the longest input of each with the same 'address'.

    #puts IN|[join $addrlist "|\n  |"]|

    # Note that we do basic lexical uniqueness first, getting rid of
    # the trivial duplicates.

    set map {}
    foreach a [lsort -unique $addrlist] {
	set route [dict get [lindex [mime::parseaddress $a] 0] address]
	dict lappend map $route $a
    }

    #array set mm $map ; parray mm ; unset mm

    set r {}
    dict for {route alist} $map {
	lappend r [lindex [lsort -command [lambda {a b} {
	    expr {[string length $b] - [string length $a]}
	}] $alist] 0]
    }

    return $r
}

proc ::cm::mailer::drop-address {addr addrlist} {
    debug.cm/mailer {}
    # We assume that all addresses are good.
    # We do not care about duplicates.
    # - If the input has them, the output will too.

    set addr [dict get [lindex [mime::parseaddress $addr] 0] address]

    debug.cm/mailer {subtract = $addr}

    set result {}
    foreach a $addrlist {
	set route [dict get [lindex [mime::parseaddress $a] 0] address]
	debug.cm/mailer {route = $route}
	if {$route eq $addr} continue
	debug.cm/mailer {  kept}
	lappend result $a
    }

    debug.cm/mailer {==> ($result)}
    return $result
}

proc ::cm::mailer::good-address {addr} {
    debug.cm/mailer {}
    set r [lindex [mime::parseaddress $addr] 0]

    # TODO: Check how it looks with multiple addresses, and bad syntax.

    # Drop empty results. Drop results which are not full addresses
    # i.e. have missing or empty local and domain parts.

    if {$r eq {}}                   { return 0 }
    if {![dict exists $r domain]}   { return 0 }
    if {[dict get $r domain] eq {}} { return 0 }
    if {![dict exists $r local]}    { return 0 }
    if {[dict get $r local] eq {}}  { return 0 }

    #puts ======================================================
    #array set aa $r ; parray aa ; unset aa

    # TODO: Filter out addresses with domains matching the local host.
    return 1
}

proc ::cm::mailer::get {setting} {
    return [Get 0 $setting]
}

proc ::cm::mailer::get-config {} {
    debug.cm/mailer {}

    foreach {option listify setting} {
	-debug    0 debug
	-usetls   0 tls
	-username 0 user
	-password 0 password
	-servers  1 host
	-ports    0 port
    } {
	lappend mconfig $option [Get $listify $setting]
    }

    lappend mconfig -tlspolicy ::cm::mailer::TlsPolicy
    lappend mconfig -header [list From [Get 0 sender] ]
    return $mconfig
}

proc ::cm::mailer::Get {listify setting} {
    debug.cm/mailer {}
    set v [config get* \
	       [vt-config internal   $setting] \
	       [vt-config default-of $setting]]
    if {$listify} { set v [list $v] }
    return $v
}

proc ::cm::mailer::has {setting} {
    debug.cm/mailer {}
    return [config has [vt-config internal $setting]]
}

# # ## ### ##### ######## ############# ######################

proc ::cm::mailer::batch {r a n destinations script} {
    upvar 1 $r receiver $a address $n name

    db do eval [string map [list @@@ [join $destinations ,]] {
	SELECT E.id    AS receiver,
               E.email AS address,
	       C.dname AS name
	FROM   email   E,
	       contact C
	WHERE E.id IN (@@@)
	AND   C.id = E.contact
    }] {
	uplevel 1 $script
    }
}

proc ::cm::mailer::send {mconfig receivers corpus {verbose 0}} {
    debug.cm/mailer {}
    #if {[suspended]} return
    #if {![llength $receivers]} return

    if {$verbose} {
	puts "    ================================================"
	puts [textutil::adjust::indent $corpus {        }]
	puts "    ================================================"
    }
    #return

    set token [mime::initialize -string $corpus]

    foreach dst $receivers {
	puts -nonewline "    To: [color name $dst] ... "
	flush stdout

	try {
	    # Can the 'From' be configured via -header here ?
	    # I.e. mconfig ? Alternate: -originator

	    set res [smtp::sendmessage $token \
			 -header [list To $dst] \
			 {*}$mconfig]
	    foreach item $res {
		puts "    ERR $item"
	    }
	} finally {
	}
	puts [color good OK]
    }

    mime::finalize $token
    puts Done

    variable mailcounter
    incr     mailcounter
    return
}

# # ## ### ##### ######## ############# ######################

proc ::cm::mailer::TlsPolicy {args} {
    debug.cm/mailer {}
    puts $args
    return secure
}

# # ## ### ##### ######## ############# ######################
package provide cm::mailer 0
return
