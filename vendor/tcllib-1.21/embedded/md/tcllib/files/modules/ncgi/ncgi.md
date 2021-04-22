
[//000000001]: # (ncgi \- CGI Support)
[//000000002]: # (Generated from file 'ncgi\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (ncgi\(n\) 1\.4\.4 tcllib "CGI Support")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ncgi \- Procedures to manipulate CGI values\.

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [EXAMPLES](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require ncgi ?1\.4\.4?  

[__::ncgi::cookie__ *cookie*](#1)  
[__::ncgi::decode__ *str*](#2)  
[__::ncgi::empty__ *name*](#3)  
[__::ncgi::exists__ *name*](#4)  
[__::ncgi::encode__ *string*](#5)  
[__::ncgi::header__ ?*type*? *args*](#6)  
[__::ncgi::import__ *cginame* ?*tclname*?](#7)  
[__::ncgi::importAll__ *args*](#8)  
[__::ncgi::importFile__ *cmd* *cginame* ?*filename*?](#9)  
[__::ncgi::input__ ?*fakeinput*? ?*fakecookie*?](#10)  
[__::ncgi::multipart__ *type query*](#11)  
[__::ncgi::nvlist__](#12)  
[__::ncgi::names__](#13)  
[__::ncgi::parse__](#14)  
[__::ncgi::parseMimeValue__ *value*](#15)  
[__::ncgi::query__](#16)  
[__::ncgi::redirect__ *url*](#17)  
[__::ncgi::reset__ *query type*](#18)  
[__::ncgi::setCookie__ *args*](#19)  
[__::ncgi::setDefaultValue__ *key defvalue*](#20)  
[__::ncgi::setDefaultValueList__ *key defvaluelist*](#21)  
[__::ncgi::setValue__ *key value*](#22)  
[__::ncgi::setValueList__ *key valuelist*](#23)  
[__::ncgi::type__](#24)  
[__::ncgi::urlStub__ ?*url*?](#25)  
[__::ncgi::value__ *key* ?*default*?](#26)  
[__::ncgi::valueList__ *key* ?*default*?](#27)  

# <a name='description'></a>DESCRIPTION

The __ncgi__ package provides commands that manipulate CGI values\. These are
values that come from Web forms and are processed either by CGI scripts or web
pages with embedded Tcl code\. Use the __ncgi__ package to query these
values, set and get cookies, and encode and decode www\-url\-encoded values\.

In the simplest case, a CGI script first calls __::ncgi::parse__ and then
calls __::ncgi::value__ to get different form values\. If a CGI value is
repeated, you should use __::ncgi::valueList__ to get back the complete list
of values\.

An alternative to __::ncgi::parse__ is __::ncgi::input__, which has
semantics similar to Don Libes' __cgi\_input__ procedure\.
__::ncgi::input__ restricts repeated CGI values to have names that end with
"List"\. In this case, __::ncgi::value__ will return the complete list of
values, and __::ncgi::input__ will raise errors if it find repeated form
elements without the right name\.

The __::ncgi::reset__ procedure can be used in test suites and Web servers
to initialize the source of the CGI values\. Otherwise the values are read in
from the CGI environment\.

The complete set of procedures is described below\.

  - <a name='1'></a>__::ncgi::cookie__ *cookie*

    Return a list of values for *cookie*, if any\. It is possible that more
    than one cookie with the same name can be present, so this procedure returns
    a list\.

  - <a name='2'></a>__::ncgi::decode__ *str*

    Decode strings in www\-url\-encoding, which represents special characters with
    a %xx sequence, where xx is the character code in hex\.

  - <a name='3'></a>__::ncgi::empty__ *name*

    Returns 1 if the CGI variable *name* is not present or has the empty
    string as its value\.

  - <a name='4'></a>__::ncgi::exists__ *name*

    The return value is a boolean\. It returns __0__ if the CGI variable
    *name* is not present, and __1__ otherwise\.

  - <a name='5'></a>__::ncgi::encode__ *string*

    Encode *string* into www\-url\-encoded format\.

  - <a name='6'></a>__::ncgi::header__ ?*type*? *args*

    Output the CGI header to standard output\. This emits a Content\-Type: header
    and additional headers based on *args*, which is a list of header names
    and header values\. The *type* defaults to "text/html"\.

  - <a name='7'></a>__::ncgi::import__ *cginame* ?*tclname*?

    This creates a variable in the current scope with the value of the CGI
    variable *cginame*\. The name of the variable is *tclname*, or
    *cginame* if *tclname* is empty \(default\)\.

  - <a name='8'></a>__::ncgi::importAll__ *args*

    This imports several CGI variables as Tcl variables\. If *args* is empty,
    then every CGI value is imported\. Otherwise each CGI variable listed in
    *args* is imported\.

  - <a name='9'></a>__::ncgi::importFile__ *cmd* *cginame* ?*filename*?

    This provides information about an uploaded file from a form input field of
    type __file__ with name *cginame*\. *cmd* can be one of
    __\-server__ __\-client__, __\-type__ or __\-data__\.

      * __\-client__ *cginame*

        returns the filename as sent by the client\.

      * __\-type__ *cginame*

        returns the mime type of the uploaded file\.

      * __\-data__ *cginame*

        returns the contents of the file\.

      * __\-server__ *cginame* *filename*

        writes the file contents to a local temporary file \(or *filename* if
        supplied\) and returns the name of the file\. The caller is responsible
        for deleting this file after use\.

  - <a name='10'></a>__::ncgi::input__ ?*fakeinput*? ?*fakecookie*?

    This reads and decodes the CGI values from the environment\. It restricts
    repeated form values to have a trailing "List" in their name\. The CGI values
    are obtained later with the __::ncgi::value__ procedure\.

  - <a name='11'></a>__::ncgi::multipart__ *type query*

    This procedure parses a multipart/form\-data *query*\. This is used by
    __::ncgi::nvlist__ and not normally called directly\. It returns an
    alternating list of names and structured values\. Each structure value is in
    turn a list of two elements\. The first element is meta\-data from the
    multipart/form\-data structure\. The second element is the form value\. If you
    use __::ncgi::value__ you just get the form value\. If you use
    __::ncgi::valueList__ you get the structured value with meta data and
    the value\.

    The *type* is the whole Content\-Type, including the parameters like
    *boundary*\. This returns a list of names and values that describe the
    multipart data\. The values are a nested list structure that has some
    descriptive information first, and the actual form value second\. The
    descriptive information is list of header names and values that describe the
    content\.

  - <a name='12'></a>__::ncgi::nvlist__

    This returns all the query data as a name, value list\. In the case of
    multipart/form\-data, the values are structured as described in
    __::ncgi::multipart__\.

  - <a name='13'></a>__::ncgi::names__

    This returns all names found in the query data, as a list\.
    __::ncgi::multipart__\.

  - <a name='14'></a>__::ncgi::parse__

    This reads and decodes the CGI values from the environment\. The CGI values
    are obtained later with the __::ncgi::value__ procedure\. IF a CGI value
    is repeated, then you should use __::ncgi::valueList__ to get the
    complete list of values\.

  - <a name='15'></a>__::ncgi::parseMimeValue__ *value*

    This decodes the Content\-Type and other MIME headers that have the form of
    "primary value; param=val; p2=v2" It returns a list, where the first element
    is the primary value, and the second element is a list of parameter names
    and values\.

  - <a name='16'></a>__::ncgi::query__

    This returns the raw query data\.

  - <a name='17'></a>__::ncgi::redirect__ *url*

    Generate a response that causes a 302 redirect by the Web server\. The
    *url* is the new URL that is the target of the redirect\. The URL will be
    qualified with the current server and current directory, if necessary, to
    convert it into a full URL\.

  - <a name='18'></a>__::ncgi::reset__ *query type*

    Set the query data and Content\-Type for the current CGI session\. This is
    used by the test suite and by Web servers to initialize the ncgi module so
    it does not try to read standard input or use environment variables to get
    its data\. If neither *query* or *type* are specified, then the
    __ncgi__ module will look in the standard CGI environment for its data\.

  - <a name='19'></a>__::ncgi::setCookie__ *args*

    Set a cookie value that will be returned as part of the reply\. This must be
    done before __::ncgi::header__ or __::ncgi::redirect__ is called in
    order for the cookie to be returned properly\. The *args* are a set of
    flags and values:

      * __\-name__ *name*

      * __\-value__ *value*

      * __\-expires__ *date*

      * __\-path__ *path restriction*

      * __\-domain__ *domain restriction*

  - <a name='20'></a>__::ncgi::setDefaultValue__ *key defvalue*

    Set a CGI value if it does not already exists\. This affects future calls to
    __::ncgi::value__ \(but not future calls to __::ncgi::nvlist__\)\. If
    the CGI value already is present, then this procedure has no side effects\.

  - <a name='21'></a>__::ncgi::setDefaultValueList__ *key defvaluelist*

    Like __::ncgi::setDefaultValue__ except that the value already has list
    structure to represent multiple checkboxes or a multi\-selection\.

  - <a name='22'></a>__::ncgi::setValue__ *key value*

    Set a CGI value, overriding whatever was present in the CGI environment
    already\. This affects future calls to __::ncgi::value__ \(but not future
    calls to __::ncgi::nvlist__\)\.

  - <a name='23'></a>__::ncgi::setValueList__ *key valuelist*

    Like __::ncgi::setValue__ except that the value already has list
    structure to represent multiple checkboxes or a multi\-selection\.

  - <a name='24'></a>__::ncgi::type__

    Returns the Content\-Type of the current CGI values\.

  - <a name='25'></a>__::ncgi::urlStub__ ?*url*?

    Returns the current URL, but without the protocol, server, and port\. If
    *url* is specified, then it defines the URL for the current session\. That
    value will be returned by future calls to __::ncgi::urlStub__

  - <a name='26'></a>__::ncgi::value__ *key* ?*default*?

    Return the CGI value identified by *key*\. If the CGI value is not present,
    then the *default* value is returned instead\. This value defaults to the
    empty string\.

    If the form value *key* is repeated, then there are two cases: if
    __::ncgi::parse__ was called, then __::ncgi::value__ only returns
    the first value associated with *key*\. If __::ncgi::input__ was
    called, then __::ncgi::value__ returns a Tcl list value and *key* must
    end in "List" \(e\.g\., "skuList"\)\. In the case of multipart/form\-data, this
    procedure just returns the value of the form element\. If you want the
    meta\-data associated with each form value, then use
    __::ncgi::valueList__\.

  - <a name='27'></a>__::ncgi::valueList__ *key* ?*default*?

    Like __::ncgi::value__, but this always returns a list of values \(even
    if there is only one value\)\. In the case of multipart/form\-data, this
    procedure returns a list of two elements\. The first element is meta\-data in
    the form of a parameter, value list\. The second element is the form value\.

# <a name='section2'></a>EXAMPLES

Uploading a file

    HTML:
    <html>
    <form action="/cgi-bin/upload.cgi" method="POST" enctype="multipart/form-data">
    Path: <input type="file" name="filedata"><br>
    Name: <input type="text" name="filedesc"><br>
    <input type="submit">
    </form>
    </html>

    TCL: upload.cgi
    #!/usr/local/bin/tclsh

    ::ncgi::parse
    set filedata [::ncgi::value filedata]
    set filedesc [::ncgi::value filedesc]

    puts "<html> File uploaded at <a href=\"/images/$filedesc\">$filedesc</a> </html>"

    set filename /www/images/$filedesc

    set fh [open $filename w]
    puts -nonewline $fh $filedata
    close $fh

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ncgi* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

[html](\.\./html/html\.md)

# <a name='keywords'></a>KEYWORDS

[CGI](\.\./\.\./\.\./\.\./index\.md\#cgi), [cookie](\.\./\.\./\.\./\.\./index\.md\#cookie),
[form](\.\./\.\./\.\./\.\./index\.md\#form), [html](\.\./\.\./\.\./\.\./index\.md\#html)

# <a name='category'></a>CATEGORY

CGI programming
