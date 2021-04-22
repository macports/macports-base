if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded struct            2.1   [list source [file join $dir struct.tcl]]
package ifneeded struct            1.4   [list source [file join $dir struct1.tcl]]

package ifneeded struct::queue     1.4.5 [list source [file join $dir queue.tcl]]
package ifneeded struct::stack     1.5.3 [list source [file join $dir stack.tcl]]
package ifneeded struct::tree      2.1.2 [list source [file join $dir tree.tcl]]
package ifneeded struct::matrix    2.0.4 [list source [file join $dir matrix.tcl]]
package ifneeded struct::pool      1.2.3 [list source [file join $dir pool.tcl]]
package ifneeded struct::record    1.2.2 [list source [file join $dir record.tcl]]
package ifneeded struct::set       2.2.3 [list source [file join $dir sets.tcl]]
package ifneeded struct::prioqueue 1.4   [list source [file join $dir prioqueue.tcl]]
package ifneeded struct::skiplist  1.3   [list source [file join $dir skiplist.tcl]]

package ifneeded struct::graph     1.2.1 [list source [file join $dir graph1.tcl]]
package ifneeded struct::tree      1.2.2 [list source [file join $dir tree1.tcl]]
package ifneeded struct::matrix    1.2.2 [list source [file join $dir matrix1.tcl]]

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded struct::list        1.8.5  [list source [file join $dir list.tcl]]
package ifneeded struct::list::test  1.8.4  [list source [file join $dir list.test.tcl]]
package ifneeded struct::graph     2.4.3  [list source [file join $dir graph.tcl]]
package ifneeded struct::map       1      [list source [file join $dir map.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}

if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded struct::disjointset 1.1 [list source [file join $dir disjointset.tcl]]
package ifneeded struct::graph::op 0.11.3 [list source [file join $dir graphops.tcl]]
