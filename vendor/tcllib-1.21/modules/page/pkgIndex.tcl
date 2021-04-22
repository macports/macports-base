# -- PAGE application packages --
# -- ---- plugin management

package ifneeded page::pluginmgr 0.2 [list source [file join $dir pluginmgr.tcl]]

# -- PAGE plugin packages
# -- ---- Canned configurations

package ifneeded page::config::peg   0.1 [list source [file join $dir plugins/config_peg.tcl]]

# -- PAGE plugin packages
# -- ---- Readers

package ifneeded page::reader::peg     0.1 [list source [file join $dir plugins/reader_peg.tcl]]
package ifneeded page::reader::lemon   0.1 [list source [file join $dir plugins/reader_lemon.tcl]]
package ifneeded page::reader::hb      0.1 [list source [file join $dir plugins/reader_hb.tcl]]
package ifneeded page::reader::ser     0.1 [list source [file join $dir plugins/reader_ser.tcl]]
package ifneeded page::reader::treeser 0.1 [list source [file join $dir plugins/reader_treeser.tcl]]

# -- PAGE plugin packages
# -- ---- Writers

package ifneeded page::writer::null     0.1   [list source [file join $dir plugins/writer_null.tcl]]
package ifneeded page::writer::me       0.1   [list source [file join $dir plugins/writer_me.tcl]]
package ifneeded page::writer::mecpu    0.1.1 [list source [file join $dir plugins/writer_mecpu.tcl]]
package ifneeded page::writer::tree     0.1   [list source [file join $dir plugins/writer_tree.tcl]]
package ifneeded page::writer::tpc      0.1   [list source [file join $dir plugins/writer_tpc.tcl]]
package ifneeded page::writer::hb       0.1   [list source [file join $dir plugins/writer_hb.tcl]]
package ifneeded page::writer::ser      0.1   [list source [file join $dir plugins/writer_ser.tcl]]
package ifneeded page::writer::peg      0.1   [list source [file join $dir plugins/writer_peg.tcl]]
package ifneeded page::writer::identity 0.1   [list source [file join $dir plugins/writer_identity.tcl]]

# -- PAGE plugin packages
# -- ---- Transformations

package ifneeded page::transform::reachable  0.1 \
	[list source [file join $dir plugins/transform_reachable.tcl]]
package ifneeded page::transform::realizable 0.1 \
	[list source [file join $dir plugins/transform_realizable.tcl]]
package ifneeded page::transform::mecpu 0.1 \
	[list source [file join $dir plugins/transform_mecpu.tcl]]

# -- PAGE packages --
# -- --- Parsing and normalization packages used by the reader plugins.

package ifneeded page::parse::peg        0.1 [list source [file join $dir parse_peg.tcl]]
package ifneeded page::parse::lemon      0.1 [list source [file join $dir parse_lemon.tcl]]
package ifneeded page::parse::pegser     0.1 [list source [file join $dir parse_pegser.tcl]]
package ifneeded page::parse::peghb      0.1 [list source [file join $dir parse_peghb.tcl]]

package ifneeded page::util::norm::peg   0.1 [list source [file join $dir util_norm_peg.tcl]]
package ifneeded page::util::norm::lemon 0.1 [list source [file join $dir util_norm_lemon.tcl]]

# @mdgen EXCLUDE: peg_grammar.tcl
### package ifneeded pg::peg::grammar      0.1 [list source [file join $dir peg_grammar.tcl]]

# -- PAGE packages --
# -- --- Code generation packages used by the writer plugins.

package ifneeded page::gen::tree::text 0.1 [list source [file join $dir gen_tree_text.tcl]]
package ifneeded page::gen::peg::cpkg  0.1 [list source [file join $dir gen_peg_cpkg.tcl]]
package ifneeded page::gen::peg::hb    0.1 [list source [file join $dir gen_peg_hb.tcl]]
package ifneeded page::gen::peg::ser   0.1 [list source [file join $dir gen_peg_ser.tcl]]
package ifneeded page::gen::peg::canon 0.1 [list source [file join $dir gen_peg_canon.tcl]]
package ifneeded page::gen::peg::me    0.1 [list source [file join $dir gen_peg_me.tcl]]
package ifneeded page::gen::peg::mecpu 0.1 [list source [file join $dir gen_peg_mecpu.tcl]]

# -- Transformation Helper Packages --

package ifneeded page::analysis::peg::minimize   0.1 [list source [file join $dir analysis_peg_minimize.tcl]]
package ifneeded page::analysis::peg::reachable  0.1 [list source [file join $dir analysis_peg_reachable.tcl]]
package ifneeded page::analysis::peg::realizable 0.1 [list source [file join $dir analysis_peg_realizable.tcl]]
package ifneeded page::analysis::peg::emodes     0.1 [list source [file join $dir analysis_peg_emodes.tcl]]
package ifneeded page::compiler::peg::mecpu      0.1.1 [list source [file join $dir compiler_peg_mecpu.tcl]]

# -- Various other utilities --

package ifneeded page::util::peg   0.1 [list source [file join $dir util_peg.tcl]]
package ifneeded page::util::quote 0.1 [list source [file join $dir util_quote.tcl]]
package ifneeded page::util::flow  0.1 [list source [file join $dir util_flow.tcl]]
