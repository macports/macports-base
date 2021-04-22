# javascript.tcl --
#
#	This file contains procedures that create HTML and Java Script
#	functions that implement objects such as:
#
#		paired multi-selection boxes
#		guarded submit buttons
#		parent and child checkboxes
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: javascript.tcl,v 1.5 2005/09/30 05:36:39 andreas_kupries Exp $

package require Tcl 8
package require ncgi 1
package provide javascript 1.0.2


namespace eval ::javascript {

    # The SelectionObjList namespace variable is used to keep the list of
    # selection boxes that were created as parts of paired multi-selection
    # boxes.  When a submit button is made for pages that have paired
    # multi-selection boxes, we set a hidden field to store the initial values
    # in the box.

    variable SelectionObjList {}
}

# ::javascript::BeginJS --
#
#	Create HTML code to begin a java script program.
#
# Arguments:
#	none.
#
# Results:
#	Returns HTML code.

proc ::javascript::BeginJS {} {
    return "\n<SCRIPT LANGUAGE=\"JavaScript\">\n"
}

# ::javascript::EndJS --
#
#	Create HTML code to end a java script program.
#
# Arguments:
#	none.
#
# Results:
#	Returns HTML code.

proc ::javascript::EndJS {} {
    return "\n</SCRIPT>\n"
}

# ::javascript::MakeMultiSel --
#
#	Construct HTML code to create a multi-selection box.
#
# Arguments:
#	id		The suffix of all HTML objects in this megawidget.
#	side		Either "left" or "right".
#	eltValues	The values to populate the selection box with.
#	eltNames	The values to populate the selection box with.
#	emptyElts	The number of empty box entry to stuff in the
#			Selection box as placeholders for elts to be added.
#	length		The number of elts to show before adding a vertical
#			scrollbar.
#	minWidth	Number of spaces to determin the minimum box width.
#
# Results:
#	Returns HTML to show the selection box.

proc ::javascript::MakeMultiSel {id side eltValues eltNames emptyElts \
	length minWidth} {

    variable SelectionObjList

    # Add this selection box to the list.

    set name "$side$id"
    lappend SelectionObjList $name

    # Create the selection box and populate it with elts.

    set html ""
    append html "<select name=$name multiple size=$length>"
    foreach elt $eltValues name $eltNames {
	set encodedElt [ncgi::encode $elt]
	append html "<option value=$encodedElt>$name"
    }

    # Add empty values for the remaining elements.

    for {set i 0} {$i < $emptyElts} {incr i} {
	append html "<option value=\"\"> "
    }

    # Add an empty value with text that is as wide as the minWidth.

    set filler ""
    for {set i 0} {$i < $minWidth} {incr i} {
	append filler "&nbsp;&nbsp;"
    }
    append html "<option value=\"\">$filler"

    append html "</select>"
    return $html
}

# ::javascript::MakeClickProc --
#
#	Create a "moveSelected$id" java script procedure to move selected items
#	from one selection box to the other.
#
# Arguments:
#	id	The suffix of all objects in this multiselection megawidget.
#
# Results:
#	Returns java script code.

proc ::javascript::MakeClickProc {id} {

    set result "\nfunction moveSelected${id}(fromObj,toObj) \{\n"

    # If nothing is selected, do nothing.

    append result "\n    if (fromObj.selectedIndex > -1) \{"

    # Find the first empty element in the toObj.

    append result {
        for (var k = 0; toObj.options[k].value != ""; k++) {}
}

    # Move the selected elements from the fromObj to the end of the toObj.
    # Shift the objects in the fromObj to fill any empty spots.
    # Clear out any extra slots in the fromObj.
    # Deselect any selected elements (deselect with both 'selected = false'
    # and by setting selectedIndex to -1, because setting selectedIndex to
    # -1 didn't seem to clear selection on all windows browsers.

    append result {
        for (var i = fromObj.selectedIndex, j = fromObj.selectedIndex; fromObj.options[i].value != ""; i++) {
            if (fromObj.options[i].selected) {
                toObj.options[k].text = fromObj.options[i].text
                toObj.options[k++].value = fromObj.options[i].value
                fromObj.options[i].selected = false
            } else {
                fromObj.options[j].text = fromObj.options[i].text
                fromObj.options[j++].value = fromObj.options[i].value
            }
        }
        for (; j < i; j++) {
            fromObj.options[j].text = ""
            fromObj.options[j].value = ""
        }
        fromObj.selectedIndex = -1
}

    # Close the if statement and the function

    append result "    \}
\}
"
    return $result
}

# ::javascript::makeSelectorWidget --
#
#	Construct HTML code to create a dual-multi-selection megawidget.  This
#	megawidget consists of two side-by-side multi-selection boxes
#	separated by a left arrow and a right arrow button.  The right arrow
#	button moves all items selected in the left box to the right box.  The
#	left arrow button moves all items selected in the right box to the left
#	box.
#
# Arguments:
#	id		The suffix of all HTML objects in this megawidget.
#	leftLabel	The text that appears above the left selection box.
#	leftValueList	The values of items in the left selection box.
#	leftNameList	The names to appear in the left selection box.
#	rightLabel	The text that appears above the right selection box.
#	rightValueList	The values of items in the right selection box.
#	rightNameList	The names to appear in the right selection box.
#	length		(optional) The number of elts to show before adding a
#			vertical scrollbar.  Defaults to 8.
#	minWidth	(optional) The number of spaces to determin the
#			minimum box width.  Defaults to 32.
#
# Results:
#	Returns HTML to show the dual-multi-selection megawidget.

proc ::javascript::makeSelectorWidget {id leftLabel leftValueList leftNameList \
	rightLabel rightValueList rightNameList {length 8} {minWidth 32}} {

    set html ""
    append html [BeginJS] \
	    [MakeClickProc $id] \
	    [EndJS]

    append html "<table border=0 cellspacing=0 cellpadding=2>\n<tr><th>" \
	    $leftLabel "</th><th></th><th>" $rightLabel "</th></tr>\n<tr>"

    set leftLen [llength $leftValueList]
    set rightLen [llength $rightValueList]
    set len [expr {$leftLen + $rightLen}]

    append html "<td valign=top colspan=1>" \
	    [MakeMultiSel $id "left" $leftValueList $leftNameList \
		$rightLen $length $minWidth] \
	    "&nbsp;&nbsp;</td>\n"

    append html "<td>" \
	    "<table border=0 cellspacing=0 cellpadding=2>\n"

    set args "this.form.left${id},this.form.right${id}"

    append html "<tr><td><input type=button name=left${id}Button
    onClick=\"moveSelected${id}(${args})\" value=\" >> \"></td></tr>"

    set args "this.form.right${id},this.form.left${id}"

    append html "<tr><td><input type=button name=right${id}Button
	onClick=\"moveSelected${id}(${args})\" value=\" << \"></td></tr>"

    append html "</table>\n" \
	    "</td>\n"

    append html "<td valign=top colspan=1>" \
	    [MakeMultiSel $id "right" $rightValueList $rightNameList \
		$leftLen $length $minWidth] \
	    "&nbsp;&nbsp;</td>\n"

    append html "</tr>\n" \
	    "</table>\n"

    # Add a hidden field to collect the data.

    append html "<input type=hidden name=valleft${id} " \
	    "value=\"$leftValueList\">\n" \
	    "<input type=hidden name=valright${id} " \
	    "value=\"$rightValueList\">\n"

    return $html
}

# ::javascript::makeSubmitButton --
#
#	Create an HTML submit button that resets a hidden field for each
#	registered multi-selection box.
#
# Arguments:
#	name	the name of the HTML button object to create.
#	value	the label of the HTML button object to create.
#
# Results:
#	Returns HTML submit button code.

proc ::javascript::makeSubmitButton {name value} {
    variable SelectionObjList
    set html ""

    # Create the java script procedure that gathers the current values for each
    # registered multi-selection box.

    append html [BeginJS]
    append html "\nfunction getSelections(form) \{\n"

    # For each registered selection box, reset hidden field to
    # store nonempty values.

    foreach obj $SelectionObjList {
	set selObj "form.$obj"
	set hiddenObj "form.val$obj"
	append html "    var tmp$obj = \"\"\n"
	append html "    for (var i$obj = 0; i$obj < $selObj.length; i$obj++) {\n"
	append html "        if ($selObj.options\[i$obj\].value == \"\") {\n"
	append html "            break\n"
	append html "        }\n"
	append html "        tmp$obj += \" \" + $selObj.options\[i$obj\].value\n"
	append html "    }\n"
	append html "    $hiddenObj.value = tmp$obj \n"
    }
    append html "\}\n"
    append html [EndJS]

    # Empty the selection box for the next page.

    set SelectionObjList {}

    # Create the HTML submit button.

    append html "<input type=submit name=\"$name\" value=\"$value\" 
    onClick=\"getSelections(this.form)\">"

    return $html
}

# ::javascript::makeProtectedSubmitButton --
#
#	Create an HTML submit button that prompts the user with a
#	continue/cancel shutdown warning before the form is submitted.
#
# Arguments:
#	name	the name of the HTML button object to create.
#	value	the label of the HTML button object to create.
#	msg	The message to display when the button is pressed.
#
# Results:
#	Returns HTML submit button code.

proc ::javascript::makeProtectedSubmitButton {name value msg} {
    set html ""

    # Create the java script procedure that gives the user the option to cancel
    # the server shutdown request.

    append html [BeginJS]
    append html "\nfunction areYouSure${name}(form) \{\n"
    append html "    if (confirm(\"$msg\")) \{\n"
    append html "        return true\n"
    append html "    \} else \{\n"
    append html "        return false\n"
    append html "    \}\n"
    append html "\}\n"
    append html [EndJS]

    # Create the HTML submit button.

    append html "<input type=submit name=\"$name\" value=\"$value\" 
    onClick=\"return areYouSure${name}(this.form)\">"

    return $html
}

# ::javascript::makeMasterButton --
#
#	Create an HTML button that sets it's slave checkboxs to the boolean
#	value.
#
# Arguments:
#	master	the name of the child's parent html checkbox object.
#	value	the value of the master.
#	slaves	the name of child html checkbox object to create.
#	boolean	the java script boolean value that will be given to all the
#		slaves.  Must be true or false.
#
# Results:
#	Returns HTML code to create the child checkbox.

proc ::javascript::makeMasterButton {master value slavePattern boolean} {
    set html ""

    # Create the java script "checkMaster$name" proc that gets called when the
    # master checkbox is selected or de-selected.

    append html [BeginJS]
    append html "\nfunction checkMaster${master}(form) \{\n"
    append html "    for (var i = 0; i < form.elements.length; i++) \{\n"
    append html "        if (form.elements\[i\].name.match('$slavePattern')) \{\n"
    append html "            form.elements\[i\].checked = $boolean \n"
    append html "        \}\n"
    append html "    \}\n"

    append html "\}\n"
    append html [EndJS]
    
    # Create the HTML button object.

    append html "<input type=button name=\"$master\" value=\"$value\" " \
	    "onClick=\"checkMaster${master}(this.form)\">\n"

    return $html
}

# ::javascript::makeParentCheckbox --
#
#	Create an HTML checkbox and tie its value to that of it's child
#	checkbox.  If the parent is unchecked, the child is automatically
#	unchecked.
#
# Arguments:
#	parentName	the name of parent html checkbox object to create.
#	childName	the name of the parent's child html checkbox object
# Results:
#	Returns HTML code to create the child checkbox.

proc ::javascript::makeParentCheckbox {parentName childName} {
    set parentObj "form.$parentName"
    set childObj "form.$childName"
    set html ""

    # Create the java script "checkParent$name" proc that gets called when the
    # parent checkbox is selected or de-selected.

    append html [BeginJS]
    append html "\nfunction checkParent${parentName}(form) \{\n"
    append html "    if (!$parentObj.checked && $childObj.checked) \{\n"
    append html "        $childObj.checked = false\n"
    append html "    \}\n"
    append html "\}\n"
    append html [EndJS]

    # Create the HTML checkbox object.

    append html "<input type=checkbox name=$parentName value=1 " \
	    "onClick=\"checkParent${parentName}(this.form)\">"

    return $html
}

# ::javascript::makeChildCheckbox --
#
#	Create an HTML checkbox and tie its value to that of it's parent
#	checkbox.  If the child is checked, the parent is automatically
#	checked.
#
# Arguments:
#	parentName	the name of the child's parent html checkbox object
#	childName	the name of child html checkbox object to create.
#
# Results:
#	Returns HTML code to create the child checkbox.

proc ::javascript::makeChildCheckbox {parentName childName} {
    set parentObj "form.$parentName"
    set childObj "form.$childName"
    set html ""

    # Create the java script "checkChild$name" proc that gets called when the
    # child checkbox is selected or de-selected.

    append html [BeginJS]
    append html "\nfunction checkChild${childName}(form) \{\n"
    append html "    if ($childObj.checked && !$parentObj.checked) \{\n"
    append html "        $parentObj.checked = true\n"
    append html "    \}\n"
    append html "\}\n"
    append html [EndJS]

    # Create the HTML checkbox object.

    append html "<input type=checkbox name=$childName value=1 " \
	    "onClick=\"checkChild${childName}(this.form)\">"

    return $html
}
