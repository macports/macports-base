
[//000000001]: # (map::slippy \- Mapping utilities)
[//000000002]: # (Generated from file 'map\_slippy\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (map::slippy\(n\) 0\.5 tcllib "Mapping utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

map::slippy \- Common code for slippy based map packages

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

  - [Coordinate systems](#section3)

      - [Geographic](#subsection1)

      - [Tiles](#subsection2)

      - [Pixels/Points](#subsection3)

  - [References](#section4)

  - [Keywords](#keywords)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.4  
package require Tk 8\.4  
package require map::slippy ?0\.5?  

[__::map::slippy__ __length__ *level*](#1)  
[__::map::slippy__ __tiles__ *level*](#2)  
[__::map::slippy__ __tile size__](#3)  
[__::map::slippy__ __tile valid__ *tile* *levels* ?*msgvar*?](#4)  
[__::map::slippy__ __geo 2tile__ *geo*](#5)  
[__::map::slippy__ __geo 2tile\.float__ *geo*](#6)  
[__::map::slippy__ __geo 2point__ *geo*](#7)  
[__::map::slippy__ __tile 2geo__ *tile*](#8)  
[__::map::slippy__ __tile 2point__ *tile*](#9)  
[__::map::slippy__ __point 2geo__ *point*](#10)  
[__::map::slippy__ __point 2tile__ *point*](#11)  
[__::map::slippy__ __fit geobox__ *canvdim* *geobox* *zmin* *zmax*](#12)  

# <a name='description'></a>DESCRIPTION

This package provides a number of methods doing things needed by all types of
slippy\-based map packages\.

# <a name='section2'></a>API

  - <a name='1'></a>__::map::slippy__ __length__ *level*

    This method returns the width/height of a slippy\-based map at the specified
    zoom *level*, in pixels\. This is, in essence, the result of

        expr { [tiles $level] * [tile size] }

  - <a name='2'></a>__::map::slippy__ __tiles__ *level*

    This method returns the width/height of a slippy\-based map at the specified
    zoom *level*, in *tiles*\.

  - <a name='3'></a>__::map::slippy__ __tile size__

    This method returns the width/height of a tile in a slippy\-based map, in
    pixels\.

  - <a name='4'></a>__::map::slippy__ __tile valid__ *tile* *levels* ?*msgvar*?

    This method checks whether *tile* described a valid tile in a slippy\-based
    map containing that many zoom *levels*\. The result is a boolean value,
    __true__ if the tile is valid, and __false__ otherwise\. For the
    latter a message is left in the variable named by *msgvar*, should it be
    specified\.

    A tile identifier as stored in *tile* is a list containing zoom level,
    tile row, and tile column, in this order\. The command essentially checks
    this, i\.e\. the syntax, that the zoom level is between 0 and "*levels*\-1",
    and that the row/col information is within the boundaries for the zoom
    level, i\.e\. 0 \.\.\. "\[tiles $zoom\]\-1"\.

  - <a name='5'></a>__::map::slippy__ __geo 2tile__ *geo*

    Converts a geographical location at a zoom level \(*geo*, a list containing
    zoom level, latitude, and longitude, in this order\) to a tile identifier
    \(list containing zoom level, row, and column\) at that level\. The tile
    identifier uses pure integer numbers for the tile coordinates, for all
    geographic coordinates mapping to that tile\.

  - <a name='6'></a>__::map::slippy__ __geo 2tile\.float__ *geo*

    Converts a geographical location at a zoom level \(*geo*, a list containing
    zoom level, latitude, and longitude, in this order\) to a tile identifier
    \(list containing zoom level, row, and column\) at that level\. The tile
    identifier uses floating point numbers for the tile coordinates,
    representing not only the tile the geographic coordinates map to, but also
    the fractional location inside of that tile\.

  - <a name='7'></a>__::map::slippy__ __geo 2point__ *geo*

    Converts a geographical location at a zoom level \(*geo*, a list containing
    zoom level, latitude, and longitude, in this order\) to a pixel position
    \(list containing zoom level, y, and x\) at that level\.

  - <a name='8'></a>__::map::slippy__ __tile 2geo__ *tile*

    Converts a tile identifier at a zoom level \(*tile*, list containing zoom
    level, row, and column\) to a geographical location \(list containing zoom
    level, latitude, and longitude, in this order\) at that level\.

  - <a name='9'></a>__::map::slippy__ __tile 2point__ *tile*

    Converts a tile identifier at a zoom level \(*tile*, a list containing zoom
    level, row, and column, in this order\) to a pixel position \(list containing
    zoom level, y, and x\) at that level\.

  - <a name='10'></a>__::map::slippy__ __point 2geo__ *point*

    Converts a pixel position at a zoom level \(*point*, list containing zoom
    level, y, and x\) to a geographical location \(list containing zoom level,
    latitude, and longitude, in this order\) at that level\.

  - <a name='11'></a>__::map::slippy__ __point 2tile__ *point*

    Converts a pixel position at a zoom level \(*point*, a list containing zoom
    level, y, and x, in this order\) to a tile identifier \(list containing zoom
    level, row, and column\) at that level\.

  - <a name='12'></a>__::map::slippy__ __fit geobox__ *canvdim* *geobox* *zmin* *zmax*

    Calculates the zoom level \(whithin the bounds *zmin* and *zmax*\) such
    that *geobox* \(a 4\-element list containing the latitudes and longitudes
    lat0, lat1, lon0 and lon1 of a geo box, in this order\) fits into a viewport
    given by *canvdim*, a 2\-element list containing the width and height of
    the viewport, in this order\.

# <a name='section3'></a>Coordinate systems

The commands of this package operate on three distinct coordinate systems, which
are explained below\.

## <a name='subsection1'></a>Geographic

*Geographic*al coordinates are represented by *Latitude* and
*[Longitude](\.\./\.\./\.\./\.\./index\.md\#longitude)*, each of which is measured
in degrees, as they are essentially angles\.

__Zero__ longitude is the *Greenwich meridian*, with positive values going
*east*, and negative values going *west*, for a total range of \+/\- 180
degrees\. Note that \+180 and \-180 longitude are the same *meridian*, opposite
to greenwich\.

__zero__ latitude the *Equator*, with positive values going *north* and
negative values going *south*\. While the true range is \+/\- 90 degrees the
projection used by the package requires us to cap the range at \+/\-
85\.05112877983284 degrees\. This means that north and south pole are not
representable and not part of any map\.

## <a name='subsection2'></a>Tiles

While [Geographic](#subsection1)al coordinates of the previous section are
independent of zoom level the *tile coordinates* are not\.

Generally the integer part of tile coordinates represent the row and column
number of the tile in question, wheras the fractional parts signal how far
inside the tile the location in question is, with pure integer coordinates \(no
fractional part\) representing the upper left corner of the tile\.

The zero point of the map is at the upper left corner, regardless of zoom level,
with larger coordinates going right \(east\) and down \(south\), and smaller
coordinates going left \(west\) and up \(north\)\. Again regardless of zxoom level\.

Negative tile coordinates are not allowed\.

At zoom level 0 the whole map is represented by a single, putting the geographic
zero at 1/2, 1/2 of tile coordinates, and the range of tile coordinates as
\[0\.\.\.1\]\.

To go from a zoom level N to the next deeper level N\+1 each tile of level N is
split into its four quadrants, which then are the tiles of level N\+1\.

This means that at zoom level N the map is sliced \(horizontally and vertically\)
into 2^N stripes, for a total of 4^N tiles, with tile coordinates ranging from 0
to 2^N\+1\.

## <a name='subsection3'></a>Pixels/Points

*pixel coordinates*, also called *point coordinates* are in essence [tile
coordinates](#subsection2) scaled by the size of the image representing a
tile\. This tile size currently has a fixed value, __256__\.

# <a name='section4'></a>References

  1. [http://wiki\.openstreetmap\.org/wiki/Main\_Page](http://wiki\.openstreetmap\.org/wiki/Main\_Page)

# <a name='keywords'></a>KEYWORDS

[geodesy](\.\./\.\./\.\./\.\./index\.md\#geodesy),
[geography](\.\./\.\./\.\./\.\./index\.md\#geography),
[latitute](\.\./\.\./\.\./\.\./index\.md\#latitute),
[location](\.\./\.\./\.\./\.\./index\.md\#location),
[longitude](\.\./\.\./\.\./\.\./index\.md\#longitude),
[map](\.\./\.\./\.\./\.\./index\.md\#map), [slippy](\.\./\.\./\.\./\.\./index\.md\#slippy),
[zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)
