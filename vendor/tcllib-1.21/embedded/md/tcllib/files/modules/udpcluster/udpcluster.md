
[//000000001]: # (udpcluster \- Lightweight UDP based tool for cluster node discovery)
[//000000002]: # (Generated from file 'udpcluster\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2016\-2018 Sean Woods <yoda@etoyoc\.com>)
[//000000004]: # (udpcluster\(n\) 0\.3\.3 tcllib "Lightweight UDP based tool for cluster node discovery")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

udpcluster \- UDP Peer\-to\-Peer cluster

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Bugs, Ideas, Feedback](#section2)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require udpcluster ?0\.3\.3?  
package require ip  
package require nettool  
package require comm  
package require interp  
package require dicttool  
package require cron  

# <a name='description'></a>DESCRIPTION

This package is a lightweight alternative to Zeroconf\. It utilizes UDP packets
to populate a table of services provided by each node on a local network\. Each
participant broadcasts a key/value list in plain UTF\-8 which lists what ports
are open, and what protocols are expected on those ports\. Developers are free to
add any additional key/value pairs beyond those\.

Using udpcluster\.

For every service you wish to publish invoke:

    cluster::publish echo@[cluster::macid] {port 10000 protocol echo}

To query what services are available on the local network:

    set results [cluster::search PATTERN]
    # And inside that result...
    echo@LOCALMACID {
       port 10000
       protocol echo
    }

To unpublish a service:

    cluster::unpublish echo@[cluster::macid]

Results will Historical Notes:

This tool was originally known as nns::cluster, but as development progressed,
it was clear that it wasn't interacting with any of the other facilities in NNS\.

# <a name='section2'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *nameserv* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[name service](\.\./\.\./\.\./\.\./index\.md\#name\_service),
[server](\.\./\.\./\.\./\.\./index\.md\#server)

# <a name='category'></a>CATEGORY

Networking

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2016\-2018 Sean Woods <yoda@etoyoc\.com>
