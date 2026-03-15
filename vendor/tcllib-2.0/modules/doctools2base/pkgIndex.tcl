if {![package vsatisfies [package provide Tcl] 8.5 9]} {return}

# Packages for the doctools {idx,toc,doc} v2 implementation
# (still v1.1 doc{idx,toc} languages).

# Supporting packages
# - Handling text generation, the nroff man.macros definitions,
#            HTML/XML generation, and the default CSS style
# - Handling of message catalogs as packages.
# - Recursive descent parser for Tcl strings (as expected by 'subst -novariables').

package ifneeded doctools::text              0.2 [list source [file join $dir text.tcl]]
package ifneeded doctools::nroff::man_macros 0.2 [list source [file join $dir nroff_manmacros.tcl]]
package ifneeded doctools::html              0.2 [list source [file join $dir html.tcl]]
package ifneeded doctools::html::cssdefaults 0.2 [list source [file join $dir html_cssdefaults.tcl]]
package ifneeded doctools::msgcat            0.2 [list source [file join $dir msgcat.tcl]]
package ifneeded doctools::tcl::parse        0.2 [list source [file join $dir tcl_parse.tcl]]
