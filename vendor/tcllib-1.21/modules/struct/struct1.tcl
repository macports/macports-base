package require Tcl 8.2
package require struct::graph     1.2.1
package require struct::queue     1.2.1
package require struct::stack     1.2.1
package require struct::tree      1.2.1
package require struct::matrix    1.2.1
package require struct::pool      1.2.1
package require struct::record    1.2.1
package require struct::list      1.4
package require struct::prioqueue 1.3
package require struct::skiplist  1.3

namespace eval ::struct {
    namespace export *
}

package provide struct 1.4
