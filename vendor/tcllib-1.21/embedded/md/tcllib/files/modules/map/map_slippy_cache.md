
[//000000001]: # (map::slippy::cache \- Mapping utilities)
[//000000002]: # (Generated from file 'map\_slippy\_cache\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (map::slippy::cache\(n\) 0\.2 tcllib "Mapping utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

map::slippy::cache \- Management of a tile cache in the local filesystem

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
package require map::slippy::cache ?0\.2?  

[__::map::slippy::cache__ *cacheName* *cachedir* *provider*](#1)  
[*cacheName* __valid__ *tile* ?*msgvar*?](#2)  
[*cacheName* __exists__ *tile*](#3)  
[*cacheName* __get__ *tile* *donecmd*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a class for managing a cache of tiles for slippy\-based
maps in the local filesystem\.

# <a name='section2'></a>API

  - <a name='1'></a>__::map::slippy::cache__ *cacheName* *cachedir* *provider*

    Creates the cache *cacheName* and configures it with both the path to the
    directory contaiing the locally cached tiles \(*cachedir*\), and the command
    prefix from which it will pull tiles asked for and not yet known to the
    cache itself \(*provider*\)\.

    The result of the command is *cacheName*\.

## <a name='subsection1'></a>Methods

  - <a name='2'></a>*cacheName* __valid__ *tile* ?*msgvar*?

    This method checks the validity of a the given *tile* identifier\. This is
    a convenience wrapper to __::map::slippy tile valid__ and has the same
    interface\.

  - <a name='3'></a>*cacheName* __exists__ *tile*

    This methods tests whether the cache contains the specified *tile* or not\.
    The result is a boolean value, __true__ if the tile is known, and
    __false__ otherwise\. The tile is identified by a list containing three
    elements, zoom level, row, and column number, in this order\.

  - <a name='4'></a>*cacheName* __get__ *tile* *donecmd*

    This is the main method of the cache, retrieving the image for the specified
    *tile* from the cache\. The tile identifier is a list containing three
    elements, the zoom level, row, and column number of the tile, in this order\.

    The command refix *donecmd* will be invoked when the cache either knows
    the image for the tile or that no image will forthcoming\. It will be invoked
    with either 2 or 3 arguments, i\.e\.

      1. The string __set__, the *tile*, and the image\.

      1. The string __unset__, and the *tile*\.

    These two possibilities are used to either signal the image for the
    *tile*, or that the *tile* has no image defined for it\.

    When the cache has no information about the tile it will invoke the
    *provider* command prefix specified during its construction, adding three
    arguments: The string __get__, the *tile*, and a callback into the
    cache\. The latter will be invoked by the provider to either transfer the
    image to the cache, or signal that the tile has no image\.

    When multiple requests for the same tile are made only one request will be
    issued to the provider\.

# <a name='section3'></a>References

  1. [http://wiki\.openstreetmap\.org/wiki/Main\_Page](http://wiki\.openstreetmap\.org/wiki/Main\_Page)

# <a name='keywords'></a>KEYWORDS

[cache](\.\./\.\./\.\./\.\./index\.md\#cache),
[filesystem](\.\./\.\./\.\./\.\./index\.md\#filesystem),
[location](\.\./\.\./\.\./\.\./index\.md\#location),
[map](\.\./\.\./\.\./\.\./index\.md\#map), [slippy](\.\./\.\./\.\./\.\./index\.md\#slippy),
[tile](\.\./\.\./\.\./\.\./index\.md\#tile), [zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)
