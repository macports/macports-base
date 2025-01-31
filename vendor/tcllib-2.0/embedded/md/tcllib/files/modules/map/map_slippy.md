
[//000000001]: # (map::slippy \- Mapping utilities)
[//000000002]: # (Generated from file 'map\_slippy\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (map::slippy\(n\) 0\.10 tcllib "Mapping utilities")

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

  - [Coordinate systems](#section2)

      - [Geographic](#subsection1)

      - [Points](#subsection2)

  - [API](#section3)

  - [References](#section4)

  - [Keywords](#keywords)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.6 9  
package require map::slippy ?0\.10?  

[__::map__ __slippy geo box 2point__ *zoom* *geobox*](#1)  
[__::map__ __slippy geo box center__ *geobox*](#2)  
[__::map__ __slippy geo box corners__ *geobox*](#3)  
[__::map__ __slippy geo box diameter__ *geobox*](#4)  
[__::map__ __slippy geo box dimensions__ *geobox*](#5)  
[__::map__ __slippy geo box fit__ *geobox* *canvdim* *zmax* ?*zmin*?](#6)  
[__::map__ __slippy geo box inside__ *geobox* *geo*](#7)  
[__::map__ __slippy geo box limit__ *geobox*](#8)  
[__::map__ __slippy geo box opposites__ *geobox*](#9)  
[__::map__ __slippy geo box perimeter__ *geobox*](#10)  
[__::map__ __slippy geo box valid__ *geobox*](#11)  
[__::map__ __slippy geo box valid\-list__ *geoboxes*](#12)  
[__::map__ __slippy geo distance__ *geo1* *geo2*](#13)  
[__::map__ __slippy geo distance\*__ *closed* *geo*\.\.\.](#14)  
[__::map__ __slippy geo distance\-list__ *closed* *geo\-list*](#15)  
[__::map__ __slippy geo limit__ *geo*](#16)  
[__::map__ __slippy geo bbox__ *geo*\.\.\.](#17)  
[__::map__ __slippy geo bbox\-list__ *geo\-list*](#18)  
[__::map__ __slippy geo center__ *geo*\.\.\.](#19)  
[__::map__ __slippy geo center\-list__ *geo\-list*](#20)  
[__::map__ __slippy geo diameter__ *geo*\.\.\.](#21)  
[__::map__ __slippy geo diameter\-list__ *geo\-list*](#22)  
[__::map__ __slippy geo 2point__ *zoom* *geo*](#23)  
[__::map__ __slippy geo 2point\*__ *zoom* *geo*\.\.\.](#24)  
[__::map__ __slippy geo 2point\-list__ *zoom* *geo\-list*](#25)  
[__::map__ __slippy geo valid__ *geo*](#26)  
[__::map__ __slippy geo valid\-list__ *geos*](#27)  
[__::map__ __slippy length__ *level*](#28)  
[__::map__ __slippy limit2__ *x*](#29)  
[__::map__ __slippy limit3__ *x*](#30)  
[__::map__ __slippy limit6__ *x*](#31)  
[__::map__ __slippy point box 2geo__ *zoom* *pointbox*](#32)  
[__::map__ __slippy point box center__ *pointbox*](#33)  
[__::map__ __slippy point box corners__ *pointbox*](#34)  
[__::map__ __slippy point box diameter__ *pointbox*](#35)  
[__::map__ __slippy point box dimensions__ *pointbox*](#36)  
[__::map__ __slippy point box inside__ *pointbox* *point*](#37)  
[__::map__ __slippy point box opposites__ *pointbox*](#38)  
[__::map__ __slippy point box perimeter__ *pointbox*](#39)  
[__::map__ __slippy point distance__ *point1* *point2*](#40)  
[__::map__ __slippy point distance\*__ *closed* *point*\.\.\.](#41)  
[__::map__ __slippy point distance\-list__ *closed* *point\-list*](#42)  
[__::map__ __slippy point bbox__ *point*\.\.\.](#43)  
[__::map__ __slippy point bbox\-list__ *point\-list*](#44)  
[__::map__ __slippy point center__ *point*\.\.\.](#45)  
[__::map__ __slippy point center\-list__ *point\-list*](#46)  
[__::map__ __slippy point diameter__ *point*\.\.\.](#47)  
[__::map__ __slippy point diameter\-list__ *point\-list*](#48)  
[__::map__ __slippy point 2geo__ *zoom* *point*](#49)  
[__::map__ __slippy point 2geo\*__ *zoom* *point*\.\.\.](#50)  
[__::map__ __slippy point 2geo\-list__ *zoom* *point\-list*](#51)  
[__::map__ __slippy point simplify radial__ *threshold* *point\-list*](#52)  
[__::map__ __slippy point simplify rdp__ *point\-list*](#53)  
[__::map__ __slippy pretty\-distance__ *x*](#54)  
[__::map__ __slippy tiles__ *level*](#55)  
[__::map__ __slippy tile size__](#56)  
[__::map__ __slippy tile valid__ *zoom* *row* *column* *levels* ?*msgvar*?](#57)  
[__::map__ __slippy valid latitude__ *x*](#58)  
[__::map__ __slippy valid longitude__ *x*](#59)  

# <a name='description'></a>DESCRIPTION

This package provides a number of methods doing things needed by all types of
slippy\-based map packages\.

*BEWARE*, *Attention* Version *0\.9* is *NOT backward compatible* with
version 0\.7 and earlier\. The entire API was *heavily revised and changed*\.

*Note:* For the representation of locations in the various coordinate systems
used by the commands of this package please read section [Coordinate
systems](#section2)\. The command descriptions will not repeat them, and
assume that they are understood already\.

# <a name='section2'></a>Coordinate systems

The commands of this package operate in two distinct coordinate systems,
geographical locations, and points\. The former represents coordinates for
locations on Earth, while the latter is for use on Tk *canvas* widgets\.

## <a name='subsection1'></a>Geographic

Geographical locations \(short: *geo*\) are represented by a pair of
*Latitude* and *[Longitude](\.\./\.\./\.\./\.\./index\.md\#longitude)* values,
each of which is measured in degrees, as they are essentially angles\.

The __Zero__ longitude is the *Greenwich meridian*, with positive values
going *east*, and negative values going *west*, for a total range of \+/\- 180
degrees\. Note that \+180 and \-180 longitude are the same *meridian*, opposite
to Greenwich\.

The __zero__ latitude is the *Equator*, with positive values going
*north* and negative values going *south*\. While the true range is \+/\- 90
degrees the projection used by the package requires us to cap the range at
roughly \+/\- __85\.05112877983284__ degrees\. This means that the North and
South poles are not representable and not part of any map\.

A geographical location is represented by a list containing two values, the
latitude, and longitude of the location, in this order\.

A geographical bounding box is represented by a list containing four values, the
minimal latitude and longitude of the box, and the maximal latitude and
longitude of the box, in this order\.

Geographical locations and boxes can be converted to points and their boxes by
means of an additional parameter, the *[zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)*
level\. This parameter indicates the size of the map in the canvas the
coordinates are to be projected into\.

## <a name='subsection2'></a>Points

Points \(short: *[point](\.\./\.\./\.\./\.\./index\.md\#point)*\) are represented by a
pair of *x* and *y* values, each of which is measured in pixels\. They
reference a location in a Tk *canvas* widget\. As a map can be shown at
different degrees of magnification, the exact pixel coordinates for a
geographical location depend on this *[zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)*
level\.

For the following explanation to make sense it should be noted that a map shown
in a Tk *canvas* widget is split into equal\-sized quadratic *tiles*\.

Point coordinates are tile coordinates scaled by the size of these tiles\. This
package uses tiles of size __256__, which is the standard size used by many
online servers providing map tiles of some kind or other\.

A point is represented by a list containing the x\- and y\-coordinates of the
lcoation, in this in this order\.

A point bounding box is represented by a list containing four values, the
minimal x and y of the box, and the maximal x and y of the box, in this order\.

Point locations and boxes can be converted to geographical locations and their
boxes by means of an additional parameter, the
*[zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)* level\. This parameter indicates the
size of the map in the canvas the coordinates are projected from\.

Tile coordinates appear only in one place of the API, in the signature of
command __map slippy tile valid__\. Everything else uses Point coordinates\.

Using tile coordinates in the following however makes the structure of the map
at the various *[zoom](\.\./\.\./\.\./\.\./index\.md\#zoom)* levels \(maginification
factors\) easier to explain\.

Generally the integer part of the tile coordinates represent the row and column
number of a tile of the map, wheras the fractional parts signal how far inside
that tile the location in question is, with pure integer coordinates \(no
fractional part\) representing the upper left corner of a tile\.

The zero point of the map is at the upper left corner, regardless of zoom level,
with larger coordinates going right \(east\) and down \(south\), and smaller
coordinates going left \(west\) and up \(north\)\. Again regardless of zoom level\.

Negative coordinates are not allowed\.

At zoom level __0__ the entire map is represented by a single tile, putting
the geographic zero at 1/2, 1/2 in terms of tile coordinates, and the range of
tile coordinates as \[0\.\.\.1\]\.

When going from zoom level __N__ to the next deeper \(magnified\) level
\(__N__\+1\) each tile of level __N__ is split into its four quadrants,
which then are the tiles of level __N__\+1\.

This means that at zoom level __N__ the map is sliced \(horizontally and
vertically\) into __2^N__ rows and columns, for a total of __4^N__ tiles,
with the tile coordinates ranging from __0__ to __2^N\+1__\.

# <a name='section3'></a>API

  - <a name='1'></a>__::map__ __slippy geo box 2point__ *zoom* *geobox*

    The command converts the geographical box *geobox* to a point box in the
    canvas, for the specified *zoom* level, and returns that box\.

  - <a name='2'></a>__::map__ __slippy geo box center__ *geobox*

    The command returns the center of the geographical box *geobox*\.

  - <a name='3'></a>__::map__ __slippy geo box corners__ *geobox*

    This command returns a list containing the four corner locations implied by
    the geographical box *geobox*\. The four points are top\-left, bottom\-left,
    top\-right, and bottom\-right, in that order\.

  - <a name='4'></a>__::map__ __slippy geo box diameter__ *geobox*

    The command returns the diameter of the geographical box *geobox*, in
    meters\.

  - <a name='5'></a>__::map__ __slippy geo box dimensions__ *geobox*

    The command returns the dimensions of the geographical box *geobox*, width
    and height, in this order\.

  - <a name='6'></a>__::map__ __slippy geo box fit__ *geobox* *canvdim* *zmax* ?*zmin*?

    This command calculates the zoom level such that the *geobox* will fit
    into a viewport given by *canvdim* \(a 2\-element list containing the width
    and height of said viewport\) and returns it\.

    The zoom level will be made to fit within the range *zmin*\.\.\.*zmax*\.
    When *zmin* is not specified it will default to __0__\.

  - <a name='7'></a>__::map__ __slippy geo box inside__ *geobox* *geo*

    The command tests if the geographical location *geo* is contained in the
    geographical box *geobox* or not\. It returns __true__ if so, and
    __false__ else\.

  - <a name='8'></a>__::map__ __slippy geo box limit__ *geobox*

    This command limits the geographical box to at most 6 decimals and returns
    the result\.

    For geographical coordinates 6 decimals is roughly equivalent to a grid of
    11\.1 cm\.

  - <a name='9'></a>__::map__ __slippy geo box opposites__ *geobox*

    This command returns a list containing the two principal corner locations
    implied by the geographical box *geobox*\. The two points are top\-left, and
    bottom\-right, in that order\.

  - <a name='10'></a>__::map__ __slippy geo box perimeter__ *geobox*

    The command returns the perimeter of the geographical box *geobox*, in
    meters\.

  - <a name='11'></a>__::map__ __slippy geo box valid__ *geobox*

    This commands tests if the specified geographical box contains only valid
    latitudes and longitudes\. It returns __true__ if the box is valid, and
    __false__ else\.

  - <a name='12'></a>__::map__ __slippy geo box valid\-list__ *geoboxes*

    This commands tests if the list of geographical boxes contains only valid
    latitudes and longitudes\. It returns __true__ if all the boxes are
    valid, and __false__ else\.

  - <a name='13'></a>__::map__ __slippy geo distance__ *geo1* *geo2*

    This command computes the great\-circle distance between the two geographical
    locations in meters and returns that value\.

    The code is based on
    [https://wiki\.tcl\-lang\.org/page/geodesy](https://wiki\.tcl\-lang\.org/page/geodesy)
    take on the [haversine
    formula](https://en\.wikipedia\.org/wiki/Haversine\_formula)\.

  - <a name='14'></a>__::map__ __slippy geo distance\*__ *closed* *geo*\.\.\.

    An extension of __map slippy geo distance__ this command computes the
    cumulative distance along the path specified by the ordered set of
    geographical locations in meters, and returns it\.

    If the path is marked as *closed* \(i\.e\. a polygon/loop\) the result
    contains the distance between last and first element of the path as well,
    making the result the length of the perimeter of the area described by the
    locations\.

  - <a name='15'></a>__::map__ __slippy geo distance\-list__ *closed* *geo\-list*

    As a variant of __map slippy geo distance\*__ this command takes the path
    to compute the length of as a single list of geographical locations, instead
    of a varying number of arguments\.

  - <a name='16'></a>__::map__ __slippy geo limit__ *geo*

    This command limits the geographical location to at most 6 decimals and
    returns the result\.

    For geographical coordinates 6 decimals is roughly equivalent to a grid of
    11\.1 cm\.

  - <a name='17'></a>__::map__ __slippy geo bbox__ *geo*\.\.\.

  - <a name='18'></a>__::map__ __slippy geo bbox\-list__ *geo\-list*

    These two commands compute the bounding box for the specified set of
    geographical locations and return a geographical box\.

    When no geographical locations are specified the box is "__0 0 0 0__"\.

    The locations are specified as either a varying number of arguments, or as a
    single list\.

  - <a name='19'></a>__::map__ __slippy geo center__ *geo*\.\.\.

  - <a name='20'></a>__::map__ __slippy geo center\-list__ *geo\-list*

    These two commands compute the center of the bounding box for the specified
    set of geographical locations\.

    When no geographical locations are specified the center is "__0 0__"\.

    The locations are specified as either a varying number of arguments, or as a
    single list\.

  - <a name='21'></a>__::map__ __slippy geo diameter__ *geo*\.\.\.

  - <a name='22'></a>__::map__ __slippy geo diameter\-list__ *geo\-list*

    These two commands compute the diameter for the specified set of
    geographical locations, in meters\. The diameter is the maximum of the
    pair\-wise distances between all locations\.

    When less than two geographical locations are specified the diameter is
    "__0__"\.

    The locations are specified as either a varying number of arguments, or as a
    single list\.

  - <a name='23'></a>__::map__ __slippy geo 2point__ *zoom* *geo*

    This command converts the geographical location *geo* to a point in the
    canvas, for the specified *zoom* level, and returns that point\.

  - <a name='24'></a>__::map__ __slippy geo 2point\*__ *zoom* *geo*\.\.\.

  - <a name='25'></a>__::map__ __slippy geo 2point\-list__ *zoom* *geo\-list*

    These two commands are extensions of __map slippy geo 2point__ which
    take a series of geographical locations as either a varying number of
    arguments or a single list, convert them all to points as per the specified
    *zoom* level and return a list of the results\.

  - <a name='26'></a>__::map__ __slippy geo valid__ *geo*

    This commands tests if the specified geographical location contains only
    valid latitudes and longitudes\. It returns __true__ if the location is
    valid, and __false__ else\.

  - <a name='27'></a>__::map__ __slippy geo valid\-list__ *geos*

    This commands tests if the list of geographical locations contains only
    valid latitudes and longitudes\. It returns __true__ if all the locations
    are valid, and __false__ else\.

  - <a name='28'></a>__::map__ __slippy length__ *level*

    This command returns the width/height of a slippy\-based map at the specified
    zoom *level*, in pixels\. This is, in essence, the result of

        expr { [tiles $level] * [tile size] }

  - <a name='29'></a>__::map__ __slippy limit2__ *x*

  - <a name='30'></a>__::map__ __slippy limit3__ *x*

  - <a name='31'></a>__::map__ __slippy limit6__ *x*

    This command limits the value to at most 2, 3, or 6 decimals and returns the
    result\.

    For geographical coordinates 6 decimals is roughly equivalent to a grid of
    11\.1 cm\.

  - <a name='32'></a>__::map__ __slippy point box 2geo__ *zoom* *pointbox*

    The command converts the point box *pointbox* to a geographical box in the
    canvas, as per the specified *zoom* level, and returns that box\.

  - <a name='33'></a>__::map__ __slippy point box center__ *pointbox*

    The command returns the center of the *pointbox*\.

  - <a name='34'></a>__::map__ __slippy point box corners__ *pointbox*

    This command returns a list containing the four corner locations implied by
    the point box *pointbox*\. The four points are top\-left, bottom\-left,
    top\-right, and bottom\-right, in that order\.

  - <a name='35'></a>__::map__ __slippy point box diameter__ *pointbox*

    The command returns the diameter of the *pointbox*, in pixels\.

  - <a name='36'></a>__::map__ __slippy point box dimensions__ *pointbox*

    The command returns the dimensions of the *pointbox*, width and height, in
    this order\.

  - <a name='37'></a>__::map__ __slippy point box inside__ *pointbox* *point*

    The command tests if the *point* is contained in the *pointbox* or not\.
    It returns __true__ if so, and __false__ else\.

  - <a name='38'></a>__::map__ __slippy point box opposites__ *pointbox*

    This command returns a list containing the two principal corner locations
    implied by the point box *pointbox*\. The two points are top\-left, and
    bottom\-right, in that order\.

  - <a name='39'></a>__::map__ __slippy point box perimeter__ *pointbox*

    The command returns the perimeter of the *pointbox*, in pixels\.

  - <a name='40'></a>__::map__ __slippy point distance__ *point1* *point2*

    This command computes the euclidena distance between the two points in
    pixels and returns that value\.

  - <a name='41'></a>__::map__ __slippy point distance\*__ *closed* *point*\.\.\.

    An extension of __map slippy point distance__ this command computes the
    cumulative distance along the path specified by the ordered set of points,
    and returns it\.

    If the path is marked as *closed* \(i\.e\. a polygon/loop\) the result
    contains the distance between last and first element of the path as well,
    making the result the length of the perimeter of the area described by the
    locations\.

  - <a name='42'></a>__::map__ __slippy point distance\-list__ *closed* *point\-list*

    As a variant of __map slippy point distance\*__ this command takes the
    path to compute the length of as a single list of points, instead of a
    varying number of arguments\.

  - <a name='43'></a>__::map__ __slippy point bbox__ *point*\.\.\.

  - <a name='44'></a>__::map__ __slippy point bbox\-list__ *point\-list*

    These two commands compute the bounding box for the specified set of points
    and return a point box\.

    When no points are specified the box is "__0 0 0 0__"\.

    The locations are specified as either a varying number of arguments, or as a
    single list\.

  - <a name='45'></a>__::map__ __slippy point center__ *point*\.\.\.

  - <a name='46'></a>__::map__ __slippy point center\-list__ *point\-list*

    These two commands compute the center of the bounding box for the specified
    set of points\.

    When no points are specified the center is "__0 0__"\.

    The locations are specified as either a varying number of arguments, or as a
    single list\.

  - <a name='47'></a>__::map__ __slippy point diameter__ *point*\.\.\.

  - <a name='48'></a>__::map__ __slippy point diameter\-list__ *point\-list*

    These two commands compute the diameter for the specified set of points, in
    pixels\. The diameter is the maximum of the pair\-wise distances between all
    locations\.

    When less than two points are specified the diameter is "__0__"\.

    The locations are specified as either a varying number of arguments, or as a
    single list\.

  - <a name='49'></a>__::map__ __slippy point 2geo__ *zoom* *point*

    This command converts the *point* in the canvas, for the specified
    *zoom* level, to a geograhical location, and returns that location\.

  - <a name='50'></a>__::map__ __slippy point 2geo\*__ *zoom* *point*\.\.\.

  - <a name='51'></a>__::map__ __slippy point 2geo\-list__ *zoom* *point\-list*

    These two commands are extensions of __map slippy point 2geo__ which
    take a series of points as either a varying number of arguments or a single
    list, convert them all to geographical locations as per the specified
    *zoom* level and return a list of the results\.

  - <a name='52'></a>__::map__ __slippy point simplify radial__ *threshold* *point\-list*

    This command takes a path of points \(as a single list\), simplifies the path
    using the *Radial Distance* algorithm and returns the simplified path as
    list of points\.

    In essence the algorithm keeps only the first of adjacent points nearer to
    that first point than the threshold, and drops the others\.

  - <a name='53'></a>__::map__ __slippy point simplify rdp__ *point\-list*

    This command takes a patch of points \(as a single list\), simplifies it using
    the *non\-parametric* *Ramer\-Douglas\-Peucker* algorithm and returns the
    simplified path as list of points\.

  - <a name='54'></a>__::map__ __slippy pretty\-distance__ *x*

    This methods formats the distance *x* \(in meters\) for display and returns
    the resulting string \(including the chosen unit\)\.

    Sub\-kilometer distances are limited to 2 decimals, i\.e\. centimeters, whereas
    Kilometers are limited to 3 decimals, i\.e\. meters\.

  - <a name='55'></a>__::map__ __slippy tiles__ *level*

    This command returns the width/height of a slippy\-based map at the specified
    zoom *level*, in *tiles*\.

  - <a name='56'></a>__::map__ __slippy tile size__

    This command returns the width/height of a tile in a slippy\-based map, in
    pixels\.

  - <a name='57'></a>__::map__ __slippy tile valid__ *zoom* *row* *column* *levels* ?*msgvar*?

    This command checks if the tile described by *zoom*, *row*, and
    *column* is valid for a slippy\-based map having that many zoom *levels*,
    or not\. The result is a boolean value, __true__ if the tile is valid,
    and __false__ otherwise\. In the latter case a message is left in the
    variable named by *msgvar*, should it be specified\.

  - <a name='58'></a>__::map__ __slippy valid latitude__ *x*

    This commands tests if the argument *x* is a valid latitude value, and
    returns the boolean result of that test\. I\.e\. __true__ if the value is
    valid, and __false__ else\.

  - <a name='59'></a>__::map__ __slippy valid longitude__ *x*

    This commands tests if the argument *x* is a valid longitude value, and
    returns the boolean result of that test\. I\.e\. __true__ if the value is
    valid, and __false__ else\.

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
