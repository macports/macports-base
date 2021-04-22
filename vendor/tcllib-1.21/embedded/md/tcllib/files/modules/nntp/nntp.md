
[//000000001]: # (nntp \- Tcl NNTP Client Library)
[//000000002]: # (Generated from file 'nntp\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (nntp\(n\) 1\.5\.1 tcllib "Tcl NNTP Client Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nntp \- Tcl client for the NNTP protocol

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [EXAMPLE](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.2  
package require nntp ?0\.2\.1?  

[__::nntp::nntp__ ?*host*? ?*port*? ?*nntpName*?](#1)  
[*nntpName* __method__ ?*arg arg \.\.\.*?](#2)  
[*nntpName* __article__ ?*msgid*?](#3)  
[*nntpName* __authinfo__ ?*user*? ?*pass*?](#4)  
[*nntpName* __body__ ?*msgid*?](#5)  
[*nntpName* __configure__](#6)  
[*nntpName* __configure__ *option*](#7)  
[*nntpName* __configure__ *option* *value* \.\.\.](#8)  
[*nntpName* __cget__ *option*](#9)  
[*nntpName* __date__](#10)  
[*nntpName* __group__ ?*group*?](#11)  
[*nntpName* __head__ ?*msgid*?](#12)  
[*nntpName* __help__](#13)  
[*nntpName* __last__](#14)  
[*nntpName* __list__](#15)  
[*nntpName* __listgroup__ ?*group*?](#16)  
[*nntpName* __mode\_reader__](#17)  
[*nntpName* __newgroups__ *since*](#18)  
[*nntpName* __newnews__](#19)  
[*nntpName* __newnews__ *since*](#20)  
[*nntpName* __newnews__ *group* ?*since*?](#21)  
[*nntpName* __next__](#22)  
[*nntpName* __post__ *article*](#23)  
[*nntpName* __slave__](#24)  
[*nntpName* __stat__ ?*msgid*?](#25)  
[*nntpName* __quit__](#26)  
[*nntpName* __xgtitle__ ?*group\_pattern*?](#27)  
[*nntpName* __xhdr__ *field* ?*range*?](#28)  
[*nntpName* __xover__ ?*range*?](#29)  
[*nntpName* __xpat__ *field* *range* ?*pattern\_list*?](#30)  

# <a name='description'></a>DESCRIPTION

The package __nntp__ provides a simple Tcl\-only client library for the NNTP
protocol\. It works by opening the standard NNTP socket on the server, and then
providing a Tcl API to access the NNTP protocol commands\. All server errors are
returned as Tcl errors \(thrown\) which must be caught with the Tcl __catch__
command\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::nntp::nntp__ ?*host*? ?*port*? ?*nntpName*?

    The command opens a socket connection to the specified NNTP server and
    creates a new nntp object with an associated global Tcl command whose name
    is *nntpName*\. This command may be used to access the various NNTP
    protocol commands for the new connection\. The default *port* number is
    "119" and the default *host* is "news"\. These defaults can be overridden
    with the environment variables __NNTPPORT__ and __NNTPHOST__
    respectively\.

    Some of the commands supported by this package are not part of the nntp rfc
    977
    \([http://www\.rfc\-editor\.org/rfc/rfc977\.txt](http://www\.rfc\-editor\.org/rfc/rfc977\.txt)\)
    and will not be available \(or implemented\) on all nntp servers\.

    The access command *nntpName* has the following general form:

      * <a name='2'></a>*nntpName* __method__ ?*arg arg \.\.\.*?

        *Option* and the *arg*s determine the exact behavior of the command\.

  - <a name='3'></a>*nntpName* __article__ ?*msgid*?

    Query the server for article *msgid* from the current group\. The article
    is returned as a valid tcl list which contains the headers, followed by a
    blank line, and then followed by the body of the article\. Each element in
    the list is one line of the article\.

  - <a name='4'></a>*nntpName* __authinfo__ ?*user*? ?*pass*?

    Send authentication information \(username and password\) to the server\.

  - <a name='5'></a>*nntpName* __body__ ?*msgid*?

    Query the server for the body of the article *msgid* from the current
    group\. The body of the article is returned as a valid tcl list\. Each element
    in the list is one line of the body of the article\.

  - <a name='6'></a>*nntpName* __configure__

  - <a name='7'></a>*nntpName* __configure__ *option*

  - <a name='8'></a>*nntpName* __configure__ *option* *value* \.\.\.

  - <a name='9'></a>*nntpName* __cget__ *option*

    Query and configure options of the nntp connection object\. Currently only
    one option is supported, __\-binary__\. When set articles are retrieved as
    binary data instead of text\. The only methods affected by this are
    __article__ and __body__\.

    One application of this option would be the download of articles containing
    yEnc encoded images\. Although encoded the data is still mostly binary and
    retrieving it as text will corrupt the information\.

    See package __[yencode](\.\./base64/yencode\.md)__ for both encoder and
    decoder of such data\.

  - <a name='10'></a>*nntpName* __date__

    Query the server for the servers current date\. The date is returned in the
    format *YYYYMMDDHHMMSS*\.

  - <a name='11'></a>*nntpName* __group__ ?*group*?

    Optionally set the current group, and retrieve information about the
    currently selected group\. Returns the estimated number of articles in the
    group followed by the number of the first article in the group, followed by
    the last article in the group, followed by the name of the group\.

  - <a name='12'></a>*nntpName* __head__ ?*msgid*?

    Query the server for the headers of the article *msgid* from the current
    group\. The headers of the article are returned as a valid tcl list\. Each
    element in the list is one line of the headers of the article\.

  - <a name='13'></a>*nntpName* __help__

    Retrieves a list of the commands that are supported by the news server that
    is currently attached to\.

  - <a name='14'></a>*nntpName* __last__

    Sets the current article pointer to point to the previous message \(if there
    is one\) and returns the msgid of that message\.

  - <a name='15'></a>*nntpName* __list__

    Returns a tcl list of valid newsgroups and associated information\. Each
    newsgroup is returned as an element in the tcl list with the following
    format:

        group last first p

    where <group> is the name of the newsgroup, <last> is the number of the last
    known article currently in that newsgroup, <first> is the number of the
    first article currently in the newsgroup, and <p> is either 'y' or 'n'
    indicating whether posting to this newsgroup is allowed \('y'\) or prohibited
    \('n'\)\.

    The <first> and <last> fields will always be numeric\. They may have leading
    zeros\. If the <last> field evaluates to less than the <first> field, there
    are no articles currently on file in the newsgroup\.

  - <a name='16'></a>*nntpName* __listgroup__ ?*group*?

    Query the server for a list of all the messages \(message numbers\) in the
    group specified by the argument *group* or by the current group if the
    *group* argument was not passed\.

  - <a name='17'></a>*nntpName* __mode\_reader__

    Query the server for its nntp 'MODE READER' response string\.

  - <a name='18'></a>*nntpName* __newgroups__ *since*

    Query the server for a list of all the new newsgroups created since the time
    specified by the argument *since*\. The argument *since* can be any time
    string that is understood by __clock scan__\. The tcl list of newsgroups
    is returned in a similar form to the list of groups returned by the
    __nntpName list__ command\. Each element of the list has the form:

        group last first p

    where <group> is the name of the newsgroup, <last> is the number of the last
    known article currently in that newsgroup, <first> is the number of the
    first article currently in the newsgroup, and <p> is either 'y' or 'n'
    indicating whether posting to this newsgroup is allowed \('y'\) or prohibited
    \('n'\)\.

  - <a name='19'></a>*nntpName* __newnews__

    Query the server for a list of new articles posted to the current group in
    the last day\.

  - <a name='20'></a>*nntpName* __newnews__ *since*

    Query the server for a list of new articles posted to the current group
    since the time specified by the argument *since*\. The argument *since*
    can be any time string that is understood by __clock scan__\.

  - <a name='21'></a>*nntpName* __newnews__ *group* ?*since*?

    Query the server for a list of new articles posted to the group specified by
    the argument *group* since the time specified by the argument *since*
    \(or in the past day if no *since* argument is passed\. The argument
    *since* can be any time string that is understood by __clock scan__\.

  - <a name='22'></a>*nntpName* __next__

    Sets the current article pointer to point to the next message \(if there is
    one\) and returns the msgid of that message\.

  - <a name='23'></a>*nntpName* __post__ *article*

    Posts an article of the form specified in RFC 1036
    \([http://www\.rfc\-editor\.org/rfc/rfc1036\.txt](http://www\.rfc\-editor\.org/rfc/rfc1036\.txt),
    successor to RFC 850\) to the current news group\.

  - <a name='24'></a>*nntpName* __slave__

    Identifies a connection as being made from a slave nntp server\. This might
    be used to indicate that the connection is serving multiple people and
    should be given priority\. Actual use is entirely implementation dependent
    and may vary from server to server\.

  - <a name='25'></a>*nntpName* __stat__ ?*msgid*?

    The stat command is similar to the article command except that no text is
    returned\. When selecting by message number within a group, the stat command
    serves to set the current article pointer without sending text\. The returned
    acknowledgment response will contain the message\-id, which may be of some
    value\. Using the stat command to select by message\-id is valid but of
    questionable value, since a selection by message\-id does NOT alter the
    "current article pointer"

  - <a name='26'></a>*nntpName* __quit__

    Gracefully close the connection after sending a NNTP QUIT command down the
    socket\.

  - <a name='27'></a>*nntpName* __xgtitle__ ?*group\_pattern*?

    Returns a tcl list where each element is of the form:

        newsgroup description

    If a *group\_pattern* is specified then only newsgroups that match the
    pattern will have their name and description returned\.

  - <a name='28'></a>*nntpName* __xhdr__ *field* ?*range*?

    Returns the specified header field value for the current message or for a
    list of messages from the current group\. *field* is the title of a field
    in the header such as from, subject, date, etc\. If *range* is not
    specified or is "" then the current message is queried\. The command returns
    a list of elements where each element has the form of:

        msgid value

    Where msgid is the number of the message and value is the value set for the
    queried field\. The *range* argument can be in any of the following forms:

      * __""__

        The current message is queried\.

      * *msgid1*\-*msgid2*

        All messages between *msgid1* and *msgid2* \(including *msgid1* and
        *msgid2*\) are queried\.

      * *msgid1* *msgid2*

        All messages between *msgid1* and *msgid2* \(including *msgid1* and
        *msgid2*\) are queried\.

  - <a name='29'></a>*nntpName* __xover__ ?*range*?

    Returns header information for the current message or for a range of
    messages from the current group\. The information is returned in a tcl list
    where each element is of the form:

        msgid subject from date idstring bodysize headersize xref

    If *range* is not specified or is "" then the current message is queried\.
    The *range* argument can be in any of the following forms:

      * __""__

        The current message is queried\.

      * *msgid1*\-*msgid2*

        All messages between *msgid1* and *msgid2* \(including *msgid1* and
        *msgid2*\) are queried\.

      * *msgid1* *msgid2*

        All messages between *msgid1* and *msgid2* \(including *msgid1* and
        *msgid2*\) are queried\.

  - <a name='30'></a>*nntpName* __xpat__ *field* *range* ?*pattern\_list*?

    Returns the specified header field value for a specified message or for a
    list of messages from the current group where the messages match the
    pattern\(s\) given in the pattern\_list\. *field* is the title of a field in
    the header such as from, subject, date, etc\. The information is returned in
    a tcl list where each element is of the form:

        msgid value

    Where msgid is the number of the message and value is the value set for the
    queried field\. The *range* argument can be in any of the following forms:

      * *msgid*

        The message specified by *msgid* is queried\.

      * *msgid1*\-*msgid2*

        All messages between *msgid1* and *msgid2* \(including *msgid1* and
        *msgid2*\) are queried\.

      * *msgid1* *msgid2*

        All messages between *msgid1* and *msgid2* \(including *msgid1* and
        *msgid2*\) are queried\.

# <a name='section3'></a>EXAMPLE

A bigger example for posting a single article\.

    package require nntp
    set n [nntp::nntp NNTP_SERVER]
    $n post "From: USER@DOMAIN.EXT (USER_FULL)
    Path: COMPUTERNAME!USERNAME
    Newsgroups: alt.test
    Subject: Tcl test post -ignore
    Message-ID: <[pid][clock seconds]
    @COMPUTERNAME>
    Date: [clock format [clock seconds] -format "%a, %d %
    b %y %H:%M:%S GMT" -gmt true]

    Test message body"

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *nntp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[news](\.\./\.\./\.\./\.\./index\.md\#news), [nntp](\.\./\.\./\.\./\.\./index\.md\#nntp),
[nntpclient](\.\./\.\./\.\./\.\./index\.md\#nntpclient), [rfc
1036](\.\./\.\./\.\./\.\./index\.md\#rfc\_1036), [rfc
977](\.\./\.\./\.\./\.\./index\.md\#rfc\_977)

# <a name='category'></a>CATEGORY

Networking
