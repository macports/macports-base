
[//000000001]: # (map::geocode::nominatim \- Mapping utilities)
[//000000002]: # (Generated from file 'map\_geocode\_nominatim\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (map::geocode::nominatim\(n\) 0\.1 tcllib "Mapping utilities")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

map::geocode::nominatim \- Resolving geographical names with a Nominatim service

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [API](#section2)

      - [Options](#subsection1)

      - [Methods](#subsection2)

  - [References](#section3)

  - [Keywords](#keywords)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require http  
package require json  
package require uri  
package require snit  
package require map::geocode::nominatim ?0\.1?  

[__::map::geocode::nominatim__ *requestor* ?__\-baseurl__ *url*? ?__\-callback__ *callback*? ?__\-error__ *error callback*?](#1)  
[__$cmdprefix__ *result*](#2)  
[__$cmdprefix__ *errorstring*](#3)  
[*requestor* __search__ *query*](#4)  

# <a name='description'></a>DESCRIPTION

This package provides a class for accessing geocoding services which implement
the *[Nominatim](\.\./\.\./\.\./\.\./index\.md\#nominatim)* interface \(see
[References](#section3)\)

# <a name='section2'></a>API

  - <a name='1'></a>__::map::geocode::nominatim__ *requestor* ?__\-baseurl__ *url*? ?__\-callback__ *callback*? ?__\-error__ *error callback*?

    Creates a geocoding request object *requestor*, which will send its
    requests to the *[Nominatim](\.\./\.\./\.\./\.\./index\.md\#nominatim)* server\.

    The result of the command is *name*\.

## <a name='subsection1'></a>Options

  - __\-baseurl__ *url*

    The base URL of the *[Nominatim](\.\./\.\./\.\./\.\./index\.md\#nominatim)*
    service\. Default value is *OpenStreetMap's* service at
    [http://nominatim\.openstreetmap\.org/search](http://nominatim\.openstreetmap\.org/search)
    A possible free alternative is at
    [http://open\.mapquestapi\.com//nominatim/v1/search](http://open\.mapquestapi\.com//nominatim/v1/search)

  - __\-callback__ *cmdprefix*

    A command prefix to be invoked when search result become available\. The
    default setting, active when nothing was specified on object creation, is to
    print the *result* \(see below\) to
    *[stdout](\.\./\.\./\.\./\.\./index\.md\#stdout)*\. The result of the command
    prefix is ignored\. Errors thrown by the command prefix are caught and cause
    the invokation of the error callback \(see option __\-error__ below\), with
    the error message as argument\.

    The signature of the command prefix is:

      * <a name='2'></a>__$cmdprefix__ *result*

        The *result* is a list of dictionaries, containing one item per hit\.
        Each dictionary will have the following entries:

          + place\_id

            The place ID \(FIXME: what's this?\)

          + licence

            The data licence string

          + osm\_type

            The OSM type of the location

          + osm\_id

            FIXME

          + boundingbox

            The coordinates of the bounding box \(min and max latitude, min and
            max longitude\)

          + lat

            The location's latitude

          + lon

            The location's longitude

          + display\_name

            the location's human readable name

          + class

            FIXME

          + type

            FIXME

          + icon

            FIXME

  - __\-error__ *cmdprefix*

    A command prefix to be invoked when encountering errors\. Typically these are
    HTTP errors\. The default setting, active when nothing was specified on
    object creation, is to print the *errorstring* \(see below\) to *stderr*\.
    The result of the command prefix is ignored\. Errors thrown by the command
    prefix are passed to higher levels\.

    The signature of the command prefix is:

      * <a name='3'></a>__$cmdprefix__ *errorstring*

## <a name='subsection2'></a>Methods

  - <a name='4'></a>*requestor* __search__ *query*

    This method returns a list of dictionaries, one item per hit for the
    specified *query*\.

# <a name='section3'></a>References

  1. [http://wiki\.openstreetmap\.org/wiki/Nominatim](http://wiki\.openstreetmap\.org/wiki/Nominatim)

  1. [http://open\.mapquestapi\.com/nominatim/](http://open\.mapquestapi\.com/nominatim/)

# <a name='keywords'></a>KEYWORDS

[geocoding](\.\./\.\./\.\./\.\./index\.md\#geocoding),
[http](\.\./\.\./\.\./\.\./index\.md\#http),
[location](\.\./\.\./\.\./\.\./index\.md\#location),
[map](\.\./\.\./\.\./\.\./index\.md\#map),
[nominatim](\.\./\.\./\.\./\.\./index\.md\#nominatim),
[server](\.\./\.\./\.\./\.\./index\.md\#server), [url](\.\./\.\./\.\./\.\./index\.md\#url)
