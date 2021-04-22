
[//000000001]: # (gpx \- GPS eXchange Format \(GPX\))
[//000000002]: # (Generated from file 'gpx\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (Copyright &copy; 2010, Keith Vetter <kvetter@gmail\.com>)
[//000000004]: # (gpx\(n\) 0\.9 tcllib "GPS eXchange Format \(GPX\)")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

gpx \- Extracts waypoints, tracks and routes from GPX files

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [COMMANDS](#section2)

  - [DATA STRUCTURES](#section3)

  - [EXAMPLE](#section4)

  - [REFERENCES](#section5)

  - [AUTHOR](#section6)

  - [Bugs, Ideas, Feedback](#section7)

  - [Keywords](#keywords)

  - [Category](#category)

  - [Copyright](#copyright)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require gpx ?0\.9?  

[__::gpx::Create__ *gpxFilename* ?*rawXML*?](#1)  
[__::gpx::Cleanup__ *token*](#2)  
[__::gpx::GetGPXMetadata__ *token*](#3)  
[__::gpx::GetWaypointCount__ *token*](#4)  
[__::gpx::GetAllWaypoints__ *token*](#5)  
[__::gpx::GetTrackCount__ *token*](#6)  
[__::gpx::GetTrackMetadata__ *token* *whichTrack*](#7)  
[__::gpx::GetTrackPoints__ *token* *whichTrack*](#8)  
[__::gpx::GetRouteCount__ *token*](#9)  
[__::gpx::GetRouteMetadata__ *token* *whichRoute*](#10)  
[__::gpx::GetRoutePoints__ *token* *whichRoute*](#11)  

# <a name='description'></a>DESCRIPTION

This module parses and extracts waypoints, tracks, routes and metadata from a
GPX \(GPS eXchange\) file\. Both GPX version 1\.0 and 1\.1 are supported\.

# <a name='section2'></a>COMMANDS

  - <a name='1'></a>__::gpx::Create__ *gpxFilename* ?*rawXML*?

    The __::gpx::Create__ is the first command called to process GPX data\.
    It takes the GPX data from either the *rawXML* parameter if present or
    from the contents of *gpxFilename*, and parses it using *tdom*\. It
    returns a token value that is used by all the other commands\.

  - <a name='2'></a>__::gpx::Cleanup__ *token*

    This procedure cleans up resources associated with *token*\. It is
    *strongly* recommended that you call this function after you are done with
    a given GPX file\. Not doing so will result in memory not being freed, and if
    your app calls __::gpx::Create__ enough times, the memory leak could
    cause a performance hit\.\.\.or worse\.

  - <a name='3'></a>__::gpx::GetGPXMetadata__ *token*

    This procedure returns a dictionary of the metadata associated with the GPX
    data identified by *token*\. The format of the metadata dictionary is
    described below, but keys *version* and *creator* will always be
    present\.

  - <a name='4'></a>__::gpx::GetWaypointCount__ *token*

    This procedure returns the number of waypoints defined in the GPX data
    identified by *token*\.

  - <a name='5'></a>__::gpx::GetAllWaypoints__ *token*

    This procedure returns the a list of waypoints defined in the GPX data
    identified by *token*\. The format of each waypoint item is described
    below\.

  - <a name='6'></a>__::gpx::GetTrackCount__ *token*

    This procedure returns the number of tracks defined in the GPX data
    identified by *token*\.

  - <a name='7'></a>__::gpx::GetTrackMetadata__ *token* *whichTrack*

    This procedure returns a dictionary of the metadata associated track number
    *whichTrack* \(1 based\) in the GPX data identified by *token*\. The format
    of the metadata dictionary is described below\.

  - <a name='8'></a>__::gpx::GetTrackPoints__ *token* *whichTrack*

    The procedure returns a list of track points comprising track number
    *whichTrack* \(1 based\) in the GPX data identified by *token*\. The format
    of the metadata dictionary is described below\.

  - <a name='9'></a>__::gpx::GetRouteCount__ *token*

    This procedure returns the number of routes defined in the GPX data
    identified by *token*\.

  - <a name='10'></a>__::gpx::GetRouteMetadata__ *token* *whichRoute*

    This procedure returns a dictionary of the metadata associated route number
    *whichRoute* \(1 based\) in the GPX data identified by *token*\. The format
    of the metadata dictionary is described below\.

  - <a name='11'></a>__::gpx::GetRoutePoints__ *token* *whichRoute*

    The procedure returns a list of route points comprising route number
    *whichRoute* \(1 based\) in the GPX data identified by *token*\. The format
    of the metadata dictionary is described below\.

# <a name='section3'></a>DATA STRUCTURES

  - metadata dictionary

    The metadata associated with either the GPX document, a track, a route, a
    waypoint, a track point or route point is returned in a dictionary\. The keys
    of that dictionary will be whatever optional GPX elements are present\. The
    value for each key depends on the GPX schema for that element\. For example,
    the value for a version key will be a string, while for a link key will be a
    sub\-dictionary with keys *href* and optionally *text* and *type*\.

  - point item

    Each item in a track or route list of points consists of a list of three
    elements: *latitude*, *longitude* and *metadata dictionary*\.
    *Latitude* and *longitude* are decimal numbers\. The *metadata
    dictionary* format is described above\. For points in a track, typically
    there will always be ele \(elevation\) and time metadata keys\.

# <a name='section4'></a>EXAMPLE

    % set token [::gpx::Create myGpxFile.gpx]
    % set version [dict get [::gpx::GetGPXMetadata $token] version]
    % set trackCnt [::gpx::GetTrackCount $token]
    % set firstPoint [lindex [::gpx::GetTrackPoints $token 1] 0]
    % lassign $firstPoint lat lon ptMetadata
    % puts "first point in the first track is at $lat, $lon"
    % if {[dict exists $ptMetadata ele]} {
         puts "at elevation [dict get $ptMetadata ele] meters"
      }
    % ::gpx::Cleanup $token

# <a name='section5'></a>REFERENCES

  1. GPX: the GPS Exchange Format
     \([http://www\.topografix\.com/gpx\.asp](http://www\.topografix\.com/gpx\.asp)\)

  1. GPX 1\.1 Schema Documentation
     \([http://www\.topografix\.com/GPX/1/1/](http://www\.topografix\.com/GPX/1/1/)\)

  1. GPX 1\.0 Developer's Manual
     \([http://www\.topografix\.com/gpx\_manual\.asp](http://www\.topografix\.com/gpx\_manual\.asp)\)

# <a name='section6'></a>AUTHOR

Keith Vetter

# <a name='section7'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *gpx* of the [Tcllib
Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report any ideas
for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[gps](\.\./\.\./\.\./\.\./index\.md\#gps), [gpx](\.\./\.\./\.\./\.\./index\.md\#gpx)

# <a name='category'></a>CATEGORY

File formats

# <a name='copyright'></a>COPYRIGHT

Copyright &copy; 2010, Keith Vetter <kvetter@gmail\.com>
