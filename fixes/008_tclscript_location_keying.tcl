#!/usr/bin/env tclsh
## -*- tcl -*-
# New columns "location.dname", "location.dstreetaddress"
# => display information. Existing columns "name", "streetaddress"
#    become lowercase normalized for case-insensitive uniqueness.
# Column reordering
# Column "location.zipcode" gets normalized uppercase.

package require sqlite3
file copy -force ~/.cm/managed ~/.cm/managed.bak
sqlite3 CM       ~/.cm/managed

puts Restructure...
CM eval {
    CREATE TABLE new_location (
	    id			INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
	    --
	    city		INTEGER NOT NULL REFERENCES city,
	    name		TEXT    NOT NULL,	-- normalized lower-case
	    dname		TEXT    NOT NULL,
	    streetaddress	TEXT    NOT NULL,	-- normalized lower-case
	    dstreetaddress	TEXT    NOT NULL,
	    zipcode		TEXT    NOT NULL,	-- normalized upper-case
	    --
	    book_fax		TEXT,	-- defaults to the local-*
	    book_link		TEXT,
	    book_phone		TEXT,
	    local_fax		TEXT	UNIQUE,
	    local_link		TEXT	UNIQUE,
	    local_phone		TEXT	UNIQUE,
	    --
	    transportation	TEXT,			-- html block (maps, descriptions, etc)
	    --
	    UNIQUE (city, streetaddress),		-- addresses must be unique within a city
	    UNIQUE (city, name)				-- location names must be unique within a city
							--
							-- uniqueness using the normalized columns
							-- makes this case-insensitive.
    );

    -- Copy data -- placeholders for name, streetaddress, zip -- normalization is step 2
    INSERT
    INTO   new_location
    SELECT id, city, name, name, streetaddress, streetaddress, zipcode,
           book_fax, book_link, book_phone, 
           local_fax, local_link, local_phone, transportation
    FROM   location
    ;

    -- Switch things around
    DROP TABLE location
    ;
    ALTER TABLE new_location RENAME TO location
    ;
}

# Finalize change, build proper normalized (PK) values

puts -nonewline {Finalize... } ; flush stdout
CM eval {
    SELECT id, name, streetaddress, zipcode FROM location
} {
    puts -nonewline * ; flush stdout
    set name          [string tolower $name]
    set streetaddress [string tolower $streetaddress]
    set zipcode       [string toupper $zipcode]
    CM eval {
	UPDATE location
	SET    name          = :name
	,      streetaddress = :streetaddress
	,      zipcode       = :zipcode
	WHERE  id            = :id
    }
}
puts "="
exit
