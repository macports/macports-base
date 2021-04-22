if {![package vsatisfies [package provide Tcl] 8.4]} {return}

# Packages for the doctools toc v2 implementation
# (still v1.1 doctoc language).

# - Index container, mutable toc objects
# - Export and import management
# - Export and import plugins
# - Parser for doctoc markup, and handling serializations
# - Message catalogs for the parser

package ifneeded doctools::toc                 2     [list source [file join $dir container.tcl]]
package ifneeded doctools::toc::export         0.2.1 [list source [file join $dir export.tcl]]

package ifneeded doctools::toc::export::doctoc 0.1 [list source [file join $dir export_doctoc.tcl]]
package ifneeded doctools::toc::export::html   0.1 [list source [file join $dir export_html.tcl]]
package ifneeded doctools::toc::export::json   0.1 [list source [file join $dir export_json.tcl]]
package ifneeded doctools::toc::export::nroff  0.2 [list source [file join $dir export_nroff.tcl]]
package ifneeded doctools::toc::export::text   0.1 [list source [file join $dir export_text.tcl]]
package ifneeded doctools::toc::export::wiki   0.1 [list source [file join $dir export_wiki.tcl]]

package ifneeded doctools::toc::import::doctoc 0.1 [list source [file join $dir import_doctoc.tcl]]
package ifneeded doctools::toc::import::json   0.1 [list source [file join $dir import_json.tcl]]

package ifneeded doctools::toc::parse          0.1 [list source [file join $dir parse.tcl]]
package ifneeded doctools::toc::structure      0.1 [list source [file join $dir structure.tcl]]

package ifneeded doctools::msgcat::toc::c      0.1 [list source [file join $dir msgcat_c.tcl]]
package ifneeded doctools::msgcat::toc::de     0.1 [list source [file join $dir msgcat_de.tcl]]
package ifneeded doctools::msgcat::toc::en     0.1 [list source [file join $dir msgcat_en.tcl]]
package ifneeded doctools::msgcat::toc::fr     0.1 [list source [file join $dir msgcat_fr.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}

package ifneeded doctools::toc::import         0.2.1 [list source [file join $dir import.tcl]]
