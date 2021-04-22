
[//000000001]: # (pop3d::udb \- Tcl POP3 Server Package)
[//000000002]: # (Generated from file 'pop3d\_udb\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pop3d::udb\(n\) 1\.0\.1 tcllib "Tcl POP3 Server Package")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pop3d::udb \- Simple user database for pop3d

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require pop3d::udb ?1\.0\.1?  

[__::pop3d::udb::new__ ?*dbName*?](#1)  
[__dbName__ *option* ?*arg arg \.\.\.*?](#2)  
[*dbName* __destroy__](#3)  
[*dbName* __add__ *user pwd storage*](#4)  
[*dbName* __remove__ *user*](#5)  
[*dbName* __rename__ *user newName*](#6)  
[*dbName* __lookup__ *user*](#7)  
[*dbName* __exists__ *user*](#8)  
[*dbName* __who__](#9)  
[*dbName* __save__ ?*file*?](#10)  
[*dbName* __read__ *file*](#11)  

# <a name='description'></a>DESCRIPTION

The package __pop3d::udb__ provides simple in memory databases which can be
used in conjunction with the pop3 server core provided by the package
__[pop3d](pop3d\.md)__\. The databases will use the names of users as keys
and associates passwords and storage references with them\.

Objects created by this package can be directly used in the authentication
callback of pop3 servers following the same interface as servers created by the
package __[pop3d](pop3d\.md)__\.

  - <a name='1'></a>__::pop3d::udb::new__ ?*dbName*?

    This command creates a new database object with an associated global Tcl
    command whose name is *dbName*\.

The command __dbName__ may be used to invoke various operations on the
database\. It has the following general form:

  - <a name='2'></a>__dbName__ *option* ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

The following commands are possible for database objects:

  - <a name='3'></a>*dbName* __destroy__

    Destroys the database object\.

  - <a name='4'></a>*dbName* __add__ *user pwd storage*

    Add a new user or changes the data of an existing user\. Stores *password*
    and *storage* reference for the given *user*\.

  - <a name='5'></a>*dbName* __remove__ *user*

    Removes the specified *user* from the database\.

  - <a name='6'></a>*dbName* __rename__ *user newName*

    Changes the name of the specified *user* to *newName*\.

  - <a name='7'></a>*dbName* __lookup__ *user*

    Searches the database for the specified *user* and returns a two\-element
    list containing the associated password and storage reference, in this
    order\. Throws an error if the user could not be found\. This is the interface
    as expected by the authentication callback of package
    __[pop3d](pop3d\.md)__\.

  - <a name='8'></a>*dbName* __exists__ *user*

    Returns true if the specified *user* is known to the database, else false\.

  - <a name='9'></a>*dbName* __who__

    Returns a list of users known to the database\.

  - <a name='10'></a>*dbName* __save__ ?*file*?

    Saves the contents of the database into the given *file*\. If the file is
    not specified the system will use the path last used in a call to *dbName*
    __read__\. The generated file can be read by the __read__ method\.

  - <a name='11'></a>*dbName* __read__ *file*

    Reads the specified *file* and adds the contained user definitions to the
    database\. As the file is actually
    __[source](\.\./\.\./\.\./\.\./index\.md\#source)__'d a safe interpreter is
    employed to safeguard against malicious code\. This interpreter knows the
    __add__ command for adding users and their associated data to this
    database\. This command has the same argument signature as the method
    __add__\. The path of the *file* is remembered internally so that it
    can be used in the next call of *dbName* __save__ without an argument\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *pop3d* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[network](\.\./\.\./\.\./\.\./index\.md\#network),
[pop3](\.\./\.\./\.\./\.\./index\.md\#pop3),
[protocol](\.\./\.\./\.\./\.\./index\.md\#protocol)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
