if {![package vsatisfies [package provide Tcl] 8.4]} {return}

# Packages for the doctools idx v2 implementation
# (still v1.1 docidx language).

# - Index container, mutable index objects
# - Export and import management
# - Export and import plugins
# - Parser for docidx markup, and handling serializations
# - Message catalogs for the parser

package ifneeded doctools::idx                 2     [list source [file join $dir container.tcl]]
package ifneeded doctools::idx::export         0.2.1 [list source [file join $dir export.tcl]]

package ifneeded doctools::idx::export::docidx 0.1 [list source [file join $dir export_docidx.tcl]]
package ifneeded doctools::idx::export::html   0.2 [list source [file join $dir export_html.tcl]]
package ifneeded doctools::idx::export::json   0.1 [list source [file join $dir export_json.tcl]]
package ifneeded doctools::idx::export::nroff  0.3 [list source [file join $dir export_nroff.tcl]]
package ifneeded doctools::idx::export::text   0.2 [list source [file join $dir export_text.tcl]]
package ifneeded doctools::idx::export::wiki   0.2 [list source [file join $dir export_wiki.tcl]]

package ifneeded doctools::idx::import::docidx 0.1 [list source [file join $dir import_docidx.tcl]]
package ifneeded doctools::idx::import::json   0.1 [list source [file join $dir import_json.tcl]]

package ifneeded doctools::idx::parse          0.1 [list source [file join $dir parse.tcl]]
package ifneeded doctools::idx::structure      0.1 [list source [file join $dir structure.tcl]]

package ifneeded doctools::msgcat::idx::c      0.1 [list source [file join $dir msgcat_c.tcl]]
package ifneeded doctools::msgcat::idx::de     0.1 [list source [file join $dir msgcat_de.tcl]]
package ifneeded doctools::msgcat::idx::en     0.1 [list source [file join $dir msgcat_en.tcl]]
package ifneeded doctools::msgcat::idx::fr     0.1 [list source [file join $dir msgcat_fr.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}

package ifneeded doctools::idx::import         0.2.1 [list source [file join $dir import.tcl]]
