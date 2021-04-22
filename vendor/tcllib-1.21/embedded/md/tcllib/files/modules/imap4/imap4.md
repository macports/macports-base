
[//000000001]: # (imap4 \- imap client)
[//000000002]: # (Generated from file 'imap4\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (imap4\(n\) 0\.5\.3 tcllib "imap client")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

imap4 \- imap client\-side tcl implementation of imap protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [PROCEDURES](#section2)

  - [EXAMPLES](#section3)

  - [TLS Security Considerations](#section4)

  - [REFERENCES](#section5)

  - [Bugs, Ideas, Feedback](#section6)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require imap4 ?0\.5\.3?  

[__::imap4::open__ *hostname* ?*port*?](#1)  
[__::imap4::starttls__ *chan*](#2)  
[__::imap4::login__ *chan* *user* *pass*](#3)  
[__::imap4::folders__ *chan* ?*\-inline*? ?*mboxref*? ?*mboxname*?](#4)  
[__::imap4::select__ *chan* ?*mailbox*?](#5)  
[__::imap4::examine__ *chan* ?*mailbox*?](#6)  
[__::imap4::fetch__ *chan* *range* ?*\-inline*? ?*attr \.\.\.*?](#7)  
[__::imap4::noop__ *chan*](#8)  
[__::imap4::check__ *chan*](#9)  
[__::imap4::folderinfo__ *chan* ?*info*?](#10)  
[__::imap4::msginfo__ *chan* *msgid* ?*info*? ?*defval*?](#11)  
[__::imap4::mboxinfo__ *chan* ?*info*?](#12)  
[__::imap4::isableto__ *chan* ?*capability*?](#13)  
[__::imap4::create__ *chan* *mailbox*](#14)  
[__::imap4::delete__ *chan* *mailbox*](#15)  
[__::imap4::rename__ *chan* *oldname* *newname*](#16)  
[__::imap4::subscribe__ *chan* *mailbox*](#17)  
[__::imap4::unsubscribe__ *chan* *mailbox*](#18)  
[__::imap4::search__ *chan* *expr* ?*\.\.\.*?](#19)  
[__::imap4::close__ *chan*](#20)  
[__::imap4::cleanup__ *chan*](#21)  
[__::imap4::debugmode__ *chan* ?*errormsg*?](#22)  
[__::imap4::store__ *chan* *range* *data* *flaglist*](#23)  
[__::imap4::expunge__ *chan*](#24)  
[__::imap4::copy__ *chan* *msgid* *mailbox*](#25)  
[__::imap4::logout__ *chan*](#26)  

# <a name='description'></a>DESCRIPTION

The __imap4__ library package provides the client side of the *Internet
Message Access Protocol* \(IMAP\) using standard sockets or secure connection via
TLS/SSL\. The package is fully implemented in Tcl\.

This document describes the procedures and explains their usage\.

# <a name='section2'></a>PROCEDURES

This package defines the following public procedures:

  - <a name='1'></a>__::imap4::open__ *hostname* ?*port*?

    Open a new IMAP connection and initalize the handler, the imap communication
    channel \(handler\) is returned\.

    *hostname* \- mail server

    *port* \- connection port, defaults to 143

    The namespace variable __::imap4::use\_ssl__ can be used to establish to
    a secure connection via TSL/SSL if set to true\. In this case default
    connection port defaults to 993\.

    *Note:* For connecting via SSL the Tcl module *tls* must be already
    loaded otherwise an error is raised\.

        package require tls              ; # must be loaded for TLS/SSL
        set ::imap4::use_ssl 1           ; # request a secure connection
        set chan [::imap4::open $server] ; # default port is now 993

  - <a name='2'></a>__::imap4::starttls__ *chan*

    Use this when tasked with connecting to an unsecure port which must be
    changed to a secure port prior to user login\. This feature is known as
    *STARTTLS*\.

  - <a name='3'></a>__::imap4::login__ *chan* *user* *pass*

    Login using the IMAP LOGIN command, 0 is returned on successful login\.

    *chan* \- imap channel

    *user* \- username

    *pass* \- password

  - <a name='4'></a>__::imap4::folders__ *chan* ?*\-inline*? ?*mboxref*? ?*mboxname*?

    Get list of matching folders, 0 is returned on success\.

    Wildcards '\*' as '%' are allowed for *mboxref* and *mboxname*, command
    __::imap4::folderinfo__ can be used to retrieve folder information\.

    *chan* \- imap channel

    *mboxref* \- mailbox reference, defaults to ""

    *mboxname* \- mailbox name, defaults to "\*"

    If __\-inline__ is specified a compact folderlist is returned instead of
    the result code\. All flags are converted to lowercase and leading special
    characters are removed\.

        {{Arc08 noselect} {Arc08/Private {noinferiors unmarked}} {INBOX noinferiors}}

  - <a name='5'></a>__::imap4::select__ *chan* ?*mailbox*?

    Select a mailbox, 0 is returned on success\.

    *chan* \- imap channel

    *mailbox* \- Path of the mailbox, defaults to *INBOX*

    Prior to examine/select an open mailbox must be closed \- see:
    __::imap4::close__\.

  - <a name='6'></a>__::imap4::examine__ *chan* ?*mailbox*?

    "Examines" a mailbox, read\-only equivalent of __::imap4::select__\.

    *chan* \- imap channel

    *mailbox* \- mailbox name or path to mailbox, defaults to *INBOX*

    Prior to examine/select an open mailbox must be closed \- see:
    __::imap4::close__\.

  - <a name='7'></a>__::imap4::fetch__ *chan* *range* ?*\-inline*? ?*attr \.\.\.*?

    Fetch attributes from messages\.

    The attributes are fetched and stored in the internal state which can be
    retrieved with command __::imap4::msginfo__, 0 is returned on success\.
    If __\-inline__ is specified, alle records are returned as list in order
    as defined in the *attr* argument\.

    *chan* \- imap channel

    *range* \- message index in format *FROM*:*TO*

    *attr* \- imap attributes to fetch

    *Note:* If *FROM* is omitted, the 1st message is assumed, if *TO* is
    ommitted the last message is assumed\. All message index ranges are 1\-based\.

  - <a name='8'></a>__::imap4::noop__ *chan*

    Send NOOP command to server\. May get information as untagged data\.

    *chan* \- imap channel

  - <a name='9'></a>__::imap4::check__ *chan*

    Send CHECK command to server\. Flush to disk\.

    *chan* \- imap channel

  - <a name='10'></a>__::imap4::folderinfo__ *chan* ?*info*?

    Get information on the recently selected folderlist\. If the *info*
    argument is omitted or a null string, the full list of information available
    for the mailbox is returned\.

    If the required information name is suffixed with a ? character, the command
    returns true if the information is available, or false if it is not\.

    *chan* \- imap channel

    *info* \- folderlist options to retrieve

    Currently supported options: *delim* \- hierarchy delimiter only, *match*
    \- ref and mbox search patterns \(see __::imap4::folders__\), *names* \-
    list of folder names only, *flags* \- list of folder names with flags in
    format *\{ \{name \{flags\}\} \.\.\. \}* \(see also compact format in function
    __::imap4::folders__\)\.

        {{Arc08 {{\NoSelect}}} {Arc08/Private {{\NoInferiors} {\UnMarked}}} {INBOX {\NoInferiors}}}

  - <a name='11'></a>__::imap4::msginfo__ *chan* *msgid* ?*info*? ?*defval*?

    Get information \(from previously collected using fetch\) from a given
    *msgid*\. If the 'info' argument is omitted or a null string, the list of
    available information options for the given message is returned\.

    If the required information name is suffixed with a ? character, the command
    returns true if the information is available, or false if it is not\.

    *chan* \- imap channel

    *msgid* \- message number

    *info* \- imap keyword to retrieve

    *defval* \- default value, returned if info is empty

    *Note:* All message index ranges are 1\-based\.

  - <a name='12'></a>__::imap4::mboxinfo__ *chan* ?*info*?

    Get information on the currently selected mailbox\. If the *info* argument
    is omitted or a null string, the list of available information options for
    the mailbox is returned\.

    If the required information name is suffixed with a ? character, the command
    returns true if the information is available, or false if it is not\.

    *chan* \- imap channel

    *opt* \- mailbox option to retrieve

    Currently supported options: *EXISTS* \(noof msgs\), *RECENT* \(noof
    'recent' flagged msgs\), *FLAGS*

    In conjunction with OK: *PERMFLAGS*, *UIDNEXT*, *UIDVAL*, *UNSEEN*

    Div\. states: *CURRENT*, *FOUND*, *PERM*\.

        ::imap4::select $chan INBOX
        puts "[::imap4::mboxinfo $chan exists] mails in INBOX"

  - <a name='13'></a>__::imap4::isableto__ *chan* ?*capability*?

    Test for capability\. It returns 1 if requested capability is supported, 0
    otherwise\. If *capability* is omitted all capability imap codes are
    retured as list\.

    *chan* \- imap channel

    *info* \- imap keyword to retrieve

    *Note:* Use the capability command to ask the server if not already done
    by the user\.

  - <a name='14'></a>__::imap4::create__ *chan* *mailbox*

    Create a new mailbox\.

    *chan* \- imap channel

    *mailbox* \- mailbox name

  - <a name='15'></a>__::imap4::delete__ *chan* *mailbox*

    Delete a new mailbox\.

    *chan* \- imap channel

    *mailbox* \- mailbox name

  - <a name='16'></a>__::imap4::rename__ *chan* *oldname* *newname*

    Rename a new mailbox\.

    *chan* \- imap channel

    *mailbox* \- old mailbox name

    *mailbox* \- new mailbox name

  - <a name='17'></a>__::imap4::subscribe__ *chan* *mailbox*

    Subscribe a new mailbox\.

    *chan* \- imap channel

    *mailbox* \- mailbox name

  - <a name='18'></a>__::imap4::unsubscribe__ *chan* *mailbox*

    Unsubscribe a new mailbox\.

    *chan* \- imap channel

    *mailbox* \- mailbox name

  - <a name='19'></a>__::imap4::search__ *chan* *expr* ?*\.\.\.*?

    Search for mails matching search criterions, 0 is returned on success\.

    *chan* \- imap channel

    *expr* \- imap search expression

    *Notes:* Currently the following search expressions are handled:

    *Mail header flags:* all mail header entries \(ending with a colon ":"\),
    like "From:", "Bcc:", \.\.\.

    *Imap message search flags:* ANSWERED, DELETED, DRAFT, FLAGGED, RECENT,
    SEEN, NEW, OLD, UNANSWERED, UNDELETED, UNDRAFT, UNFLAGGED, UNSEEN, ALL

    *Imap header search flags:* BODY, CC, FROM, SUBJECT, TEXT, KEYWORD, BCC

    *Imap conditional search flags:* SMALLER, LARGER, ON, SENTBEFORE, SENTON,
    SENTSINCE, SINCE, BEFORE \(not implemented\), UID \(not implemented\)

    *Logical search conditions:* OR, NOT

        ::imap4::search $chan larger 4000 seen
        puts "Found messages: [::imap4::mboxinfo $chan found]"
        Found messages: 1 3 6 7 8 9 13 14 15 19 20

  - <a name='20'></a>__::imap4::close__ *chan*

    Close the mailbox\. Permanently removes \\Deleted messages and return to the
    AUTH state\.

    *chan* \- imap channel

  - <a name='21'></a>__::imap4::cleanup__ *chan*

    Destroy an IMAP connection and free the used space\. Close the mailbox\.
    Permanently removes \\Deleted messages and return to the AUTH state\.

    *chan* \- imap channel

  - <a name='22'></a>__::imap4::debugmode__ *chan* ?*errormsg*?

    Switch client into command line debug mode\.

    This is a developers mode only that pass the control to the programmer\.
    Every line entered is sent verbatim to the server \(after the addition of the
    request identifier\)\. The ::imap4::debug variable is automatically set to '1'
    on enter\.

    It's possible to execute Tcl commands starting the line with a slash\.

    *chan* \- imap channel

    *errormsg* \- optional error message to display

  - <a name='23'></a>__::imap4::store__ *chan* *range* *data* *flaglist*

    Alters data associated with a message in the selected mailbox\.

    *chan* \- imap channel

    *range* \- message index in format *FROM*:*TO*

    *flaglist* \- Flags the *data* operates on\.

    *data* \- The currently defined *data* items that can be stored are shown
    below\. *Note* that all of these data types may also be suffixed with
    "\.SILENT" to suppress the untagged FETCH response\.

      * FLAGS

        Replace the flags for the message \(other than \\Recent\) with the
        *flaglist*\.

      * \+FLAGS

        Add the flags in *flaglist* to the existing flags for the message\.

      * \-FLAGS

        Remove the flags in *flaglist* to the existing flags for the message\.

    For example:

        ::imap4::store $chan $start_msgid:$end_msgid +FLAGS "Deleted"

  - <a name='24'></a>__::imap4::expunge__ *chan*

    Permanently removes all messages that have the \\Deleted flag set from the
    currently selected mailbox, without the need to close the connection\.

    *chan* \- imap channel

  - <a name='25'></a>__::imap4::copy__ *chan* *msgid* *mailbox*

    Copies the specified message \(identified by its message number\) to the named
    mailbox, i\.e\. imap folder\.

    *chan* \- imap channel

    *msgid* \- message number

    *mailbox* \- mailbox name

  - <a name='26'></a>__::imap4::logout__ *chan*

    Informs the server that the client is done with the connection and closes
    the network connection\. Permanently removes \\Deleted messages\.

    A new connection will need to be established to login once more\.

    *chan* \- imap channel

# <a name='section3'></a>EXAMPLES

    set user myusername
    set pass xtremescrt
    set server imap.test.tld
    set FOLDER INBOX
    # Connect to server
    set imap [::imap4::open $server]
    ::imap4::login $imap $user $pass
    ::imap4::select $imap $FOLDER
    # Output all the information about that mailbox
    foreach info [::imap4::mboxinfo $imap] {
        puts "$info -> [::imap4::mboxinfo $imap $info]"
    }
    # fetch 3 records inline
    set fields {from: to: subject: size}
    foreach rec [::imap4::fetch $imap :3 -inline {*}$fields] {
        puts -nonewline "#[incr idx])"
        for {set j 0} {$j<[llength $fields]} {incr j} {
            puts "\t[lindex $fields $j] [lindex $rec $j]"
        }
    }

    # Show all the information available about the message ID 1
    puts "Available info about message 1: [::imap4::msginfo $imap 1]"

    # Use the capability stuff
    puts "Capabilities: [::imap4::isableto $imap]"
    puts "Is able to imap4rev1? [::imap4::isableto $imap imap4rev1]"

    # Cleanup
    ::imap4::cleanup $imap

# <a name='section4'></a>TLS Security Considerations

This package uses the __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ package to
handle the security for __https__ urls and other socket connections\.

Policy decisions like the set of protocols to support and what ciphers to use
are not the responsibility of __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__, nor
of this package itself however\. Such decisions are the responsibility of
whichever application is using the package, and are likely influenced by the set
of servers the application will talk to as well\.

For example, in light of the recent [POODLE
attack](http://googleonlinesecurity\.blogspot\.co\.uk/2014/10/this\-poodle\-bites\-exploiting\-ssl\-30\.html)
discovered by Google many servers will disable support for the SSLv3 protocol\.
To handle this change the applications using
__[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ must be patched, and not this
package, nor __[TLS](\.\./\.\./\.\./\.\./index\.md\#tls)__ itself\. Such a patch
may be as simple as generally activating __tls1__ support, as shown in the
example below\.

    package require tls
    tls::init -tls1 1 ;# forcibly activate support for the TLS1 protocol

    ... your own application code ...

# <a name='section5'></a>REFERENCES

Mark R\. Crispin, "INTERNET MESSAGE ACCESS PROTOCOL \- VERSION 4rev1", RFC 3501,
March 2003,
[http://www\.rfc\-editor\.org/rfc/rfc3501\.txt](http://www\.rfc\-editor\.org/rfc/rfc3501\.txt)

OpenSSL, [http://www\.openssl\.org/](http://www\.openssl\.org/)

# <a name='section6'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *imap4* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\. Only a small part of rfc3501 implemented\.

# <a name='seealso'></a>SEE ALSO

[ftp](\.\./ftp/ftp\.md), [http](\.\./\.\./\.\./\.\./index\.md\#http),
[imap](\.\./\.\./\.\./\.\./index\.md\#imap), [mime](\.\./mime/mime\.md),
[pop3](\.\./pop3/pop3\.md), [tls](\.\./\.\./\.\./\.\./index\.md\#tls)

# <a name='keywords'></a>KEYWORDS

[email](\.\./\.\./\.\./\.\./index\.md\#email), [imap](\.\./\.\./\.\./\.\./index\.md\#imap),
[internet](\.\./\.\./\.\./\.\./index\.md\#internet),
[mail](\.\./\.\./\.\./\.\./index\.md\#mail), [net](\.\./\.\./\.\./\.\./index\.md\#net),
[rfc3501](\.\./\.\./\.\./\.\./index\.md\#rfc3501),
[ssl](\.\./\.\./\.\./\.\./index\.md\#ssl), [tls](\.\./\.\./\.\./\.\./index\.md\#tls)

# <a name='category'></a>CATEGORY

Networking
