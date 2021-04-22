## -*- tcl -*-
# ### ### ### ######### ######### #########

## Geocoding (finding geo coordinates from location names and keywords)
## Reverse geocoding (putting names on coordinate sets)
## Both based on the nominatim interface

## See https://wiki.openstreetmap.org/wiki/Nominatim for details

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require http
package require json
package require uri
package require snit

# ### ### ### ######### ######### #########
## Implementation

snit::type map::geocode::nominatim {
    # ### ### ### ######### ######### #########
    ## API

    proc callbackdefault {result} {
        # FIXME Is there a good default here?
        puts "callback: $result"
    }

    proc errordefault {err} {
        bgerror "nominatim error: $err"
    }

    option -baseurl "http://nominatim.openstreetmap.org/search"
    option -callback callbackdefault
    option -error errordefault
    

    # No special constructor, so far

    # ::nominatim::search
    # Queries the location server. Returns a list of dicts, each item having
    # - place_id
    # - licence
    # - osm_type
    # - osm_id
    # - boundingbox
    # - lat
    # - lon
    # - display_name
    # - class
    # - type
    # - icon 
    # Most interesting should be display_name, lat, lon and boundingbox
    method search {query} {
        set query [http::formatQuery q $query format json]
        http::geturl [uri::join {*}[uri::split $options(-baseurl)] query $query] \
            -command [mymethod Done] -timeout 60000
    }

    method Error {context err} {
        uplevel \#0 [list {*}$options(-error) "$context: $err"]
	return
    }

    # Private method
    method Done {htok} {
        if { [http::ncode $htok] != 200 } {
	    $self Error "HTTP" [http::code $htok]
            return
        }
	if { [catch {
	    set res [::json::json2dict [encoding convertfrom utf-8 [::http::data $htok]]]
	} _ err] } {
            $self Error "JSON" $err
            return
        }
        if { [catch {
	    uplevel \#0 [list {*}$options(-callback) $res]
	} _ err] } {
            $self Error "Callback" $err
        }
    }

    # ### ### ### ######### ######### #########
    ## State
    # none, so far
}

package provide map::geocode::nominatim 0.1
