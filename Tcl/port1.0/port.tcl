# ex:ts=4
#
# Insert some license text here at some point soon.
#
# standard package load
package provide port 1.0

package require portmain 1.0
package require portfetch 1.0
package require portchecksum 1.0
package require portextract 1.0
package require portpatch 1.0
package require portconfigure 1.0
package require portmake 1.0
package require portui 1.0

# System wide configuration
if [info exists portconf] {
    source $portconf
}

# Initialize the UI abstraction API
ui_init
