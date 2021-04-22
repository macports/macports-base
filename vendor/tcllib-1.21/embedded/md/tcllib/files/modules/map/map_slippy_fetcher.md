
[//000000001]: # (map::slippy::fetcher \- Mapping utilities)
[//000000002]: # (Generated from file 'map\_slippy\_fetcher\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (map::slippy::fetcher\(n\) 0\.4 tcllib "Mapping utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

map::slippy::fetcher \- Accessing a server providing tiles for slippy\-based maps

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Methods](#subsection1)

  - [References](#section3)

  - [Keywords](#keywords)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require Tk 8\.4  
package require img::png  
package require map::slippy  
package require map::slippy::fetcher ?0\.4?  

[__::map::slippy::fetcher__ *fetcherName* *levels* *url*](#1)  
[*fetcherName* __levels__](#2)  
[*fetcherName* __tileheight__](#3)  
[*fetcherName* __tilewidth__](#4)  
[*fetcherName* __get__ *tile* *donecmd*](#5)  

# <a name='description'></a>DESCRIPTION

This package provides a class for accessing http servers providing tiles for
slippy\-based maps\.

# <a name='section2'></a>API

  - <a name='1'></a>__::map::slippy::fetcher__ *fetcherName* *levels* *url*

    Creates the fetcher *fetcherName* and configures it with the number of
    zoom *levels* supported by the tile server, and the *url* it is
    listening on for tile requests\.

    The result of the command is *fetcherName*\.

## <a name='subsection1'></a>Methods

  - <a name='2'></a>*fetcherName* __levels__

    This method returns the number of zoom levels supported by the fetcher
    object, and the tile server it is accessing\.

  - <a name='3'></a>*fetcherName* __tileheight__

    This method returns the height of tiles served, in pixels\.

  - <a name='4'></a>*fetcherName* __tilewidth__

    This method returns the width of tiles served, in pixels\.

  - <a name='5'></a>*fetcherName* __get__ *tile* *donecmd*

    This is the main method of the fetcher, retrieving the image for the
    specified *tile*\. The tile identifier is a list containing three elements,
    the zoom level, row, and column number of the tile, in this order\.

    The command refix *donecmd* will be invoked when the fetcher either knows
    the image for the tile or that no image will forthcoming\. It will be invoked
    with either 2 or 3 arguments, i\.e\.

      1. The string __set__, the *tile*, and the image\.

      1. The string __unset__, and the *tile*\.

    These two possibilities are used to either signal the image for the
    *tile*, or that the *tile* has no image defined for it\.

# <a name='section3'></a>References

  1. [http://wiki\.openstreetmap\.org/wiki/Main\_Page](http://wiki\.openstreetmap\.org/wiki/Main\_Page)

# <a name='keywords'></a>KEYWORDS

[http](\.\./\.\./\.\./\.\./index\.md\#http),
[location](\.\./\.\./\.\./\.\./index\.md\#location),
[map](\.\./\.\./\.\./\.\./index\.md\#map), [server](\.\./\.\./\.\./\.\./index\.md\#server),
[slippy](\.\./\.\./\.\./\.\./index\.md\#slippy),
[tile](\.\./\.\./\.\./\.\./index\.md\#tile), [url](\.\./\.\./\.\./\.\./index\.md\#url),
[zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)
