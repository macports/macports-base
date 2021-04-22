
[//000000001]: # (nettool \- nettool)
[//000000002]: # (Generated from file 'nettool\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2015\-2018 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (nettool\(n\) 0\.5\.2 tcllib "nettool")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

nettool \- Tools for networked applications

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Bugs, Ideas, Feedback](#section3)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require nettool ?0\.5\.2?  
package require twapi 3\.1  
package require ip 0\.1  
package require platform 0\.1  

[__::cat__ *filename*](#1)  
[__::nettool::allocate\_port__ *startingport*](#2)  
[__::nettool::arp\_table__](#3)  
[__::nettool::broadcast\_list__](#4)  
[__::nettool::claim\_port__ *port* ?*protocol*?](#5)  
[__::nettool::cpuinfo__ *args*](#6)  
[__::nettool::find\_port__ *startingport*](#7)  
[__::nettool::hwid\_list__](#8)  
[__::nettool::ip\_list__](#9)  
[__::nettool::mac\_list__](#10)  
[__::nettool::network\_list__](#11)  
[__::nettool::port\_busy__ *port*](#12)  
[__::nettool::release\_port__ *port* ?*protocol*?](#13)  
[__::nettool::status__](#14)  
[__::nettool::user\_data\_root__ *appname*](#15)  

# <a name='description'></a>DESCRIPTION

The __nettool__ package consists of a Pure\-tcl set of tools to perform
common network functions that would normally require different packages or calls
to exec, in a standard Tcl interface\. At present nettool has reference
implementations for the following operating systems: Windows, MacOSX, and Linux
\(debian\)\.

# <a name='section2'></a>Commands

  - <a name='1'></a>__::cat__ *filename*

    Dump the contents of a file as a result\.

  - <a name='2'></a>__::nettool::allocate\_port__ *startingport*

    Attempt to allocate *startingport*, or, if busy, advance the port number
    sequentially until a free port is found, and claim that port\. This command
    uses a built\-in database of known ports to avoid returning a port which is
    in common use\. \(For example: http \(80\)\)

  - <a name='3'></a>__::nettool::arp\_table__

    Dump the contents of this computer's Address Resolution Protocol \(ARP\)
    table\. The result will be a Tcl formatted list: *macid* *ipaddrlist* \.\.\.

  - <a name='4'></a>__::nettool::broadcast\_list__

    Returns a list of broadcast addresses \(suitable for UDP multicast\) that this
    computer is associated with\.

  - <a name='5'></a>__::nettool::claim\_port__ *port* ?*protocol*?

    Mark *port* as busy, optionally as either __tcp__ \(default\) or
    __udp__\.

  - <a name='6'></a>__::nettool::cpuinfo__ *args*

    If no arguments are given, return a key/value list describing the CPU of the
    present machine\. Included in the matrix is info on the number of
    cores/processors that are available for parallel tasking, installed physical
    RAM, and processor family\.

    The exact contents are platform specific\.

    For Linux, information is drawn from /proc/cpuinfo and /proc/meminfo\.

    For MacOSX, information is drawn from sysctl

    For Windows, information is draw from TWAPI\.

    If arguments are given, the result with be a key/value list limited to the
    fields requested\.

    Canonical fields for all platforms:

      * cpus

        Count of CPUs/cores/execution units

      * speed

        Clock speed of processor\(s\) in Mhz

      * memory

        Installed RAM \(in MB\)

      * vendor

        Manufacturer

  - <a name='7'></a>__::nettool::find\_port__ *startingport*

    Return *startingport* if it is available, or the next free port after
    *startingport*\. Note: Unlike __::nettool::allocate\_port__, this
    command does not claim the port\.

    This command uses a built\-in database of known ports to avoid returning a
    port which is in common use\. \(For example: http \(80\)\)

  - <a name='8'></a>__::nettool::hwid\_list__

    Return a list of hardware specific identifiers from this computer\. The
    source and content will vary by platform\.

    For MacOSX, the motherboard serial number and macids for all network devices
    is returned\.

    For Windows, the volume serial number of C and macids for all network
    devices is returned\.

    For Linux, macids for all network devices is returned\.

  - <a name='9'></a>__::nettool::ip\_list__

    Return a list of IP addresses associated with this computer\.

  - <a name='10'></a>__::nettool::mac\_list__

    Return a list of MACIDs for the network cards attached to this machine\. The
    MACID of the primary network card is returned first\.

  - <a name='11'></a>__::nettool::network\_list__

    Return a list of networks associated with this computer\. Networks are
    formated with __ip::nativeToPrefix__\.

  - <a name='12'></a>__::nettool::port\_busy__ *port*

    Return true if *port* is claimed, false otherwise\.

  - <a name='13'></a>__::nettool::release\_port__ *port* ?*protocol*?

    Mark *port* as not busy, optionally as either __tcp__ \(default\) or
    __udp__\.

  - <a name='14'></a>__::nettool::status__

    Return a key/value list describing the status of the computer\. The output is
    designed to be comparable to the output of __top__ for all platforms\.

    Common fields include:

      * load

        Processes per processing unit

      * memory\_total

        Total physical RAM \(MB\)

      * memory\_free

        Total physical RAM unused \(MB\)

  - <a name='15'></a>__::nettool::user\_data\_root__ *appname*

    Return a fully qualified path to a folder where *appname* should store
    it's data\. The path is not created, only computed, by this command\.

# <a name='section3'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *odie* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[nettool](\.\./\.\./\.\./\.\./index\.md\#nettool),
[odie](\.\./\.\./\.\./\.\./index\.md\#odie)

# <a name='category'></a>CATEGORY

System

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2015\-2018 Sean Woods <yoda@etoyoc\.com>
