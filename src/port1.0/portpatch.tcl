# ex:ts=4
#
# Insert some license text here at some point soon.
#

package provide portpatch 1.0
package require portutil 1.0

register com.apple.patch target build patch_main
register com.apple.patch provides patch
register com.apple.patch requires main fetch checksum extract
register com.apple.patch swdep build depends_build

set UI_PREFIX "---> "

proc patch_main {args} {
    global portname patchfiles distpath filedir workdir portpath UI_PREFIX

    if ![info exists patchfiles] {
	return 0
    }
    foreach patch $patchfiles {
	if [file exists $portpath/$filedir/$patch] {
	    lappend patchlist $portpath/$filedir/$patch
	} elseif [file exists $distpath/$patch] {
	    lappend patchlist $distpath/$patch
	}
    }
    if ![info exists patchlist] {
	return -code error "Patch files missing"
    }
    cd $portpath/$workdir
    foreach patch $patchlist {
	ui_info "$UI_PREFIX Applying $patch"
	switch -glob -- [file tail $patch] {
	    *.Z -
	    *.gz {system "gzcat $patch | patch -p0"}
	    *.bz2 {system "bzcat $patch | patch -p0"}
	    default {system "patch -p0 < $patch"}
	}
    }
    return 0
}

