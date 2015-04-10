#!/usr/bin/env tclsh
## -*- tcl -*-
# New column "city.csnkey"
# - actual PK
# - lowercase normalized for case-insensitive uniqueness.

package require sqlite3
sqlite3 CM ~/.cm/managed

puts Restructure...
CM eval {
    CREATE TABLE new_city (
	    -- Base data for hotels, resorts, and other locations:
	    -- The city they are in.

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name	TEXT    NOT NULL,
	    state	TEXT,
	    nation	TEXT    NOT NULL,
	    csnkey	TEXT    NOT NULL,	-- actual key, lower-case
	    UNIQUE (name, state, nation),
	    UNIQUE (csnkey)
	    );

    -- Copy data
    INSERT
    INTO   new_city
    SELECT id, name, state, nation,
           name||','||state||','||nation AS csnkey	-- temp PK
    FROM   city
    ;

    -- Switch things around
    DROP TABLE city
    ;
    ALTER TABLE new_city RENAME TO city
    ;
}

# Finalize change, build proper normalized PK value

puts -nonewline {Finalize... } ; flush stdout
CM eval {
    SELECT id, name, state, nation FROM city
} {
    puts -nonewline * ; flush stdout
    lappend csnkey [string tolower $name]
    lappend csnkey [string tolower $state]
    lappend csnkey [string tolower $nation]
    CM eval {
	UPDATE city
	SET    csnkey = :csnkey
	WHERE  id     = :id
    }
    unset csnkey
}
puts ""
exit
