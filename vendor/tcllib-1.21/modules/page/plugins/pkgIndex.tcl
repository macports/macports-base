#puts @plugins
# -- PAGE plugin packages
# -- ---- Canned configurations

package ifneeded page::config::peg   0.1 [list source [file join $dir config_peg.tcl]]

# -- PAGE plugin packages
# -- ---- Readers

package ifneeded page::reader::peg     0.1 [list source [file join $dir reader_peg.tcl]]
package ifneeded page::reader::lemon   0.1 [list source [file join $dir reader_lemon.tcl]]
package ifneeded page::reader::hb      0.1 [list source [file join $dir reader_hb.tcl]]
package ifneeded page::reader::ser     0.1 [list source [file join $dir reader_ser.tcl]]
package ifneeded page::reader::treeser 0.1 [list source [file join $dir reader_treeser.tcl]]

# -- PAGE plugin packages
# -- ---- Writers

package ifneeded page::writer::null     0.1 [list source [file join $dir writer_null.tcl]]
package ifneeded page::writer::me       0.1 [list source [file join $dir writer_me.tcl]]
package ifneeded page::writer::mecpu    0.1.1 [list source [file join $dir writer_mecpu.tcl]]
package ifneeded page::writer::tree     0.1 [list source [file join $dir writer_tree.tcl]]
package ifneeded page::writer::tpc      0.1 [list source [file join $dir writer_tpc.tcl]]
package ifneeded page::writer::hb       0.1 [list source [file join $dir writer_hb.tcl]]
package ifneeded page::writer::ser      0.1 [list source [file join $dir writer_ser.tcl]]
package ifneeded page::writer::peg      0.1 [list source [file join $dir writer_peg.tcl]]
package ifneeded page::writer::identity 0.1 [list source [file join $dir writer_identity.tcl]]

# -- PAGE plugin packages
# -- ---- Transformations

package ifneeded page::transform::reachable  0.1 [list source [file join $dir transform_reachable.tcl]]
package ifneeded page::transform::realizable 0.1 [list source [file join $dir transform_realizable.tcl]]
package ifneeded page::transform::mecpu      0.1 [list source [file join $dir transform_mecpu.tcl]]
