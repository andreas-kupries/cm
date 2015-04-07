## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package cm::validate::config 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/cm
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::validate::common
package require cm::db::config

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::validate {
    namespace export config
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration configs

namespace eval ::cm::validate::config {
    namespace export release validate default complete \
	internal external all default-of
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::cm::db::config
}

proc ::cm::validate::config::release  {p x} { return }
proc ::cm::validate::config::validate {p x} {
    if {[has $x]} {
	return [internal $x]
    }
    fail $p CONFIG "a CM setting" $x
}

proc ::cm::validate::config::default  {p} { return {} }
proc ::cm::validate::config::complete {p x} {
    variable legal
    complete-enum $legal 1 $x
}

proc ::cm::validate::config::has {x} {
    variable map
    return [dict exists $map [string tolower $x]]
}

proc ::cm::validate::config::external {x} {
    variable imap
    return [dict get $imap $x]
}

proc ::cm::validate::config::internal {x} {
    variable map
    return [dict get $map [string tolower $x]]
}

proc ::cm::validate::config::default-of {x} {
    variable default
    return [dict get $default $x]
}

proc ::cm::validate::config::all {} {
    variable legal
    return  $legal
}

# # ## ### ##### ######## ############# ######################

namespace eval ::cm::validate::config {
    # # ##
    # sender   string. mail address of the nominal sender, inserted into the generated mails.

    # debug     boolean, low-level smtp-debugging yes/no
    # tls       boolean. (can|must) use TLS to secure smtp yes/no.
    # host      string. name of relay host
    # password  string. password for smtp transaction
    # user      string. user for smtp  transaction.
    # port      integer. port on relay host accepting smtp.

    # limit     number of mails the system is allowed to send in a block.
    # suspended boolean, delivery disabled no/yes.

    # Names starting with @ are reserved for internal purposes.

    variable map {
	debug     debug
	host 	  host
	limit     limit
	password  password
	port 	  port
	sender    sender
	suspended suspended
	tls       tls
	user      user
    }

    variable default {
	debug     0
	host 	  localhost
	limit     10
	password  {}
	port 	  25
	sender    {*Undefined* Please set.}
	suspended 0
	tls       0
	user      {}
    }

    # Last map: Type validation per setting.
}

# Generate back-conversion internal to external.
::apply {{} {
    variable legal
    variable imap
    variable map
    foreach {k v} $map {
	dict set imap $v $k
	lappend legal $k
    }
} ::cm::validate::config}

# # ## ### ##### ######## ############# ######################
package provide cm::validate::config 0
return
