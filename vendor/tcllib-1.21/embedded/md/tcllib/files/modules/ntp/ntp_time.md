
[//000000001]: # (ntp\_time \- Network Time Facilities)
[//000000002]: # (Generated from file 'ntp\_time\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2002, Pat Thoyts <patthoyts@users\.sourceforge\.net>)
[//000000004]: # (ntp\_time\(n\) 1\.2\.1 tcllib "Network Time Facilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

ntp\_time \- Tcl Time Service Client

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [AUTHORS](#section3)

  - [Bugs, Ideas, Feedback](#section4)

  - [See Also](#seealso)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.0  
package require time ?1\.2\.1?  

[__::time::gettime__ ?*options*? *timeserver* ?*port*?](#1)  
[__::time::getsntp__ ?*options*? *timeserver* ?*port*?](#2)  
[__::time::configure__ ?*options*?](#3)  
[__::time::cget__ *name*](#4)  
[__::time::unixtime__ *token*](#5)  
[__::time::status__ *token*](#6)  
[__::time::error__ *token*](#7)  
[__::time::reset__ *token* *?reason?*](#8)  
[__::time::wait__ *token*](#9)  
[__::time::cleanup__ *token*](#10)  

# <a name='description'></a>DESCRIPTION

This package implements a client for the RFC 868 TIME protocol
\([http://www\.rfc\-editor\.org/rfc/rfc868\.txt](http://www\.rfc\-editor\.org/rfc/rfc868\.txt)\)
and also a minimal client for the RFC 2030 Simple Network Time Protocol
\([http://www\.rfc\-editor\.org/rfc/rfc2030\.txt](http://www\.rfc\-editor\.org/rfc/rfc2030\.txt)\)\.
RFC 868 returns the time in seconds since 1 January 1900 to either tcp or udp
clients\. RFC 2030 also gives this time but also provides a fractional part which
is not used in this client\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::time::gettime__ ?*options*? *timeserver* ?*port*?

    Get the time from *timeserver*\. You may specify any of the options listed
    for the __configure__ command here\. This command returns a token which
    must then be used with the remaining commands in this package\. Once you have
    finished, you should use __[cleanup](\.\./\.\./\.\./\.\./index\.md\#cleanup)__
    to release all resources\. The default port is __37__\.

  - <a name='2'></a>__::time::getsntp__ ?*options*? *timeserver* ?*port*?

    Get the time from an SNTP server\. This accepts exactly the same arguments as
    __::time::gettime__ except that the default port is __123__\. The
    result is a token as per __::time::gettime__ and should be handled in
    the same way\.

    Note that it is unlikely that any SNTP server will reply using tcp so you
    will require the __tcludp__ or the __ceptcl__ package\. If a suitable
    package can be loaded then the udp protocol will be used by default\.

  - <a name='3'></a>__::time::configure__ ?*options*?

    Called with no arguments this command returns all the current configuration
    options and values\. Otherwise it should be called with pairs of option name
    and value\.

      * __\-protocol__ *number*

        Set the default network protocol\. This defaults to udp if the tcludp
        package is available\. Otherwise it will use tcp\.

      * __\-port__ *number*

        Set the default port to use\. RFC 868 uses port __37__, RFC 2030 uses
        port __123__\.

      * __\-timeout__ *number*

        Set the default timeout value in milliseconds\. The default is 10
        seconds\.

      * __\-command__ *number*

        Set a command procedure to be run when a reply is received\. The
        procedure is called with the time token appended to the argument list\.

      * __\-loglevel__ *number*

        Set the logging level\. The default is 'warning'\.

  - <a name='4'></a>__::time::cget__ *name*

    Get the current value for the named configuration option\.

  - <a name='5'></a>__::time::unixtime__ *token*

    Format the returned time for the unix epoch\. RFC 868 time defines time 0 as
    1 Jan 1900, while unix time defines time 0 as 1 Jan 1970\. This command
    converts the reply to unix time\.

  - <a name='6'></a>__::time::status__ *token*

    Returns the status flag\. For a successfully completed query this will be
    *ok*\. May be *error* or *timeout* or *eof*\. See also
    __::time::error__

  - <a name='7'></a>__::time::error__ *token*

    Returns the error message provided for requests whose status is *error*\.
    If there is no error message then an empty string is returned\.

  - <a name='8'></a>__::time::reset__ *token* *?reason?*

    Reset or cancel the query optionally specfying the reason to record for the
    __[error](\.\./\.\./\.\./\.\./index\.md\#error)__ command\.

  - <a name='9'></a>__::time::wait__ *token*

    Wait for a query to complete and return the status upon completion\.

  - <a name='10'></a>__::time::cleanup__ *token*

    Remove all state variables associated with the request\.

    % set tok [::time::gettime ntp2a.mcc.ac.uk]
    % set t [::time::unixtime $tok]
    % ::time::cleanup $tok

    % set tok [::time::getsntp pool.ntp.org]
    % set t [::time::unixtime $tok]
    % ::time::cleanup $tok

    proc on_time {token} {
       if {[time::status $token] eq "ok"} {
          puts [clock format [time::unixtime $token]]
       } else {
          puts [time::error $token]
       }
       time::cleanup $token
    }
    time::getsntp -command on_time pool.ntp.org

# <a name='section3'></a>AUTHORS

Pat Thoyts

# <a name='section4'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *ntp* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='seealso'></a>SEE ALSO

ntp

# <a name='keywords'></a>KEYWORDS

[NTP](\.\./\.\./\.\./\.\./index\.md\#ntp), [SNTP](\.\./\.\./\.\./\.\./index\.md\#sntp),
[rfc 2030](\.\./\.\./\.\./\.\./index\.md\#rfc\_2030), [rfc
868](\.\./\.\./\.\./\.\./index\.md\#rfc\_868), [time](\.\./\.\./\.\./\.\./index\.md\#time)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2002, Pat Thoyts <patthoyts@users\.sourceforge\.net>
