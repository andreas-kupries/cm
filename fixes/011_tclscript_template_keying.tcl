#!/usr/bin/env tclsh
## -*- tcl -*-
# New columns "template.dname"
# => display information. Existing columns "name"
#    become lowercase normalized for case-insensitive uniqueness.

package require sqlite3
file copy -force ~/.cm/managed ~/.cm/managed.bak
sqlite3 CM       ~/.cm/managed

puts Restructure...
CM eval {
    CREATE TABLE new_template (
	    -- Text templates for mail campaigns, the web site, etc

	    id		INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    name	TEXT    NOT NULL UNIQUE,	-- normalized lowercase
	    dname	TEXT    NOT NULL,
	    value	TEXT	NOT NULL
    );

    -- Copy data -- placeholder for name -- normalization is step 2
    INSERT
    INTO   new_template
    SELECT id, name, name, value
    FROM   template
    ;

    -- Switch things around
    DROP TABLE template
    ;
    ALTER TABLE new_template RENAME TO template
    ;
}

# Finalize change, build proper normalized (PK) values

puts -nonewline {Finalize... } ; flush stdout
CM eval {
    SELECT id, name, dname, value FROM template
} {
    puts -nonewline * ; flush stdout
    set name          [string tolower $name]
    CM eval {
	UPDATE template
	SET    name = :name
	WHERE  id   = :id
    }
}
puts "="
exit
