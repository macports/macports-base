# ex:ts=4
#
# Insert some license text here at some point soon.
#

# the 'clean' target is provided by this package

package provide portclean 1.0
package require portutil 1.0

register com.apple.clean target clean_main clean_init always
register com.apple.clean provides clean
register com.apple.clean requires main

proc clean_init {args} {
    return 0
}

proc clean_main {args} {
    global portpath workdir
    if {[ui_yesno "Delete ${portpath}/${workdir}? "]} {
	system "rm -rf \"${portpath}/${workdir}\""
    }
    return 0
}
