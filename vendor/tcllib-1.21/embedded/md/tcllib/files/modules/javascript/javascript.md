
[//000000001]: # (javascript \- HTML and Java Script Generation)
[//000000002]: # (Generated from file 'javascript\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (javascript\(n\) 1\.0\.2 tcllib "HTML and Java Script Generation")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

javascript \- Procedures to generate HTML and Java Script structures\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8  
package require javascript ?1\.0\.2?  

[__::javascript::makeSelectorWidget__ *id leftLabel leftValueList rightLabel rightValueList rightNameList* ?*length*? ?*minWidth*?](#1)  
[__::javascript::makeSubmitButton__ *name value*](#2)  
[__::javascript::makeProtectedSubmitButton__ *name value msg*](#3)  
[__::javascript::makeMasterButton__ *master value slavePattern boolean*](#4)  
[__::javascript::makeParentCheckbox__ *parentName childName*](#5)  
[__::javascript::makeChildCheckbox__ *parentName childName*](#6)  

# <a name='description'></a>DESCRIPTION

The __::javascript__ package provides commands that generate HTML and Java
Script code\. These commands typically return an HTML string as their result\. In
particular, they do not output their result to __stdout__\.

  - <a name='1'></a>__::javascript::makeSelectorWidget__ *id leftLabel leftValueList rightLabel rightValueList rightNameList* ?*length*? ?*minWidth*?

    Construct HTML code to create a dual\-multi\-selection megawidget\. This
    megawidget consists of two side\-by\-side multi\-selection boxes separated by a
    left arrow and a right arrow button\. The right arrow button moves all items
    selected in the left box to the right box\. The left arrow button moves all
    items selected in the right box to the left box\. The *id* argument is the
    suffix of all HTML objects in this megawidget\. The *leftLabel* argument is
    the text that appears above the left selection box\. The *leftValueList*
    argument is the values of items in the left selection box\. The
    *leftNameList* argument is the names to appear in the left selection box\.
    The *rightLabel* argument is the text that appears above the right
    selection box\. The *rightValueList* argument is the values of items in the
    right selection box\. The *rightNameList* argument is the names to appear
    in the right selection box\. The *length* argument \(optional\) determines
    the number of elts to show before adding a vertical scrollbar; it defaults
    to 8\. The *minWidth* argument \(optional\) is the number of spaces to
    determine the minimum box width; it defaults to 32\.

  - <a name='2'></a>__::javascript::makeSubmitButton__ *name value*

    Create an HTML submit button that resets a hidden field for each registered
    multi\-selection box\. The *name* argument is the name of the HTML button
    object to create\. The *value* argument is the label of the HTML button
    object to create\.

  - <a name='3'></a>__::javascript::makeProtectedSubmitButton__ *name value msg*

    Create an HTML submit button that prompts the user with a continue/cancel
    shutdown warning before the form is submitted\. The *name* argument is the
    name of the HTML button object to create\. The *value* argument is the
    label of the HTML button object to create\. The *msg* argument is the
    message to display when the button is pressed\.

  - <a name='4'></a>__::javascript::makeMasterButton__ *master value slavePattern boolean*

    Create an HTML button that sets its slave checkboxs to the boolean value\.
    The *master* argument is the name of the child's parent html checkbox
    object\. The *value* argument is the value of the master\. The *slaves*
    argument is the name of child html checkbox object to create\. The
    *boolean* argument is the java script boolean value that will be given to
    all the slaves; it must be "true" or "false"\.

  - <a name='5'></a>__::javascript::makeParentCheckbox__ *parentName childName*

    Create an HTML checkbox and tie its value to that of its child checkbox\. If
    the parent is unchecked, the child is automatically unchecked\. The
    *parentName* argument is the name of parent html checkbox object to
    create\. The *childName* argument is the name of the parent's child html
    checkbox object\.

  - <a name='6'></a>__::javascript::makeChildCheckbox__ *parentName childName*

    Create an HTML checkbox and tie its value to that of its parent checkbox\. If
    the child is checked, the parent is automatically checked\. The
    *parentName* argument is the name of the child's parent html checkbox
    object\. The *childName* argument is the name of child html checkbox object
    to create\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *javascript* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[html](\.\./html/html\.md), [ncgi](\.\./ncgi/ncgi\.md)

# <a name='keywords'></a>KEYWORDS

[checkbox](\.\./\.\./\.\./\.\./index\.md\#checkbox),
[html](\.\./\.\./\.\./\.\./index\.md\#html),
[javascript](\.\./\.\./\.\./\.\./index\.md\#javascript),
[selectionbox](\.\./\.\./\.\./\.\./index\.md\#selectionbox),
[submitbutton](\.\./\.\./\.\./\.\./index\.md\#submitbutton)

# <a name='category'></a>CATEGORY

CGI programming
