# ftp_geturl.tcl --
#
# Copyright (c) 2001 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
#
# ftp::geturl url

package require ftp
package require uri

namespace eval ::ftp {
    namespace export geturl
}

# ::ftp::geturl
#
# Command useable by uri to retrieve the contents of an ftp url.
# Returns the contents of the requested url.

proc ::ftp::geturl {url} {
    # FUTURE: -validate to validate existence of url, but no download
    # of contents.

    array set urlparts [uri::split $url]

    if {$urlparts(user) == {}} {
        set urlparts(user) "anonymous"
    }
    if {$urlparts(pwd) == {}} {
        set urlparts(pwd) "user@localhost.localdomain"
    }
    if {$urlparts(port) == {}} {
        set urlparts(port) 21
    }

    set fdc [ftp::Open $urlparts(host) $urlparts(user) $urlparts(pwd) \
                 -port $urlparts(port)]
    if {$fdc < 0} {
	return -code error "Cannot reach host for url \"$url\""
    }

    # We have reached the host, now get on to retrieve the item.
    # We are very careful in accessing the item because we don't know
    # if it is a file, directory or link. So we change into the
    # directory containing the item, get a list of all entries and
    # then determine if the item actually exists and what type it is,
    # and what actions to perform.

    set ftp_dir  [file dirname $urlparts(path)]
    set ftp_file [file tail    $urlparts(path)]

    set result [ftp::Cd $fdc $ftp_dir]
    if { $result == 0 } {
	ftp::Close $fdc
	return -code error "Cannot reach directory of url \"$url\""
    }

    # Fix for the tkcon List enhancements in ftp.tcl
    set List ::ftp::List_org
    if {[info commands $List] == {}} {
        set List ::ftp::List 
    }

    # The result of List is a list of entries in the given directory.
    # Note that it is in 'ls -l format. We parse that into a more
    # readable array.

    #array set flist [ftp::ParseList [$List $fdc ""]]
    #if {![info exists flist($ftp_file)]} {}
    set flist [$List $fdc $ftp_file]
    if {$flist == {}} {
	ftp::Close $fdc
	return -code error "Cannot reach item of url \"$url\""
    }

    # The item exists, what is it ?
    # File     : Download the contents.
    # Directory: Download a listing, this is its contents.
    # Link     : For now we do not follow the link but return the
    #            meta information, i.e. the path it is pointing to.

    #switch -exact -- [lindex $flist($ftp_file) 0] {}
    switch -exact -- [string index [lindex $flist 0] 0] {
	- {
	    if {[string equal $ftp_file {}]} {
                set contents [ftp::NList $fdc $ftp_file]
            } else {
                ftp::Get $fdc $ftp_file -variable contents
            }
	}
	d {
	    set contents [ftp::NList $fdc $ftp_file]
	}
	l {
	    set contents $flist
	}
        default {
            ftp::Close $fdc
            return -code error "File information \"$flist\" not recognised"
        }
    }

    ftp::Close $fdc
    return $contents
}

# Internal helper to parse a directory listing into something which
# can be better handled by tcl than raw ls -l format.

proc ::ftp::ParseList {flist} {
    array set data {}
    foreach item $flist {
	foreach {mode dummy owner group size month day yrtime name} $item break

	if {[string first : $yrtime] >=0} {
	    set date "$month/$day/[clock format [clock seconds] -format %Y] $yrtime"
	} else {
	    set date "$month/$day/$yrtime 00:00"
	}
	set info [list owner $owner group $group size $size date $date]

	switch -exact -- [string index $mode 0] {
	    - {set type file}
	    d {set type dir}
	    l {set type link ; lappend info link [lindex $item end]}
	}

	set data($name) [list $type $info]
    }
    array get data
}

# ==================================================================
# At last, everything is fine, we can provide the package.

package provide ftp::geturl [lindex {Revision: 0.2.2} 1]
