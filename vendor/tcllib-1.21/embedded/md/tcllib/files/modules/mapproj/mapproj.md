
[//000000001]: # (mapproj \- Tcl Library)
[//000000002]: # (Generated from file 'mapproj\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2007 Kevin B\. Kenny <kennykb@acm\.org>)
[//000000004]: # (mapproj\(n\) 0\.1 tcllib "Tcl Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

mapproj \- Map projection routines

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [Commands](#section2)

  - [Arguments](#section3)

  - [Results](#section4)

  - [Choosing a projection](#section5)

  - [Keywords](#keywords)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl ?8\.4?  
package require math::interpolate ?1\.0?  
package require math::special ?0\.2\.1?  
package require mapproj ?1\.0?  

[__::mapproj::toPlateCarree__ *lambda\_0* *phi\_0* *lambda* *phi*](#1)  
[__::mapproj::fromPlateCarree__ *lambda\_0* *phi\_0* *x* *y*](#2)  
[__::mapproj::toCylindricalEqualArea__ *lambda\_0* *phi\_0* *lambda* *phi*](#3)  
[__::mapproj::fromCylindricalEqualArea__ *lambda\_0* *phi\_0* *x* *y*](#4)  
[__::mapproj::toMercator__ *lambda\_0* *phi\_0* *lambda* *phi*](#5)  
[__::mapproj::fromMercator__ *lambda\_0* *phi\_0* *x* *y*](#6)  
[__::mapproj::toMillerCylindrical__ *lambda\_0* *lambda* *phi*](#7)  
[__::mapproj::fromMillerCylindrical__ *lambda\_0* *x* *y*](#8)  
[__::mapproj::toSinusoidal__ *lambda\_0* *phi\_0* *lambda* *phi*](#9)  
[__::mapproj::fromSinusoidal__ *lambda\_0* *phi\_0* *x* *y*](#10)  
[__::mapproj::toMollweide__ *lambda\_0* *lambda* *phi*](#11)  
[__::mapproj::fromMollweide__ *lambda\_0* *x* *y*](#12)  
[__::mapproj::toEckertIV__ *lambda\_0* *lambda* *phi*](#13)  
[__::mapproj::fromEckertIV__ *lambda\_0* *x* *y*](#14)  
[__::mapproj::toEckertVI__ *lambda\_0* *lambda* *phi*](#15)  
[__::mapproj::fromEckertVI__ *lambda\_0* *x* *y*](#16)  
[__::mapproj::toRobinson__ *lambda\_0* *lambda* *phi*](#17)  
[__::mapproj::fromRobinson__ *lambda\_0* *x* *y*](#18)  
[__::mapproj::toCassini__ *lambda\_0* *phi\_0* *lambda* *phi*](#19)  
[__::mapproj::fromCassini__ *lambda\_0* *phi\_0* *x* *y*](#20)  
[__::mapproj::toPeirceQuincuncial__ *lambda\_0* *lambda* *phi*](#21)  
[__::mapproj::fromPeirceQuincuncial__ *lambda\_0* *x* *y*](#22)  
[__::mapproj::toOrthographic__ *lambda\_0* *phi\_0* *lambda* *phi*](#23)  
[__::mapproj::fromOrthographic__ *lambda\_0* *phi\_0* *x* *y*](#24)  
[__::mapproj::toStereographic__ *lambda\_0* *phi\_0* *lambda* *phi*](#25)  
[__::mapproj::fromStereographic__ *lambda\_0* *phi\_0* *x* *y*](#26)  
[__::mapproj::toGnomonic__ *lambda\_0* *phi\_0* *lambda* *phi*](#27)  
[__::mapproj::fromGnomonic__ *lambda\_0* *phi\_0* *x* *y*](#28)  
[__::mapproj::toAzimuthalEquidistant__ *lambda\_0* *phi\_0* *lambda* *phi*](#29)  
[__::mapproj::fromAzimuthalEquidistant__ *lambda\_0* *phi\_0* *x* *y*](#30)  
[__::mapproj::toLambertAzimuthalEqualArea__ *lambda\_0* *phi\_0* *lambda* *phi*](#31)  
[__::mapproj::fromLambertAzimuthalEqualArea__ *lambda\_0* *phi\_0* *x* *y*](#32)  
[__::mapproj::toHammer__ *lambda\_0* *lambda* *phi*](#33)  
[__::mapproj::fromHammer__ *lambda\_0* *x* *y*](#34)  
[__::mapproj::toConicEquidistant__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *lambda* *phi*](#35)  
[__::mapproj::fromConicEquidistant__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *x* *y*](#36)  
[__::mapproj::toAlbersEqualAreaConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *lambda* *phi*](#37)  
[__::mapproj::fromAlbersEqualAreaConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *x* *y*](#38)  
[__::mapproj::toLambertConformalConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *lambda* *phi*](#39)  
[__::mapproj::fromLambertConformalConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *x* *y*](#40)  
[__::mapproj::toLambertCylindricalEqualArea__ *lambda\_0* *phi\_0* *lambda* *phi*](#41)  
[__::mapproj::fromLambertCylindricalEqualArea__ *lambda\_0* *phi\_0* *x* *y*](#42)  
[__::mapproj::toBehrmann__ *lambda\_0* *phi\_0* *lambda* *phi*](#43)  
[__::mapproj::fromBehrmann__ *lambda\_0* *phi\_0* *x* *y*](#44)  
[__::mapproj::toTrystanEdwards__ *lambda\_0* *phi\_0* *lambda* *phi*](#45)  
[__::mapproj::fromTrystanEdwards__ *lambda\_0* *phi\_0* *x* *y*](#46)  
[__::mapproj::toHoboDyer__ *lambda\_0* *phi\_0* *lambda* *phi*](#47)  
[__::mapproj::fromHoboDyer__ *lambda\_0* *phi\_0* *x* *y*](#48)  
[__::mapproj::toGallPeters__ *lambda\_0* *phi\_0* *lambda* *phi*](#49)  
[__::mapproj::fromGallPeters__ *lambda\_0* *phi\_0* *x* *y*](#50)  
[__::mapproj::toBalthasart__ *lambda\_0* *phi\_0* *lambda* *phi*](#51)  
[__::mapproj::fromBalthasart__ *lambda\_0* *phi\_0* *x* *y*](#52)  

# <a name='description'></a>DESCRIPTION

The __mapproj__ package provides a set of procedures for converting between
world co\-ordinates \(latitude and longitude\) and map co\-ordinates on a number of
different map projections\.

# <a name='section2'></a>Commands

The following commands convert between world co\-ordinates and map co\-ordinates:

  - <a name='1'></a>__::mapproj::toPlateCarree__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the *plate carrée* \(cylindrical equidistant\) projection\.

  - <a name='2'></a>__::mapproj::fromPlateCarree__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the *plate carrée* \(cylindrical equidistant\) projection\.

  - <a name='3'></a>__::mapproj::toCylindricalEqualArea__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the cylindrical equal\-area projection\.

  - <a name='4'></a>__::mapproj::fromCylindricalEqualArea__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the cylindrical equal\-area projection\.

  - <a name='5'></a>__::mapproj::toMercator__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Mercator \(cylindrical conformal\) projection\.

  - <a name='6'></a>__::mapproj::fromMercator__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Mercator \(cylindrical conformal\) projection\.

  - <a name='7'></a>__::mapproj::toMillerCylindrical__ *lambda\_0* *lambda* *phi*

    Converts to the Miller Cylindrical projection\.

  - <a name='8'></a>__::mapproj::fromMillerCylindrical__ *lambda\_0* *x* *y*

    Converts from the Miller Cylindrical projection\.

  - <a name='9'></a>__::mapproj::toSinusoidal__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the sinusoidal \(Sanson\-Flamsteed\) projection\. projection\.

  - <a name='10'></a>__::mapproj::fromSinusoidal__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the sinusoidal \(Sanson\-Flamsteed\) projection\. projection\.

  - <a name='11'></a>__::mapproj::toMollweide__ *lambda\_0* *lambda* *phi*

    Converts to the Mollweide projection\.

  - <a name='12'></a>__::mapproj::fromMollweide__ *lambda\_0* *x* *y*

    Converts from the Mollweide projection\.

  - <a name='13'></a>__::mapproj::toEckertIV__ *lambda\_0* *lambda* *phi*

    Converts to the Eckert IV projection\.

  - <a name='14'></a>__::mapproj::fromEckertIV__ *lambda\_0* *x* *y*

    Converts from the Eckert IV projection\.

  - <a name='15'></a>__::mapproj::toEckertVI__ *lambda\_0* *lambda* *phi*

    Converts to the Eckert VI projection\.

  - <a name='16'></a>__::mapproj::fromEckertVI__ *lambda\_0* *x* *y*

    Converts from the Eckert VI projection\.

  - <a name='17'></a>__::mapproj::toRobinson__ *lambda\_0* *lambda* *phi*

    Converts to the Robinson projection\.

  - <a name='18'></a>__::mapproj::fromRobinson__ *lambda\_0* *x* *y*

    Converts from the Robinson projection\.

  - <a name='19'></a>__::mapproj::toCassini__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Cassini \(transverse cylindrical equidistant\) projection\.

  - <a name='20'></a>__::mapproj::fromCassini__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Cassini \(transverse cylindrical equidistant\) projection\.

  - <a name='21'></a>__::mapproj::toPeirceQuincuncial__ *lambda\_0* *lambda* *phi*

    Converts to the Peirce Quincuncial Projection\.

  - <a name='22'></a>__::mapproj::fromPeirceQuincuncial__ *lambda\_0* *x* *y*

    Converts from the Peirce Quincuncial Projection\.

  - <a name='23'></a>__::mapproj::toOrthographic__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the orthographic projection\.

  - <a name='24'></a>__::mapproj::fromOrthographic__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the orthographic projection\.

  - <a name='25'></a>__::mapproj::toStereographic__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the stereographic \(azimuthal conformal\) projection\.

  - <a name='26'></a>__::mapproj::fromStereographic__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the stereographic \(azimuthal conformal\) projection\.

  - <a name='27'></a>__::mapproj::toGnomonic__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the gnomonic projection\.

  - <a name='28'></a>__::mapproj::fromGnomonic__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the gnomonic projection\.

  - <a name='29'></a>__::mapproj::toAzimuthalEquidistant__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the azimuthal equidistant projection\.

  - <a name='30'></a>__::mapproj::fromAzimuthalEquidistant__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the azimuthal equidistant projection\.

  - <a name='31'></a>__::mapproj::toLambertAzimuthalEqualArea__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Lambert azimuthal equal\-area projection\.

  - <a name='32'></a>__::mapproj::fromLambertAzimuthalEqualArea__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Lambert azimuthal equal\-area projection\.

  - <a name='33'></a>__::mapproj::toHammer__ *lambda\_0* *lambda* *phi*

    Converts to the Hammer projection\.

  - <a name='34'></a>__::mapproj::fromHammer__ *lambda\_0* *x* *y*

    Converts from the Hammer projection\.

  - <a name='35'></a>__::mapproj::toConicEquidistant__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *lambda* *phi*

    Converts to the conic equidistant projection\.

  - <a name='36'></a>__::mapproj::fromConicEquidistant__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *x* *y*

    Converts from the conic equidistant projection\.

  - <a name='37'></a>__::mapproj::toAlbersEqualAreaConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *lambda* *phi*

    Converts to the Albers equal\-area conic projection\.

  - <a name='38'></a>__::mapproj::fromAlbersEqualAreaConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *x* *y*

    Converts from the Albers equal\-area conic projection\.

  - <a name='39'></a>__::mapproj::toLambertConformalConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *lambda* *phi*

    Converts to the Lambert conformal conic projection\.

  - <a name='40'></a>__::mapproj::fromLambertConformalConic__ *lambda\_0* *phi\_0* *phi\_1* *phi\_2* *x* *y*

    Converts from the Lambert conformal conic projection\.

Among the cylindrical equal\-area projections, there are a number of choices of
standard parallels that have names:

  - <a name='41'></a>__::mapproj::toLambertCylindricalEqualArea__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Lambert cylindrical equal area projection\. \(standard
    parallel is the Equator\.\)

  - <a name='42'></a>__::mapproj::fromLambertCylindricalEqualArea__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Lambert cylindrical equal area projection\. \(standard
    parallel is the Equator\.\)

  - <a name='43'></a>__::mapproj::toBehrmann__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Behrmann cylindrical equal area projection\. \(standard
    parallels are 30 degrees North and South\)

  - <a name='44'></a>__::mapproj::fromBehrmann__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Behrmann cylindrical equal area projection\. \(standard
    parallels are 30 degrees North and South\.\)

  - <a name='45'></a>__::mapproj::toTrystanEdwards__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Trystan Edwards cylindrical equal area projection\. \(standard
    parallels are 37\.4 degrees North and South\)

  - <a name='46'></a>__::mapproj::fromTrystanEdwards__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Trystan Edwards cylindrical equal area projection\.
    \(standard parallels are 37\.4 degrees North and South\.\)

  - <a name='47'></a>__::mapproj::toHoboDyer__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Hobo\-Dyer cylindrical equal area projection\. \(standard
    parallels are 37\.5 degrees North and South\)

  - <a name='48'></a>__::mapproj::fromHoboDyer__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Hobo\-Dyer cylindrical equal area projection\. \(standard
    parallels are 37\.5 degrees North and South\.\)

  - <a name='49'></a>__::mapproj::toGallPeters__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Gall\-Peters cylindrical equal area projection\. \(standard
    parallels are 45 degrees North and South\)

  - <a name='50'></a>__::mapproj::fromGallPeters__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Gall\-Peters cylindrical equal area projection\. \(standard
    parallels are 45 degrees North and South\.\)

  - <a name='51'></a>__::mapproj::toBalthasart__ *lambda\_0* *phi\_0* *lambda* *phi*

    Converts to the Balthasart cylindrical equal area projection\. \(standard
    parallels are 50 degrees North and South\)

  - <a name='52'></a>__::mapproj::fromBalthasart__ *lambda\_0* *phi\_0* *x* *y*

    Converts from the Balthasart cylindrical equal area projection\. \(standard
    parallels are 50 degrees North and South\.\)

# <a name='section3'></a>Arguments

The following arguments are accepted by the projection commands:

  - *lambda*

    Longitude of the point to be projected, in degrees\.

  - *phi*

    Latitude of the point to be projected, in degrees\.

  - *lambda\_0*

    Longitude of the center of the sheet, in degrees\. For many projections, this
    figure is also the reference meridian of the projection\.

  - *phi\_0*

    Latitude of the center of the sheet, in degrees\. For the azimuthal
    projections, this figure is also the latitude of the center of the
    projection\.

  - *phi\_1*

    Latitude of the first reference parallel, for projections that use reference
    parallels\.

  - *phi\_2*

    Latitude of the second reference parallel, for projections that use
    reference parallels\.

  - *x*

    X co\-ordinate of a point on the map, in units of Earth radii\.

  - *y*

    Y co\-ordinate of a point on the map, in units of Earth radii\.

# <a name='section4'></a>Results

For all of the procedures whose names begin with 'to', the return value is a
list comprising an *x* co\-ordinate and a *y* co\-ordinate\. The co\-ordinates
are relative to the center of the map sheet to be drawn, measured in Earth radii
at the reference location on the map\. For all of the functions whose names begin
with 'from', the return value is a list comprising the longitude and latitude,
in degrees\.

# <a name='section5'></a>Choosing a projection

This package offers a great many projections, because no single projection is
appropriate to all maps\. This section attempts to provide guidance on how to
choose a projection\.

First, consider the type of data that you intend to display on the map\. If the
data are *directional* \(*e\.g\.,* winds, ocean currents, or magnetic fields\)
then you need to use a projection that preserves angles; these are known as
*conformal* projections\. Conformal projections include the Mercator, the
Albers azimuthal equal\-area, the stereographic, and the Peirce Quincuncial
projection\. If the data are *thematic*, describing properties of land or
water, such as temperature, population density, land use, or demographics; then
you need a projection that will show these data with the areas on the map
proportional to the areas in real life\. These so\-called *equal area*
projections include the various cylindrical equal area projections, the
sinusoidal projection, the Lambert azimuthal equal\-area projection, the Albers
equal\-area conic projection, and several of the world\-map projections \(Miller
Cylindrical, Mollweide, Eckert IV, Eckert VI, Robinson, and Hammer\)\. If the
significant factor in your data is distance from a central point or line \(such
as air routes\), then you will do best with an *equidistant* projection such as
*plate carrée*, Cassini, azimuthal equidistant, or conic equidistant\. If
direction from a central point is a critical factor in your data \(for instance,
air routes, radio antenna pointing\), then you will almost surely want to use one
of the azimuthal projections\. Appropriate choices are azimuthal equidistant,
azimuthal equal\-area, stereographic, and perhaps orthographic\.

Next, consider how much of the Earth your map will cover, and the general shape
of the area of interest\. For maps of the entire Earth, the cylindrical equal
area, Eckert IV and VI, Mollweide, Robinson, and Hammer projections are good
overall choices\. The Mercator projection is traditional, but the extreme
distortions of area at high latitudes make it a poor choice unless a conformal
projection is required\. The Peirce projection is a better choice of conformal
projection, having less distortion of landforms\. The Miller Cylindrical is a
compromise designed to give shapes similar to the traditional Mercator, but with
less polar stretching\. The Peirce Quincuncial projection shows all the
continents with acceptable distortion if a reference meridian close to \+20
degrees is chosen\. The Robinson projection yields attractive maps for things
like political divisions, but should be avoided in presenting scientific data,
since other projections have moe useful geometric properties\.

If the map will cover a hemisphere, then choose stereographic,
azimuthal\-equidistant, Hammer, or Mollweide projections; these all project the
hemisphere into a circle\.

If the map will cover a large area \(at least a few hundred km on a side\), but
less than a hemisphere, then you have several choices\. Azimuthal projections are
usually good \(choose stereographic, azimuthal equidistant, or Lambert azimuthal
equal\-area according to whether shapes, distances from a central point, or areas
are important\)\. Azimuthal projections \(and possibly the Cassini projection\) are
the only really good choices for mapping the polar regions\.

If the large area is in one of the temperate zones and is round or has a
primarily east\-west extent, then the conic projections are good choices\. Choose
the Lambert conformal conic, the conic equidistant, or the Albers equal\-area
conic according to whether shape, distance, or area are the most important
parameters\. For any of these, the reference parallels should be chosen at
approximately 1/6 and 5/6 of the range of latitudes to be displayed\. For
instance, maps of the 48 coterminous United States are attractive with reference
parallels of 28\.5 and 45\.5 degrees\.

If the large area is equatorial and is round or has a primarily east\-west
extent, then the Mercator projection is a good choice for a conformal
projection; Lambert cylindrical equal\-area and sinusoidal projections are good
equal\-area projections; and the *plate carrée* is a good equidistant
projection\.

Large areas having a primarily North\-South aspect, particularly those spanning
the Equator, need some other choices\. The Cassini projection is a good choice
for an equidistant projection \(for instance, a Cassini projection with a central
meridian of 80 degrees West produces an attractive map of the Americas\)\. The
cylindrical equal\-area, Albers equal\-area conic, sinusoidal, Mollweide and
Hammer projections are possible choices for equal\-area projections\. A good
conformal projection in this situation is the Transverse Mercator, which alas,
is not yet implemented\.

Small areas begin to get into a realm where the ellipticity of the Earth affects
the map scale\. This package does not attempt to handle accurate mapping for
large\-scale topographic maps\. If slight scale errors are acceptable in your
application, then any of the projections appropriate to large areas should work
for small ones as well\.

There are a few projections that are included for their special properties\. The
orthographic projection produces views of the Earth as seen from space\. The
gnomonic projection produces a map on which all great circles \(the shortest
distance between two points on the Earth's surface\) are rendered as straight
lines\. While this projection is useful for navigational planning, it has extreme
distortions of shape and area, and can display only a limited area of the Earth
\(substantially less than a hemisphere\)\.

# <a name='keywords'></a>KEYWORDS

[geodesy](\.\./\.\./\.\./\.\./index\.md\#geodesy),
[map](\.\./\.\./\.\./\.\./index\.md\#map),
[projection](\.\./\.\./\.\./\.\./index\.md\#projection)

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2007 Kevin B\. Kenny <kennykb@acm\.org>
