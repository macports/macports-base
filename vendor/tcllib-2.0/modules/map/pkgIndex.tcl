if {![package vsatisfies [package provide Tcl] 8.6 9]} {return}
package ifneeded map::slippy             0.10  [list source [file join $dir map_slippy.tcl]]
package ifneeded map::slippy::fetcher    0.7   [list source [file join $dir map_slippy_fetcher.tcl]]
package ifneeded map::slippy::cache      0.5   [list source [file join $dir map_slippy_cache.tcl]]
package ifneeded map::geocode::nominatim 0.3   [list source [file join $dir map_geocode_nominatim.tcl]]

