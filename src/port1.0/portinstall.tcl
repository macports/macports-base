# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portinstall 1.0
package require portutil 1.0

register com.apple.install target install_main
register com.apple.install provides install
register com.apple.install requires main fetch extract checksum patch configure build
register com.apple.install swdep depends_run depends_lib

# define options
#options make.cmd make.type make.target.all make.target.install

set UI_PREFIX "---> "

proc install_main {args} {

    return 0
}

