##+##########################################################################
#
# gpx.tcl -- Parse gpx files
# by Keith Vetter, July 7, 2010
#
# gpx definition:
#   http://www.topografix.com/gpx.asp
#   http://www.topografix.com/GPX/1/1/
#   GPX 1.0 => http://www.topografix.com/gpx_manual.asp
#
# code reference:
#   http://wiki.tcl.tk/26635

# API
#  set token [::gpx::Create gpxFilename]
#  ::gpx::Cleanup $token
#  ::gpx::GetGPXMetadata $token               => dict of metadata
#  ::gpx::GetWaypointCount $token             => number of waypoints
#  ::gpx::GetAllWaypoints $token              => list of waypoint items
#  ::gpx::GetTrackCount $token                => number of tracks
#  ::gpx::GetTrackMetadata $token $whichTrack => dict of metadata for this track
#  ::gpx::GetTrackPoints $token $whichTrack   => list of trkpts for this track
#  ::gpx::GetRouteCount $token                => number of routes
#  ::gpx::GetRouteMetadata $token $whichRoute => dict of metadata for this route
#  ::gpx::GetRoutePoints $token $whichRoute   => list of rtepts for this route
#
# o metadata is a dictionary whose keys depends on the which optional elements
#   are present and whose structure depends on the element's schema
#
# o a waypoint/trackpoint is a 3 element list consisting of latitude,
#   longitude and a dictionary of metadata:
#   e.g. 41.61716028 -70.61758477 {ele 35.706 time 2010-06-17T16:02:28Z}
#

package require Tcl 8.5
package require tdom

namespace eval gpx {
    variable nameSpaces {
        gpx "http://www.topografix.com/GPX/1/1"
        xsi "http://www.w3.org/2001/XMLSchema-instance"
    }
    # gpx 1.0 was obsoleted August 9, 2004, but we handle it anyway
    variable nameSpaces10 {
        gpx "http://www.topografix.com/GPX/1/0"
        topografix "http://www.topografix.com/GPX/Private/TopoGrafix/0/2"
    }
    variable gpx
    set gpx(id) 0

    # Cleanup any existing doms if we reload this module
    ::apply {{} {
        foreach arr [array names ::gpx::gpx dom,*] {
            catch {$::gpx::gpx($arr) delete}
            unset ::gpx::gpx($arr)
        }
    }}
}

##+##########################################################################
#
# ::gpx::Create -- Creates a tdom object, returns opaque token to it
#  parameters: gpxFilename
#  returns: token for this tdom object
#
proc ::gpx::Create {gpxFilename {rawXML {}}} {
    variable nameSpaces
    variable gpx

    if {$rawXML eq ""} {
        set fin [open $gpxFilename r]
        set rawXML [read $fin] ; list
        close $fin
    }

    set token "gpx[incr gpx(id)]"
    dom parse $rawXML gpx(dom,$token)

    # Check version 1.0, 1.1 or fail
    set version [[$gpx(dom,$token) documentElement] getAttribute version 0.0]
    if {[package vcompare $version 1.1] >= 0} {
        $gpx(dom,$token) selectNodesNamespaces $::gpx::nameSpaces
    } elseif {[package vcompare $version 1.0] == 0} {
        $gpx(dom,$token) selectNodesNamespaces $::gpx::nameSpaces10
    } else {
        $gpx(dom,$token) delete
        error "$gpxFilename is version $version, need 1.0 or better"
    }
    set gpx(version,$token) $version
    return $token
}
##+##########################################################################
#
# ::gpx::Cleanup -- Cleans up an instance of a tdom object
#   parameter: token returned by ::gpx::Create
#
proc ::gpx::Cleanup {token} {
    variable gpx
    $gpx(dom,$token) delete
    unset gpx(dom,$token)
}


##+##########################################################################
#
# ::gpx::GetGPXMetadata -- Return metadata dictionary for entire document
#   parameter: token returned by ::gpx::Create
#   returns: metadata dictionary for entire document
#
proc ::gpx::GetGPXMetadata {token} {
    set gpxNode [$::gpx::gpx(dom,$token) documentElement]
    set version $::gpx::gpx(version,$token)
    set creator [$gpxNode getAttribute creator ?]
    set attr [dict create version $version creator $creator]

    if {[package vcompare $version 1.0] == 0} {
        set result [::gpx::_ExtractNodeMetadata $token $gpxNode]
    } else {
        set meta [$::gpx::gpx(dom,$token) selectNodes /gpx:gpx/gpx:metadata]
        set result [::gpx::_ExtractNodeMetadata $token $meta]
    }
    set result [dict merge $attr $result]
    return $result
}

##+##########################################################################
#
# ::gpx::GetWaypointCount -- Return number of waypoints defined in gpx file
#   parameter: token returned by ::gpx::Create
#   returns: number of waypoints
#
proc ::gpx::GetWaypointCount {token} {
    set wpts [$::gpx::gpx(dom,$token) selectNodes /gpx:gpx/gpx:wpt]
    return [llength $wpts]
}
##+##########################################################################
#
# ::gpx::GetAllWaypoints -- Returns list of waypoints, each item consists
# of {lat lon <dictionary of metadata>}
#   parameter: token returned by ::gpx::Create
#   returns: list of waypoint items
#
proc ::gpx::GetAllWaypoints {token} {
    set wpts [$::gpx::gpx(dom,$token) selectNodes /gpx:gpx/gpx:wpt]

    set result {}
    foreach wpt $wpts {
        set lat [$wpt getAttribute "lat" ?]
        set lon [$wpt getAttribute "lon" ?]
        set meta [::gpx::_ExtractNodeMetadata $token $wpt]
        lappend result [list $lat $lon $meta]
    }
    return $result
}
##+##########################################################################
#
# ::gpx::GetTrackCount -- returns how many tracks
#   parameter: token returned by ::gpx::Create
#   returns: number of tracks
#
proc ::gpx::GetTrackCount {token} {
    set trks [$::gpx::gpx(dom,$token) selectNodes /gpx:gpx/gpx:trk]
    return [llength $trks]
}
##+##########################################################################
#
# ::gpx::GetTrackMetadata -- Returns metadata dictionary for this track
#   parameter: token returned by ::gpx::Create
#              whichTrack: which track to get (1 based)
#   returns: metadata dictionary for this track
#
proc ::gpx::GetTrackMetadata {token whichTrack} {
    set trkNode [$::gpx::gpx(dom,$token) selectNodes \
                     /gpx:gpx/gpx:trk\[$whichTrack\]]

    set meta [::gpx::_ExtractNodeMetadata $token $trkNode]
}
##+##########################################################################
#
# ::gpx::GetTrackPoints -- Returns track consisting of a list of track points,
# each of which consists of {lat lon <dictionary of metadata>}
#   parameter: token returned by ::gpx::Create
#              whichTrack: which track to get (1 based)
#   returns: list of trackpoints for given track
#
proc ::gpx::GetTrackPoints {token whichTrack} {
    set trkpts [$::gpx::gpx(dom,$token) selectNodes \
                    /gpx:gpx/gpx:trk\[$whichTrack\]//gpx:trkpt]
    set result {}
    foreach trkpt $trkpts {
        set lat [$trkpt getAttribute "lat" ?]
        set lon [$trkpt getAttribute "lon" ?]
        set meta [::gpx::_ExtractNodeMetadata $token $trkpt]
        lappend result [list $lat $lon $meta]
    }
    return $result
}
##+##########################################################################
#
# ::gpx::GetRouteCount -- returns how many routes
#   parameter: token returned by ::gpx::Create
#   returns: number of routes
#
proc ::gpx::GetRouteCount {token} {
    set rtes [$::gpx::gpx(dom,$token) selectNodes /gpx:gpx/gpx:rte]
    return [llength $rtes]
}
##+##########################################################################
#
# ::gpx::GetRouteMetadata -- Returns metadata dictionary for this route
#   parameter: token returned by ::gpx::Create
#              whichRoute: which route to get (1 based)
#   returns: metadata dictionary for this route
#
proc ::gpx::GetRouteMetadata {token whichRoute} {
    set rteNode [$::gpx::gpx(dom,$token) selectNodes \
                     /gpx:gpx/gpx:rte\[$whichRoute\]]

    set meta [::gpx::_ExtractNodeMetadata $token $rteNode]
}
##+##########################################################################
#
# ::gpx::GetRoutePoints -- Returns route consisting of a list of route points,
# each of which consists of {lat lon <dictionary of metadata>}
#   parameter: token returned by ::gpx::Create
#              whichRoute: which route to get (1 based)
#   returns: list of routepoints for given route
#
proc ::gpx::GetRoutePoints {token whichRoute} {
    set rtepts [$::gpx::gpx(dom,$token) selectNodes \
                    /gpx:gpx/gpx:rte\[$whichRoute\]//gpx:rtept]
    set result {}
    foreach rtept $rtepts {
        set lat [$rtept getAttribute "lat" ?]
        set lon [$rtept getAttribute "lon" ?]
        set meta [::gpx::_ExtractNodeMetadata $token $rtept]
        lappend result [list $lat $lon $meta]
    }
    return $result
}
##+##########################################################################
#
# ::gpx::_ExtractNodeMetadata -- Internal routine to get all
# the optional data associated with an xml element. For most
# elements we just want element name and text value but some
# we want their attributes and some we want children metadata.
#
proc ::gpx::_ExtractNodeMetadata {token node} {
    set result {}
    if {$node eq ""} { return $result }

    # author and email elements are different in version 1.0 and 1.1
    set onlyAttributes [list "bounds" "email"]
    set attributesAndElements [list "extension" "author" "link" "copyright"]
    if {$::gpx::gpx(version,$token) == 1.0} {
        set onlyAttributes [list "bounds"]
        set attributesAndElements [list "extension" "link" "copyright"]
    }

    foreach child [$node childNodes] {
        set nodeName [$child nodeName]

        if {$nodeName in {"wpt" "trk" "trkseg" "trkpt" "rte" "rtept"}} continue
        if {[string match "topografix:*" $nodeName]} continue

        if {$nodeName in $onlyAttributes} {
            set attr [::gpx::_GetAllAttributes $child]
            lappend result $nodeName $attr
        } elseif {$nodeName in $attributesAndElements} {
            set attr [::gpx::_GetAllAttributes $child]
            set meta [::gpx::_ExtractNodeMetadata $token $child]
            set meta [concat $attr $meta]
            lappend result $nodeName $meta
        } else {
            lappend result $nodeName [$child asText]
        }
    }
    return $result
}
##+##########################################################################
#
# ::gpx::_GetAllAttributes -- Returns dictionary of attribute name and value
#
proc ::gpx::_GetAllAttributes {node} {
    set result {}
    foreach attr [$node attributes] {
        lappend result $attr [$node getAttribute $attr]
    }
    return $result
}
################################################################

package provide gpx 1
return
