set rev(form2.tcl) {$Header: /cvsroot/web/devxchg.site/community/tcl2005/forms.tcl,v 1.1.1.1 2005/10/18 02:41:14 clif Exp $}
#####################################################################
;# NAME:   
;# AUTHOR: Steve Uhler, Brent Welch, Clif Flynt
;# DATE:   199x, 2000-2003
;# DESC:   Handles creating and processing HTML forms within
;#         the httpd.tcl httpd server.  
;#         Part of the code is modified from examples in
;# 	   Practical Programming, some from the old Scriptics .tml
;#         files (Steve Uhler and Brent Welch, I think), and some from 
;#         Clif Flynt.  There might be some of Jeff Hobbs code in
;#         here as well.
;#
;# PARAMETERS:  
;#	   Many and varied.
;#
#####################################################################
# Parts of this code are written and copyrighted by Clif Flynt, 2003
#
# It is licenced for public use with these terms:
#
#  This licence agreement must remain intact with the code.
# 
#  You may use this code freely for non-commercial purposes.
#
#  You may sell this code or distribute it with a commercial product.
#
#  You may examine and modify the code to your heart's content.
#
#  You may not claim to have authored the code (aside from modifications
#  you may have made.)
#
#  You may not distribute the code without this license agreement
#
#  Maintenance, extension, modification, etc can be performed by:
#
#   Noumena Corporation
#   8888 Black Pine Ln
#   Whitmore Lake, MI  48189
#
#   Contact: clif@noucorp.com
#
#####################################################################

package require html
namespace eval form2 {
    variable Form2
    array set Form2 {
        star.0 "" 
	star.1 *
	missing ""
	invalid ""
    }

    variable btag <p>   ;# Could be <li>
    variable qnum
    variable cols       45

}



################################################################
# proc form2::Form_MultiPostProcess {id fields nextPage serialNum}--
#    Process a form
# Arguments
#   id		The identifier for this form, and the name 
#               of the directory that will contain data and 
#               Membership numbers
#   fields	A list of elements to display in the form
# fields format
#  {type   req key {text/selections} post}
#   input  1/0 key Label-beside     {}
#   select 1/0 key Label-beside     {default choice list}    
#   submit {}  key {text}           postP
#   break  1/0 {}  {}               {}
#   nextPage	The final page for this mess, relative or full URL
#   serialNum	Optional value if serial number req'd
# 
# Results
#   
# 
proc form2::Form_MultiPostProcess {id fields nextPage {memberNum -1} } {
    global page 
    variable Form2

    # set of [open /tmp/argh w]
    # puts $of "id $id fields $fields nextPage $nextPage memberNum $memberNum "
    # puts $of "DOCROOT $::Config(docRoot)"

    if {[form2::empty formid]} {
	# First time through the page
	set firstPass 1
    } else {
	# Incoming form values, check them
	set firstPass 0
	set memberNum [form2::data memberNum]
    }

    set html "<!-- Self-posting. Next page is $nextPage -->\n"
    append html "<form action=\"$page(url)\" method=post>\n"
    append html "<input type=hidden name=formid value=$id>\n"
    append html "<input type=hidden name=memberNum value=$memberNum>\n"
    append html "<div class=\"$id\">\n"
    append html [form2::genForm2 $id $firstPass $fields]

    append html "</div></form>\n"

    if {! $firstPass} {
	set ok [form2::checkRequired $fields]
	if {$ok} {
	    
	    set ok [${id}::validate $fields]
	    if {[llength $Form2(missing)] == 0 && $ok} {

		# No missing fields, so advance to the next page.
		# In practice, you must save the existing fields 
		# at this point before redirecting to the next page.

		set new [genBlankPage $id $fields $nextPage]

		set of [open /tmp/tst2 w]
		# puts $of "$Form2($id.calculate) $fields $nextPage"
		catch {
		    puts $of "NEW: ..$new.. -- $nextPage"
		    close $of
		}

		#		 Doc_Redirect $new
		set rtn [Redirect_Self $new]
		set of [open /tmp/tst2 a]
		puts $of $rtn
		close $of
	    }
	}
	if {!$ok} {
	    set msgMissing ""
	    set msgInvalid ""
	    if {!$ok} {
		if {[llength $Form2(invalid)] == 1} {
		    set msgInvalid {<div class="alert">Please correct this field: }
		} elseif {[llength $Form2(invalid)] != 0} {
		    # Skip if corrections are not there - just missing
		    set msgInvalid {<div class="alert">Please correct these fields: }
		}
		append msgInvalid [join $Form2(invalid) "<br "]
		append msgInvalid "</div><p>"
	    }
	    if {[llength $Form2(missing)] > 0} {
		if {[llength $Form2(missing)] == 1 } {
		    set msgMissing {<div clsss="alert">Please fill in this field:  }
		} elseif {[llength $Form2(missing)] > 1} {
		    set msgMissing {<div class="alert">Please fill in these fields:<br> }
		}
		append msgMissing [join $Form2(missing) "<br> "] 
	    }
	    set html "<P>\n$msgMissing\n<P>\n$msgInvalid\n$html"
	}
    }
    # catch {close $of}
    return $html
}

proc form2::checkRequired {fields} {
    set result 1

    foreach {type required key label post} $fields {
	if {$required} {
	    set val [string trim [form2::data $key]]
	    if {[string equal {} $val]} {
		# form2::appendIndex invalid "Need to fill in $label"
		set result 0
	    }
	}
    }

    return $result
}


proc form2::makeUniqueFileName {prefix} {
    set uniq 0
    while {[file exists ${prefix}_$uniq]} {
	incr uniq
    }
    return ${prefix}_$uniq
}

proc html::input {name dflt args} {
    return "<input name=\"$name\" value=\"$dflt\">"
}

proc html::label {name args} {
    return "<B>$name</B>"
}
proc html::break {args} {
    return "<br>"
}

################################################################
# proc form2::item {firstPass type key label post}--
#    Return the HTML for an form element
# Arguments
#   firstPass	1 if first time (no check) else 0
#   key		Key/name for this page variable
#   
# 
# Results
#   
# 
proc form2::item {firstPass type key label post} {
    switch $type {
	label {
	    set text "	    [eval [list html::$type $key ]]\n"
	}
	textInput {
	    set text "       [eval [list html::$type $key {} $post ]]\n"
	}
        submit {
	    set text "       <input type=submit name=$key value=$label>\n"
	}
	hidden {
	    set text "       $post <input type=hidden name=$key value=\"$post\">\n"
	}
	select {
	    set text "       [html::select $key {} $post]\n"
	}
	exact {
	    set text "       $key\n"
	}
	default {
	    set text "       [eval [list html::$type $key $label $post]]\n"
	}
    }
    return "$text"
}

################################################################
# proc form2::getFontDesc {firstPass req key } --
#    Returns a list of font on/font off depending on whether
#  this is the first pass, data is filled in, etc.
# Arguments
#   firstPass	1 if first time (no check) else 0
#   req		Is this required (1)
#   key		Key/name for this page variable
# 
# Results
#   Returns a list which may be two empty strings, or 
#   will be a start/end font descriptor.
# 
proc form2::getFontDesc {firstPass req key } {
    variable Form2
    if {(!$firstPass) && $req && [form2::empty $key]} {
        set startFont {  <div class="alert">}
	set endFont {</div>}
    } else {
        set startFont {}
	set endFont {}
    }
    return [list $startFont $endFont]
}

################################################################
# proc form2::genForm2 {id firstPass lst}--
#    Return a body for a table
# Arguments
#   id 		The identifier for this input section
#   firstPass	1 if first time (no check) else 0
#   lst		A list of descriptors, see above for format.
#   missingVar	VarName for a variable to get the missing count, 
#               if not firstPass
# Results
#   Returns a set of table row definitions, but not <TABLE>/</TABLE>

proc form2::genForm2 {id firstPass lst } {
    variable Form2
    set Form2(missing) {}
    
    set html [formBody $id $firstPass $lst]

    set Form2(missing) [string trim $Form2(missing) ", "]
    #
    # Check for input fields before adding the "Continue/Reset buttons.
    #
    if {([string first {type="text"} $html] > 0) ||
	([string first {<select name=} $html] > 0)} {
	append html {<p><input type=submit name=submit value=Continue>}
	append html {<input type="reset">}
    }
    return $html  
}

proc form2::formBody {id firstPass lst } {
    variable Form2

    append html "<input type=hidden name=formid value=$id>\n"

    foreach {type req key label post} $lst {
	
	if {$req} {
	    set style [string map [list [clock format [clock seconds] -format %Y] ""] $id]_required
	    if {$post eq ""} {
		set post " required "
	    } else {
		append style " required "
	    }
	} else {
	    set style [string map [list [clock format [clock seconds] -format %Y] ""] $id]
	}

	foreach {startFont endFont} \
	    [getFontDesc $firstPass $req $key ] {}
	
	if {![string match [string trim $startFont] ""]} {
	    regexp {([0-9a-zA-Z\.\ ,\-_]+)} $label all a
	    lappend Form2(missing) [string trim $a]
	}

	switch $type {
	    label {
		append html "  [eval [list form2::item $firstPass $type $key $label $post]]\n"
	    }
	    exact {
		append html "  [eval [list form2::item $firstPass $type $key $label $post]]\n"
	    }
	    default {
		append html "  <br> $startFont <label class=\"$style\"> $label</label> $endFont\n"
		append html "       [eval [list form2::item $firstPass $type $key $label $post]]\n"
	    }
	}      
    }
    return $html  
}


# form2::empty --
#
#       Return true if the variable doesn't exist or is an empty string

proc form2::empty {name} {
    set x [ncgi::empty $name]
    if {[string match $x ""]} {
        set x 0
    }
    return $x
}


proc form2::startNumber {i} {
    variable qnum $i
}
proc form2::incrNumber {} {
    variable qnum
    incr qnum
}


proc form2::getFormInfo {} {
    global page
    set html ""
    if {![info exist page(query)]} {
	return "<!-- no query data -->\n"
    }
    foreach {name value} $page(query) {
	if {[string match submit_* $name] || [string match token $name]} {
	    continue
	}
	append html "<input type=hidden name=\"$name\" value=\"$value\">\n"
    }
    return $html
}

# form2::line --
#
#	Display an entry in a table row

proc form2::line {name question {value {}}} {
    set html "<tr><td>$question\n</td><td><input type=text size=30 [form2::value $name]></td></tr>\n"
    return $html
}

proc form2::text {lines name question {value {}}} {
    variable btag
    variable cols
    if {$lines == 1} {
	set html "$btag$question\n<br><input type=text name=\"$name\" size=$cols value=\"$value\">\n"
    } else {
	set html "$btag$question\n<br><textarea name=\"$name\" cols=$cols rows=$lines>$value</textarea>\n"
    }
    return $html
}

proc form2::checkbox {name question {value yes}} {
    variable btag
    set html "$btag<input type=checkbox name=\"$name\" value=$value> $question\n\n"
}

proc form2::selectplain {name size choices} {
    set namevalue {}
    foreach c $choices {
	lappend namevalue $c $c
    }
    return [form2::select $name $size $namevalue]
}

proc form2::select {name size choices} {
    global page

    if {![form2::empty $name]} {
	array set query $page(query)
	set current $query($name)
    } else {
	set current ""
    }
    set html "<select name=\"$name\" size=$size>\n"
    foreach {v label} $choices {
	if {[string match $current $v]} {
	    set SEL SELECTED
	} else {
	    set SEL ""
	}
	append html "<option value=\"$v\" $SEL>$label\n"
    }
    append html "</select>\n"
    return $html
}

proc form2::classboxStart {} {
    set html "<table cellpadding=2>\n<tr valign=top><th>Course Description</th><th># Students</th><th>Travel?</th></tr>\n"
}

proc form2::classbox {name desc} {
    append html "<tr><td><input type=checkbox name=\"$name\" value=yes> $desc</td>\n"
    append html "<td><input type=text name=\"${name}_size\" size=6></td>\n"
    append html "<td><input type=checkbox name=\"{$name}_travel\" value=yes></td>\n"
    append html </tr>\n
}
proc form2::classboxEnd {} {
    set html "</table>"
}



proc form2::submit {label {name submit}} {
    variable btag
    set html "$btag<input type=submit name=\"$name\" value=\"$label\">\n"
}

# Return a name and value pair, where the value is initialized
# from existing form data, if any.

proc form2::value {name} {
    global page
    if {[catch {array set query $page(query)}] ||
	![info exist query($name)]} {
	return "name=$name value=\"\""
    }
    return "name=$name value=\"$query($name)\""
}

# Return a form value, or "" if the element is not defined in the query data.

proc form2::data {name} {
    global page
    if {[catch {array set query $page(query)}] ||
	![info exist query($name)]} {
	return ""
    }
    return $query($name)
}

# Like form2::value, but for checkboxes that need CHECKED

proc form2::checkvalue {name {value 1}} {
    global page
    if {[catch {array set query $page(query)}] ||
	![info exist query($name)]} {
	return "name=$name value=\"$value\""
    }
    foreach {n v} $page(query) {
	if {[string compare $name $n] == 0 &&
	    [string compare $value $v] == 0} {
	    return "name=$name value=\"$value\" CHECKED"
	}
    }
    return "name=$name value=\"$value\""
}

# Like form2::value, but for radioboxes that need CHECKED

proc form2::radiovalue {name value} {
    global page
    if {[catch {array set query $page(query)}] ||
	![info exist query($name)] ||
	[string compare $query($name) $value] != 0} {
	return "name=$name value=\"$value\""
    }
    return "name=$name value=\"$value\" CHECKED"
}

# form2::radioset --
#
#	Display a set of radio buttons while looking for an existing
#	value from the query data, if any.

proc form2::radioset {key sep list} {
    global page
    if {[info exist page(query)]} {
	array set query $page(query)
	set html "<!-- radioset $key $page(query) -->\n"
    }
    foreach {v label} $list {
	if {![form2::empty $key] &&
	    [string match $v $query($key)]} {
	    set SEL CHECKED
	} else {
	    set SEL ""
	}
	append html "<input type=radio name=$key value=$v $SEL> $label$sep"
    }
    return $html
}

# form2::checkset --
#
#	Display a set of check buttons while looking for an existing
#	value from the query data, if any.

proc form2::checkset {key sep list} {
    global page
    if {[info exist page(query)]} {
	array set query $page(query)
    }
    foreach {v label} $list {
	if {![empty query($key)] &&
	    [lsearch $query($key) $v] >= 0} {
	    set SEL CHECKED
	} else {
	    set SEL ""
	}
	append html "<input type=checkbox name=$key value=$v $SEL> $label$sep"
    }
    return $html
}


proc form2::setProc {index procName {new 0}} {
    variable Form2
    if {![info exists Form2($index)] && (!$new)} {
        error "$index is a bad index" "$index is a bad index"
    }

    if {[string equal [info procs $procName] {} ]} {
        error "$procName is a bad procedure" "$procName is a bad procedure"
    }
    set Form2($index) $procName
    return ""
}

proc form2::appendIndex {index value} {
    variable Form2

    if {![info exists Form2($index)]} {
        error "$index is a bad index" "$index is a bad index"
    }
    lappend Form2($index) $value
}

proc form2::setIndex {index value} {
    variable Form2

    if {![info exists Form2($index)]} {
        error "$index is a bad index" "$index is a bad index"
    }
    set Form2($index) $value
    return ""
}

proc form2::getIndex {index } {
    variable Form2

    if {![info exists Form2($index)]} {
        error "$index is a bad index" "$index is a bad index"
    }
    return $Form2($index)
}

proc form2::renameFile {path id value} {

    if {![file exists $path/inProcess_$id]} {
	return "This transaction was already completed"
    }

    if {[string match $value OK]} {
	file rename $path/inProcess_$id $path/confirm_$id
	set html "Transaction is confirmed OK for $id"
    } else {
	file rename $path/inProcess_$id $path/cancel_$id
	set html "Transaction is cancelled for $id"
    }
    return $html
}
# KEY: "testID for http pages"


proc form2::BAD_CSS_list2tableBody {columnCount data} {
    set pos -1;
    while {$pos < [llength $data]} {
	append html " \n<BR> <div class=\"line\">"
	for {set i 0} {$i < $columnCount} {incr i} {
	    append html " <span margin-right=[expr {($i+1)*20}]> [lindex $data [incr pos]]</span>"
	}
	append html " </div>\n"
    }
    return $html
}

proc form2::BAD_FORM_list2tableBody {columnCount data} {
    set pos -1;
    while {$pos < [llength $data]} {
	append html " \n<BR>"
	set item {label"}
      for {set i 0} {$i < $columnCount} {incr i} {
        append html "\n  <$item>[lindex $data [incr pos]]</[lindex $item 0]>"
	set item {input type="text" size="20em"}
      }
    }
    return $html
}

proc form2::list2tableBody {columnCount data} {
    set pos -1;
    while {$pos < [llength $data]} {
	append html " \n<TR>"
	for {set i 0} {$i < $columnCount} {incr i} {
	    append html "\n  <TD>[lindex $data [incr pos]]</TD>"
	}
    }
    return $html
}

proc form2::pairs2tableBody {data} {
    set html ""
    set i 0
    foreach {lbl val} $data {
	if {[string trim $lbl] eq ""} {continue}
	if {[string trim $val] eq "-"} {continue}
	append html "\n<tr>"
	append html "  <td>$lbl</td>\n"
	append html "    <td>$val</td>\n"
    }
    return $html
}

proc form2::pairs2FormRows {data} {
    set html ""
    set i 0
    foreach {lbl val} $data {
	if {[string trim $lbl] eq ""} {continue}
	append html "\n<br>"
	append html "  <label>$lbl</label>\n"
	append html "    <input name=n[incr i] type=text value=\"$val\">$val</input>\n"
    }
    return $html
}

proc form2::Form_Survey {id postProcess selections nextpage} {
    global page
    if {![form2::empty formid]} {
	# Incoming form values, check them
	set check 1
    } else {
	# First time through the page
	set check 0
    }
    set html "<!-- Self-posting. Next page is $nextpage -->\n"
    append html "<form action=\"$page(url)\" method=post>\n"
    append html "<input type=hidden name=formid value=$id>\n"
    
    append html {<TABLE border="1">}
    
    foreach entry $selections {
	foreach {txt name param choices dflt} $entry {break} 
	#	    append html "<TR>   <TD> $txt \n    <TD>"
	#	    append html [html::select $name $param $choices $dflt]
	append html "<TR>\n  <TD> [html::select $name $param $choices $dflt]\n"
	append html "  <TD> <A HREF=\"#$name\"> $txt </A>"
	lappend fields [list $txt $name]
    }
    append html </TABLE>
    
    # puts "CHECK: $check -- [info exist missing]"
    if {$check} {
	# puts "FORMID:  [form2::data formid]"
	if {![info exist missing]} {

	    # No missing fields, so advance to the next page.
	    # In practice, you must save the existing fields 
	    # at this point before redirecting to the next page.
	    
	    # puts "Reqired fields: $fields"
	    foreach f $fields {
		foreach {txt key} $f {break}
		lappend d [list $txt $key [form2::data $key]]
		# puts "$txt -- $key -- [form2::data $key]"
	    }
	    
	    $postProcess $d

	    Doc_Redirect $nextpage
	} 
    }

    append html "<BR><input type=submit>\n</form>\n"

    return $html
}

proc form2::SurveyProcess {dataList} {
    global Doc
    catch {source $Doc(root)/surveyData.tcl}

    foreach entry $dataList {
	foreach {txt key val} $entry {break} 
	if {[info exists survey($key.$val)]} {
	    incr survey($key.$val)
	} else {
	    set survey($key.$val) 1
	    set survey($key.text) $txt
	}
    }
    set of [open $Doc(root)/surveyData.tcl w]
    puts $of "array set survey [list [array get survey]]"
    close $of
}

proc form2::SurveyReport {} {
    global Doc
    source $Doc(root)/surveyData.tcl
    
    set fields ""
    set labels ""
    set keys ""

    foreach f [lsort [array names survey]] {
	foreach {k v} [split $f "."] {break;}
	if {[string match $v "text"]} {continue}
	if {[lsearch $fields $v] < 0} {lappend fields $v}
	if {[lsearch $keys $k] < 0} {lappend keys $k}
    }

    set txt ""
    set page "<TABLE>"
    append page "<TR> <TH> Title\n"

    foreach v [lsort $fields] {
	set l [lrange [split $v -] 1 end]
	append page "   <TH> $l\n"
    }

    foreach k $keys {
	append page "\n <TR><TD> $survey($k.text)\n"
	foreach f [lsort $fields] {
	    if {[info exists survey($k.$f)]} {
		append page "   <TD> $survey($k.$f)\n"
	    } else {
		append page "   <TD> 0\n"
	    }
	}
    }
    
    append page "</TABLE>"
    return $page
}

proc form2::incrSerialNum {id} {
    global page
    set fileName [file root $page(filename)]/$id.ser
    if {[catch {
	set if [open $fileName r]
    }]} {
	# auto-handle missing serial by creating a suitable starting point
	set serialNum [clock format [clock seconds] -format %Y]0000
    } else {
	set serialNum [gets $if]
	close $if
    }
    incr serialNum
    set of [open $fileName w]
    puts $of $serialNum
    close $of
    return $serialNum
}

proc form2::genBlankPage {id fields nextPage} {
    if {[info exists ${id}::PayPalURL]} {
	return [genRegisterBlankPage $id $fields $nextPage]
    } else {
	return [genSubmitBlankPage $id $fields $nextPage]
    }
}

proc form2::genSubmitBlankPage {id fields nextPage} {

    foreach {type required key label post} $fields {
	set val [form2::data $key]
	if {![string match $label ""] && [string match $val ""]} {
	    set val "-"
	}
	lappend lst $label $val
	append mail "$label: $val\n"
    }    
    
    set serNum [form2::incrSerialNum $id]
    lappend lst "ID Number" $serNum

    set if [open [file root $::page(filename)].tml r]
    set blank [read $if]
    close $if

    set p1 [string first "DO NOT" $blank ]
    set p1 [string first "\[" $blank $p1]  
    set p2 [string last "DO NOT" $blank ] 
    set p2 [string last  "\]" $blank $p2]
    incr p1 -1
    incr p2

    set pre [string range $blank 0 $p1]
    set post [string range $blank $p2 end]
    
    set fileBase [file dirname $::page(filename)]/submit_$serNum
    set of [open $fileBase.tml w]
    puts $of $pre
    puts $of [set ${id}::ConfirmMsg]
    puts $of <table>
    puts $of [form2::pairs2tableBody $lst]
    puts $of "</table>\n"
    puts $of [format {
	<form action="%s" method="post">\
	    <input type="hidden" name="memberNum" value="%s">
	<input type="hidden" name="invoice" value="%s">
	<input type="hidden" name="cmd" value="_xclick">} $nextPage $serNum $serNum]

    puts $of { <p><input type=submit name="submit" value="Submit">
	<input type=submit name="submit" value="Cancel">
	</form>}

    puts $of $post

    close $of
    after 100
    return [string map [list [file normalize $::Config(docRoot)] ""] $fileBase.html]
}

proc form2::genRegisterBlankPage {id fields nextPage} {

    foreach {type required key label post} $fields {
	set val [form2::data $key]
	if {![string match $label ""] && [string match $val ""]} {
	    set val "-"
	}
	lappend lst $label $val
    }    
    
    set total [${id}::calculate $fields]
    
    lappend lst Total $total
    set serNum [form2::incrSerialNum $id]
    lappend lst "ID Number" $serNum

    set if [open [file root $::page(filename)].tml r]
    set blank [read $if]
    close $if

    set p1 [string first "DO NOT" $blank ]
    set p1 [string first "\[" $blank $p1]  
    set p2 [string last "DO NOT" $blank ] 
    set p2 [string last "\]" $blank $p2]
    incr p1 -1
    incr p2

    set pre [string range $blank 0 $p1]
    set post [string range $blank $p2 end]
    
    set fileBase [file dirname $::page(filename)]/register_$serNum
    set of [open $fileBase.tml w]
    puts $of $pre
    puts $of [set ${id}::ConfirmMsg]
    puts $of <table>
    puts $of [form2::pairs2tableBody $lst]
    puts $of "</table>\n"
    puts $of [format {
	<form action="%s" method="post">\
	    <input type="hidden" name="cmd" value="_xclick">\
	    <input type="hidden" name="amount" value="%5.2f">
	<input type="hidden" name="no_shipping" value="1">
	<input type="hidden" name="business" value="%s">
	<input type="hidden" name="quantity" value="1">
	<input type="hidden" name="item_name" value="%s">
	<input type="hidden" name="cpp_header_image" value="%s">
	<input type="hidden" name="page_style" value="Editomat">
	<input type="hidden" name="return"  value="%s">
	<input type="hidden" name="memberNum" value="%s">
	<input type="hidden" name="invoice" value="%s">
	<input type="hidden" name="custom" value="%s">} \
		  [set ${id}::PayPalURL] \
		  $total \
		  [set ${id}::PayPalBusiness] \
		  [set ${id}::PayPalItem] \
		  [set ${id}::PayPalImage] \
		  [set ${id}::PayPalReturnURL] \
		  $serNum \
		  $serNum \
		  $serNum ]

    puts $of { <p><input type=submit name="submit" value="Purchase">
	<input type=submit name="submit" value="Cancel">
	</form>}

    puts $of $post
    close $of
    return [string map [list [file normalize $::Config(docRoot)] ""] $fileBase.html]
}
