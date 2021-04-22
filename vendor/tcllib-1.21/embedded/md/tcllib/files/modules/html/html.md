
[//000000001]: # (html \- HTML Generation)
[//000000002]: # (Generated from file 'html\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (html\(n\) 1\.5 tcllib "HTML Generation")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

html \- Procedures to generate HTML structures

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require html ?1\.5?  

[__::html::author__ *author*](#1)  
[__::html::bodyTag__ *args*](#2)  
[__::html::cell__ *param value* ?*tag*?](#3)  
[__::html::checkbox__ *name value*](#4)  
[__::html::checkSet__ *key sep list*](#5)  
[__::html::checkValue__ *name* ?*value*?](#6)  
[__::html::closeTag__](#7)  
[__::html::default__ *key* ?*param*?](#8)  
[__::html::description__ *description*](#9)  
[__::html::end__](#10)  
[__::html::eval__ *arg* ?*args*?](#11)  
[__::html::extractParam__ *param key* ?*varName*?](#12)  
[__::html::font__ *args*](#13)  
[__::html::for__ *start test next body*](#14)  
[__::html::foreach__ *varlist1 list1* ?*varlist2 list2 \.\.\.*? *body*](#15)  
[__::html::formValue__ *name* ?*defvalue*?](#16)  
[__::html::getFormInfo__ *args*](#17)  
[__::html::getTitle__](#18)  
[__::html::h__ *level string* ?*param*?](#19)  
[__::html::h1__ *string* ?*param*?](#20)  
[__::html::h2__ *string* ?*param*?](#21)  
[__::html::h3__ *string* ?*param*?](#22)  
[__::html::h4__ *string* ?*param*?](#23)  
[__::html::h5__ *string* ?*param*?](#24)  
[__::html::h6__ *string* ?*param*?](#25)  
[__::html::hdrRow__ *args*](#26)  
[__::html::head__ *title*](#27)  
[__::html::headTag__ *string*](#28)  
[__::html::html\_entities__ *string*](#29)  
[__::html::if__ *expr1 body1* ?__elseif__ *expr2 body2 \.\.\.*? ?__else__ *bodyN*?](#30)  
[__::html::init__ ?*list*?](#31)  
[__::html::keywords__ *args*](#32)  
[__::html::mailto__ *email* ?*subject*?](#33)  
[__::html::meta__ *args*](#34)  
[__::html::meta\_name__ *args*](#35)  
[__::html::meta\_equiv__ *args*](#36)  
[__::html::meta\_charset__ *charset*](#37)  
[__::html::css__ *href*](#38)  
[__::html::css\-clear__](#39)  
[__::html::js__ *href*](#40)  
[__::html::js\-clear__](#41)  
[__::html::minorList__ *list* ?*ordered*?](#42)  
[__::html::minorMenu__ *list* ?*sep*?](#43)  
[__::html::nl2br__ *string*](#44)  
[__::html::openTag__ *tag* ?*param*?](#45)  
[__::html::paramRow__ *list* ?*rparam*? ?*cparam*?](#46)  
[__::html::passwordInput__ ?*name*?](#47)  
[__::html::passwordInputRow__ *label* ?*name*?](#48)  
[__::html::quoteFormValue__ *value*](#49)  
[__::html::radioSet__ *key sep list*](#50)  
[__::html::radioValue__ *name value*](#51)  
[__::html::refresh__ *seconds url*](#52)  
[__::html::row__ *args*](#53)  
[__::html::select__ *name param choices* ?*current*?](#54)  
[__::html::selectPlain__ *name param choices* ?*current*?](#55)  
[__::html::set__ *var val*](#56)  
[__::html::submit__ *label* ?*name*? ?*title*?](#57)  
[__::html::tableFromArray__ *arrname* ?*param*? ?*pat*?](#58)  
[__::html::tableFromList__ *querylist* ?*param*?](#59)  
[__::html::textarea__ *name* ?*param*? ?*current*?](#60)  
[__::html::textInput__ *name value args*](#61)  
[__::html::textInputRow__ *label name value args*](#62)  
[__::html::varEmpty__ *name*](#63)  
[__::html::while__ *test body*](#64)  
[__::html::doctype__ *id*](#65)  
[__::html::wrapTag__ *tag* ?*text*? ?*args*?](#66)  

# <a name='description'></a>DESCRIPTION

The package __html__ provides commands that generate HTML\. These commands
typically return an HTML string as their result\. In particular, they do not
output their result to __stdout__\.

The command __::html::init__ should be called early to initialize the
module\. You can also use this procedure to define default values for HTML tag
parameters\.

  - <a name='1'></a>__::html::author__ *author*

    *Side effect only*\. Call this before __::html::head__ to define an
    author for the page\. The author is noted in a comment in the HEAD section\.

  - <a name='2'></a>__::html::bodyTag__ *args*

    Generate a *body* tag\. The tag parameters are taken from *args* or from
    the body\.\* attributes define with __::html::init__\.

  - <a name='3'></a>__::html::cell__ *param value* ?*tag*?

    Generate a *td* \(or *th*\) tag, a value, and a closing *td* \(or *th*\)
    tag\. The tag parameters come from *param* or TD\.\* attributes defined with
    __::html::init__\. This uses __::html::font__ to insert a standard
    *font* tag into the table cell\. The *tag* argument defaults to "td"\.

  - <a name='4'></a>__::html::checkbox__ *name value*

    Generate a *[checkbox](\.\./\.\./\.\./\.\./index\.md\#checkbox)* form element
    with the specified name and value\. This uses __::html::checkValue__\.

  - <a name='5'></a>__::html::checkSet__ *key sep list*

    Generate a set of *[checkbox](\.\./\.\./\.\./\.\./index\.md\#checkbox)* form
    elements and associated labels\. The *list* should contain an alternating
    list of labels and values\. This uses __::html::checkbox__\. All the
    *[checkbox](\.\./\.\./\.\./\.\./index\.md\#checkbox)* buttons share the same
    *key* for their name\. The *sep* is text used to separate the elements\.

  - <a name='6'></a>__::html::checkValue__ *name* ?*value*?

    Generate the "name=*name* value=*value*" for a
    *[checkbox](\.\./\.\./\.\./\.\./index\.md\#checkbox)* form element\. If the CGI
    variable *name* has the value *value*, then SELECTED is added to the
    return value\. *value* defaults to "1"\.

  - <a name='7'></a>__::html::closeTag__

    Pop a tag off the stack created by __::html::openTag__ and generate the
    corresponding close tag \(e\.g\., </body>\)\.

  - <a name='8'></a>__::html::default__ *key* ?*param*?

    This procedure is used by __::html::tagParam__ to generate the name,
    value list of parameters for a tag\. The __::html::default__ procedure is
    used to generate default values for those items not already in *param*\. If
    the value identified by *key* matches a value in *param* then this
    procedure returns the empty string\. Otherwise, it returns a
    "parameter=value" string for a form element identified by *key*\. The
    *key* has the form "tag\.parameter" \(e\.g\., body\.bgcolor\)\. Use
    __::html::init__ to register default values\. *param* defaults to the
    empty string\.

  - <a name='9'></a>__::html::description__ *description*

    *Side effect only*\. Call this before __::html::head__ to define a
    description *meta* tag for the page\. This tag is generated later in the
    call to __::html::head__\.

  - <a name='10'></a>__::html::end__

    Pop all open tags from the stack and generate the corresponding close HTML
    tags, \(e\.g\., </body></html>\)\.

  - <a name='11'></a>__::html::eval__ *arg* ?*args*?

    This procedure is similar to the built\-in Tcl __eval__ command\. The only
    difference is that it returns "" so it can be called from an HTML template
    file without appending unwanted results\.

  - <a name='12'></a>__::html::extractParam__ *param key* ?*varName*?

    This is a parsing procedure that extracts the value of *key* from
    *param*, which is a HTML\-style "name=quotedvalue" list\. *varName* is
    used as the name of a Tcl variable that is changed to have the value found
    in the parameters\. The function returns 1 if the parameter was found in
    *param*, otherwise it returns 0\. If the *varName* is not specified, then
    *key* is used as the variable name\.

  - <a name='13'></a>__::html::font__ *args*

    Generate a standard *font* tag\. The parameters to the tag are taken from
    *args* and the HTML defaults defined with __::html::init__\.

  - <a name='14'></a>__::html::for__ *start test next body*

    This procedure is similar to the built\-in Tcl __for__ control structure\.
    Rather than evaluating the body, it returns the subst'ed *body*\. Each
    iteration of the loop causes another string to be concatenated to the result
    value\.

  - <a name='15'></a>__::html::foreach__ *varlist1 list1* ?*varlist2 list2 \.\.\.*? *body*

    This procedure is similar to the built\-in Tcl
    __[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__ control structure\.
    Rather than evaluating the body, it returns the subst'ed *body*\. Each
    iteration of the loop causes another string to be concatenated to the result
    value\.

  - <a name='16'></a>__::html::formValue__ *name* ?*defvalue*?

    Return a name and value pair, where the value is initialized from existing
    CGI data, if any\. The result has this form:

        name="fred" value="freds value"

  - <a name='17'></a>__::html::getFormInfo__ *args*

    Generate hidden fields to capture form values\. If *args* is empty, then
    hidden fields are generated for all CGI values\. Otherwise args is a list of
    string match patterns for form element names\.

  - <a name='18'></a>__::html::getTitle__

    Return the title string, with out the surrounding *title* tag, set with a
    previous call to __::html::title__\.

  - <a name='19'></a>__::html::h__ *level string* ?*param*?

    Generate a heading \(e\.g\., *h__level__*\) tag\. The *string* is nested
    in the heading, and *param* is used for the tag parameters\.

  - <a name='20'></a>__::html::h1__ *string* ?*param*?

    Generate an *h1* tag\. See __::html::h__\.

  - <a name='21'></a>__::html::h2__ *string* ?*param*?

    Generate an *h2* tag\. See __::html::h__\.

  - <a name='22'></a>__::html::h3__ *string* ?*param*?

    Generate an *h3* tag\. See __::html::h__\.

  - <a name='23'></a>__::html::h4__ *string* ?*param*?

    Generate an *h4* tag\. See __::html::h__\.

  - <a name='24'></a>__::html::h5__ *string* ?*param*?

    Generate an *h5* tag\. See __::html::h__\.

  - <a name='25'></a>__::html::h6__ *string* ?*param*?

    Generate an *h6* tag\. See __::html::h__\.

  - <a name='26'></a>__::html::hdrRow__ *args*

    Generate a table row, including *tr* and *th* tags\. Each value in
    *args* is place into its own table cell\. This uses __::html::cell__\.

  - <a name='27'></a>__::html::head__ *title*

    Generate the *head* section that includes the page *title*\. If previous
    calls have been made to __::html::author__, __::html::keywords__,
    __::html::description__, or __::html::meta__ then additional tags
    are inserted into the *head* section\. This leaves an open
    *[html](\.\./\.\./\.\./\.\./index\.md\#html)* tag pushed on the stack with
    __::html::openTag__\.

  - <a name='28'></a>__::html::headTag__ *string*

    Save a tag for inclusion in the *head* section generated by
    __::html::head__\. The *string* is everything in the tag except the
    enclosing angle brackets, < >\.

  - <a name='29'></a>__::html::html\_entities__ *string*

    This command replaces all special characters in the *string* with their
    HTML entities and returns the modified text\.

  - <a name='30'></a>__::html::if__ *expr1 body1* ?__elseif__ *expr2 body2 \.\.\.*? ?__else__ *bodyN*?

    This procedure is similar to the built\-in Tcl __if__ control structure\.
    Rather than evaluating the body of the branch that is taken, it returns the
    subst'ed *body*\. Note that the syntax is slightly more restrictive than
    that of the built\-in Tcl __if__ control structure\.

  - <a name='31'></a>__::html::init__ ?*list*?

    __::html::init__ accepts a Tcl\-style name\-value list that defines values
    for items with a name of the form "tag\.parameter"\. For example, a default
    with key "body\.bgcolor" defines the background color for the *body* tag\.

  - <a name='32'></a>__::html::keywords__ *args*

    *Side effect only*\. Call this before __::html::head__ to define a
    keyword *meta* tag for the page\. The *meta* tag is included in the
    result of __::html::head__\.

  - <a name='33'></a>__::html::mailto__ *email* ?*subject*?

    Generate a hypertext link to a mailto: URL\.

  - <a name='34'></a>__::html::meta__ *args*

    Compatibility name for __html::meta\_name__\.

  - <a name='35'></a>__::html::meta\_name__ *args*

    *Side effect only*\. Call this before __::html::head__ to define a
    *meta* tag for the page\. The arguments \(*args*\) are a Tcl\-style name,
    value list that is used for the __name=__ and __content=__
    attributes of the *meta* tag\. The *meta* tag is included in the result
    of __::html::head__\.

  - <a name='36'></a>__::html::meta\_equiv__ *args*

    *Side effect only*\. Call this before __::html::head__ to define a
    *meta* tag for the page\. The arguments \(*args*\) are a Tcl\-style name,
    value list that is used for the __http\-equiv=__ and __content=__
    attributes of the *meta* tag\. The *meta* tag is included in the result
    of __::html::head__\.

  - <a name='37'></a>__::html::meta\_charset__ *charset*

    *Side effect only*\. Call this before __::html::head__ to define a
    *meta* tag for the page\. The *charset* is used with the __charset=__
    attribute of the *meta* tag\. The *meta* tag is included in the result of
    __::html::head__\.

  - <a name='38'></a>__::html::css__ *href*

    *Side effect only*\. Call this before __::html::head__ to define a
    *link* tag for a linked CSS document\. The *href* value is a HTTP URL to
    a CSS document\. The *link* tag is included in the result of
    __::html::head__\.

    Multiple calls of this command are allowed, enabling the use of multiple CSS
    document references\. In other words, the arguments of multiple calls are
    accumulated, and do not overwrite each other\.

  - <a name='39'></a>__::html::css\-clear__

    *Side effect only*\. Call this before __::html::head__ to clear all
    links to CSS documents\.

    Multiple calls of this command are allowed, doing nothing after the first of
    a sequence with no intervening __::html::css__\.

  - <a name='40'></a>__::html::js__ *href*

    *Side effect only*\. Call this before __::html::head__ to define a
    *script* tag for a linked JavaScript document\. The *href* is a HTTP URL
    to a JavaScript document\. The *script* tag is included in the result of
    __::html::head__\.

    Multiple calls of this command are allowed, enabling the use of multiple
    JavaScript document references\. In other words, the arguments of multiple
    calls are accumulated, and do not overwrite each other\.

  - <a name='41'></a>__::html::js\-clear__

    *Side effect only*\. Call this before __::html::head__ to clear all
    links to JavaScript documents\.

    Multiple calls of this command are allowed, doing nothing after the first of
    a sequence with no intervening __::html::js__\.

  - <a name='42'></a>__::html::minorList__ *list* ?*ordered*?

    Generate an ordered or unordered list of links\. The *list* is a Tcl\-style
    name, value list of labels and urls for the links\. *ordered* is a boolean
    used to choose between an ordered or unordered list\. It defaults to
    __false__\.

  - <a name='43'></a>__::html::minorMenu__ *list* ?*sep*?

    Generate a series of hypertext links\. The *list* is a Tcl\-style name,
    value list of labels and urls for the links\. The *sep* is the text to put
    between each link\. It defaults to " &#124; "\.

  - <a name='44'></a>__::html::nl2br__ *string*

    This command replaces all line\-endings in the *string* with a *br* tag
    and returns the modified text\.

  - <a name='45'></a>__::html::openTag__ *tag* ?*param*?

    Push *tag* onto a stack and generate the opening tag for *tag*\. Use
    __::html::closeTag__ to pop the tag from the stack\. The second argument
    provides any tag arguments, as a list whose elements are formatted to be in
    the form "__key__=__value__"\.

  - <a name='46'></a>__::html::paramRow__ *list* ?*rparam*? ?*cparam*?

    Generate a table row, including *tr* and *td* tags\. Each value in
    *list* is placed into its own table cell\. This uses __::html::cell__\.
    The value of *rparam* is used as parameter for the *tr* tag\. The value
    of *cparam* is passed to __::html::cell__ as parameter for the *td*
    tags\.

  - <a name='47'></a>__::html::passwordInput__ ?*name*?

    Generate an *input* tag of type
    *[password](\.\./\.\./\.\./\.\./index\.md\#password)*\. The *name* defaults to
    "password"\.

  - <a name='48'></a>__::html::passwordInputRow__ *label* ?*name*?

    Format a table row containing a label and an *input* tag of type
    *[password](\.\./\.\./\.\./\.\./index\.md\#password)*\. The *name* defaults to
    "password"\.

  - <a name='49'></a>__::html::quoteFormValue__ *value*

    Quote special characters in *value* by replacing them with HTML entities
    for quotes, ampersand, and angle brackets\.

  - <a name='50'></a>__::html::radioSet__ *key sep list*

    Generate a set of *input* tags of type *radio* and an associated text
    label\. All the radio buttons share the same *key* for their name\. The
    *sep* is text used to separate the elements\. The *list* is a Tcl\-style
    label, value list\.

  - <a name='51'></a>__::html::radioValue__ *name value*

    Generate the "name=*name* value=*value*" for a *radio* form element\.
    If the CGI variable *name* has the value *value*, then SELECTED is added
    to the return value\.

  - <a name='52'></a>__::html::refresh__ *seconds url*

    Set up a refresh *meta* tag\. Call this before __::html::head__ and the
    HEAD section will contain a *meta* tag that causes the document to refresh
    in *seconds* seconds\. The *url* is optional\. If specified, it specifies
    a new page to load after the refresh interval\.

  - <a name='53'></a>__::html::row__ *args*

    Generate a table row, including *tr* and *td* tags\. Each value in
    *args* is place into its own table cell\. This uses __::html::cell__\.
    Ignores any default information set up via __::html::init__\.

  - <a name='54'></a>__::html::select__ *name param choices* ?*current*?

    Generate a *select* form element and nested *option* tags\. The *name*
    and *param* are used to generate the *select* tag\. The *choices* list
    is a Tcl\-style name, value list\.

  - <a name='55'></a>__::html::selectPlain__ *name param choices* ?*current*?

    Like __::html::select__ except that *choices* is a Tcl list of values
    used for the *option* tags\. The label and the value for each *option*
    are the same\.

  - <a name='56'></a>__::html::set__ *var val*

    This procedure is similar to the built\-in Tcl
    __[set](\.\./\.\./\.\./\.\./index\.md\#set)__ command\. The main difference is
    that it returns "" so it can be called from an HTML template file without
    appending unwanted results\. The other difference is that it must take two
    arguments\.

  - <a name='57'></a>__::html::submit__ *label* ?*name*? ?*title*?

    Generate an *input* tag of type *submit*\. The *name* defaults to
    "submit"\. When a non\-empty *title* string is specified the button gains a
    __title=__ attribute with that value\.

  - <a name='58'></a>__::html::tableFromArray__ *arrname* ?*param*? ?*pat*?

    Generate a two\-column *[table](\.\./\.\./\.\./\.\./index\.md\#table)* and nested
    rows to display a Tcl array\. The table gets a heading that matches the array
    name, and each generated row contains a name, value pair\. The array names
    are sorted \(__lsort__ without special options\)\. The argument *param*
    is for the *[table](\.\./\.\./\.\./\.\./index\.md\#table)* tag and has to
    contain a pre\-formatted string\. The *pat* is a __string match__
    pattern used to select the array elements to show in the table\. It defaults
    to __\*__, i\.e\. the whole array is shown\.

  - <a name='59'></a>__::html::tableFromList__ *querylist* ?*param*?

    Generate a two\-column *[table](\.\./\.\./\.\./\.\./index\.md\#table)* and nested
    rows to display *querylist*, which is a Tcl dictionary\. Each generated row
    contains a name, value pair\. The information is shown in the same order as
    specified in the dictionary\. The argument *param* is for the
    *[table](\.\./\.\./\.\./\.\./index\.md\#table)* tag and has to contain a
    pre\-formatted string\.

  - <a name='60'></a>__::html::textarea__ *name* ?*param*? ?*current*?

    Generate a *textarea* tag wrapped around its current values\.

  - <a name='61'></a>__::html::textInput__ *name value args*

    Generate an *input* form tag with type
    *[text](\.\./\.\./\.\./\.\./index\.md\#text)*\. This uses
    __::html::formValue__\. The args is any additional tag attributes you
    want to put into the *input* tag\.

  - <a name='62'></a>__::html::textInputRow__ *label name value args*

    Generate an *input* form tag with type
    *[text](\.\./\.\./\.\./\.\./index\.md\#text)* formatted into a table row with an
    associated label\. The args is any additional tag attributes you want to put
    into the *input* tag\.

  - <a name='63'></a>__::html::varEmpty__ *name*

    This returns 1 if the named variable either does not exist or has the empty
    string for its value\.

  - <a name='64'></a>__::html::while__ *test body*

    This procedure is similar to the built\-in Tcl __while__ control
    structure\. Rather than evaluating the body, it returns the subst'ed
    *body*\. Each iteration of the loop causes another string to be
    concatenated to the result value\.

  - <a name='65'></a>__::html::doctype__ *id*

    This procedure can be used to build the standard DOCTYPE declaration string\.
    It will return the standard declaration string for the id, or throw an error
    if the id is not known\. The following id's are defined:

      1. HTML32

      1. HTML40

      1. HTML40T

      1. HTML40F

      1. HTML401

      1. HTML401T

      1. HTML401F

      1. XHTML10S

      1. XHTML10T

      1. XHTML10F

      1. XHTML11

      1. XHTMLB

  - <a name='66'></a>__::html::wrapTag__ *tag* ?*text*? ?*args*?

    A helper to wrap a *text* in a pair of open/close *tag*s\. The arguments
    \(*args*\) are a Tcl\-style name, value list that is used to provide
    attributes and associated values to the opening tag\. The result is a string
    with the open *tag* along with the optional attributes, the optional text,
    and the closed tag\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *html* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[htmlparse](\.\./htmlparse/htmlparse\.md), [ncgi](\.\./ncgi/ncgi\.md)

# <a name='keywords'></a>KEYWORDS

[checkbox](\.\./\.\./\.\./\.\./index\.md\#checkbox),
[checkbutton](\.\./\.\./\.\./\.\./index\.md\#checkbutton),
[form](\.\./\.\./\.\./\.\./index\.md\#form), [html](\.\./\.\./\.\./\.\./index\.md\#html),
[radiobutton](\.\./\.\./\.\./\.\./index\.md\#radiobutton),
[table](\.\./\.\./\.\./\.\./index\.md\#table)

# <a name='category'></a>CATEGORY

CGI programming
