# global port routines
package provide portpatch 1.0
package require portutil 1.0

register target patch portpatch::main 
register requires patch main fetch checksum extract

namespace eval portpatch {
	variable options
}

proc portpatch::main {args} {
	global portname patchfiles distdir filesdir workdir portdir portpath

	if ![info exists patchfiles] {
		return 0
	}
	foreach patch $patchfiles {
		if [file exists $portdir/$filesdir/$patch] {
			lappend patchlist $portdir/$filesdir/$patch
		} elseif [file exists $portpath/$distdir/$patch] {
			lappend patchlist $portpath/$distdir/$patch
		}
	}
	if ![info exists patchlist] {
		return -code error "Patch files missing"
	}

	cd $portdir/$workdir
	foreach patch $patchlist {
		switch -glob -- [file tail $patch] {
			*.Z -
			*.gz {system "gzcat $patch | patch -p0"}
			*.bz2 {system "bzcat $patch | patch -p0"}
			default {system "patch -p0 < $patch"}
		}
	}
	return 0
}
