
[//000000001]: # (pop3d::dbox \- Tcl POP3 Server Package)
[//000000002]: # (Generated from file 'pop3d\_dbox\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>)
[//000000004]: # (pop3d::dbox\(n\) 1\.0\.2 tcllib "Tcl POP3 Server Package")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

pop3d::dbox \- Simple mailbox database for pop3d

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.3  
package require pop3d::dbox ?1\.0\.2?  

[__::pop3d::dbox::new__ ?*dbName*?](#1)  
[__dbName__ *option* ?*arg arg \.\.\.*?](#2)  
[*dbName* __destroy__](#3)  
[*dbName* __base__ *base*](#4)  
[*dbName* __add__ *mbox*](#5)  
[*dbName* __remove__ *mbox*](#6)  
[*dbName* __move__ *old new*](#7)  
[*dbName* __list__](#8)  
[*dbName* __exists__ *mbox*](#9)  
[*dbName* __locked__ *mbox*](#10)  
[*dbName* __lock__ *mbox*](#11)  
[*dbName* __unlock__ *mbox*](#12)  
[*dbName* __stat__ *mbox*](#13)  
[*dbName* __size__ *mbox* ?*msgId*?](#14)  
[*dbName* __dele__ *mbox msgList*](#15)  
[*storageCmd* __get__ *mbox* *msgId*](#16)  

# <a name='description'></a>DESCRIPTION

The package __pop3d::dbox__ provides simple/basic mailbox management
facilities\. Each mailbox object manages a single base directory whose
subdirectories represent the managed mailboxes\. Mails in a mailbox are
represented by files in a mailbox directory, where each of these files contains
a single mail, both headers and body, in RFC 822
\([http://www\.rfc\-editor\.org/rfc/rfc822\.txt](http://www\.rfc\-editor\.org/rfc/rfc822\.txt)\)
conformant format\.

Any mailbox object following the interface described below can be used in
conjunction with the pop3 server core provided by the package
__[pop3d](pop3d\.md)__\. It is especially possible to directly use the
objects created by this package in the storage callback of pop3 servers
following the same interface as servers created by the package
__[pop3d](pop3d\.md)__\.

  - <a name='1'></a>__::pop3d::dbox::new__ ?*dbName*?

    This command creates a new database object with an associated global Tcl
    command whose name is *dbName*\.

The command __dbName__ may be used to invoke various operations on the
database\. It has the following general form:

  - <a name='2'></a>__dbName__ *option* ?*arg arg \.\.\.*?

    *Option* and the *arg*s determine the exact behavior of the command\.

The following commands are possible for database objects:

  - <a name='3'></a>*dbName* __destroy__

    Destroys the mailbox database and all transient data\. The directory
    associated with the object is not destroyed\.

  - <a name='4'></a>*dbName* __base__ *base*

    Defines the base directory containing the mailboxes to manage\. If this
    method is not called none of the following methods will work\.

  - <a name='5'></a>*dbName* __add__ *mbox*

    Adds a mailbox of name *mbox* to the database\. The name must be a valid
    path component\.

  - <a name='6'></a>*dbName* __remove__ *mbox*

    Removes the mailbox specified through *mbox*, and the mails contained
    therein, from the database\. This method will fail if the specified mailbox
    is locked\.

  - <a name='7'></a>*dbName* __move__ *old new*

    Changes the name of the mailbox *old* to *new*\.

  - <a name='8'></a>*dbName* __list__

    Returns a list containing the names of all mailboxes in the directory
    associated with the database\.

  - <a name='9'></a>*dbName* __exists__ *mbox*

    Returns true if the mailbox with name *mbox* exists in the database, or
    false if not\.

  - <a name='10'></a>*dbName* __locked__ *mbox*

    Checks if the mailbox specified through *mbox* is currently locked\.

  - <a name='11'></a>*dbName* __lock__ *mbox*

    This method locks the specified mailbox for use by a single connection to
    the server\. This is necessary to prevent havoc if several connections to the
    same mailbox are open\. The complementary method is __unlock__\. The
    command will return true if the lock could be set successfully or false if
    not\.

  - <a name='12'></a>*dbName* __unlock__ *mbox*

    This is the complementary method to __lock__, it revokes the lock on the
    specified mailbox\.

  - <a name='13'></a>*dbName* __stat__ *mbox*

    Determines the number of messages in the specified mailbox and returns this
    number\. This method fails if the mailbox *mbox* is not locked\.

  - <a name='14'></a>*dbName* __size__ *mbox* ?*msgId*?

    Determines the size of the message specified through its id in *msgId*, in
    bytes, and returns this number\. The command will return the size of the
    whole maildrop if no message id was specified\. If specified the *msgId*
    has to be in the range "1 \.\.\. \[*dbName* __stat__\]" or this call will
    fail\. If __stat__ was not called before this call, __size__ will
    assume that there are zero messages in the mailbox\.

  - <a name='15'></a>*dbName* __dele__ *mbox msgList*

    Deletes the messages whose numeric ids are contained in the *msgList* from
    the mailbox specified via *mbox*\. The *msgList* must not be empty or
    this call will fail\. The numeric ids in *msgList* have to be in the range
    "1 \.\.\. \[*dbName* __stat__\]" or this call will fail\. If __stat__
    was not called before this call, __dele__ will assume that there are
    zero messages in the mailbox\.

  - <a name='16'></a>*storageCmd* __get__ *mbox* *msgId*

    Returns a handle for the specified message\. This handle is a mime token
    following the interface described in the documentation of package
    __[mime](\.\./mime/mime\.md)__\. The token is *read\-only*\. In other
    words, the caller is allowed to do anything with the token except to modify
    it\. The *msgId* has to be in the range "1 \.\.\. \[*dbName* __stat__\]"
    or this call will fail\. If __stat__ was not called before this call,
    __get__ will assume that there are zero messages in the mailbox\.

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
[protocol](\.\./\.\./\.\./\.\./index\.md\#protocol), [rfc
822](\.\./\.\./\.\./\.\./index\.md\#rfc\_822)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002 Andreas Kupries <andreas\_kupries@users\.sourceforge\.net>
