source [file join [lindex $argv 0] macports1.0 macports_fastload.tcl]
package require macports
mportinit

set scriptdir [file dirname [info script]]
source ${scriptdir}/../portfetch.tcl
source ${scriptdir}/common.tcl

namespace eval tests {

proc "mirror tags are parsed correctly" {} {
    global distfiles master_sites name dist_subdir filespath scriptdir

    set name test
    set filespath $scriptdir
    set dist_subdir tset
    set portfetch::mirror_sites::sites(macports_test) {
        http://distfiles.macports.org/:mirror
        http://distfiles2.macports.org:80/:mirror
        http://distfiles3.macports.org:80/
        http://distfiles4.macports.org:80/some/subdir/
        http://distfiles5.macports.org:80/some/subdir/:mirror
    }
    set distfiles test.tar.bz2
    set master_sites macports_test
    set fetch_urls {}
    portfetch::checksites [list master_sites {}] ""
    portfetch::checkdistfiles fetch_urls

    global portfetch::urlmap
    foreach {url_var distfile} $fetch_urls {
        if {![info exists urlmap($url_var)]} {
            set urlmap($url_var) $urlmap(master_sites)
        }
        foreach site $urlmap($url_var) {
            set file_url [portfetch::assemble_url $site $distfile]
            lappend all_file_urls $file_url
        }
    }
    set all_file_urls [lsort $all_file_urls]

    set expected [list http://distfiles.macports.org/tset/test.tar.bz2 \
                       http://distfiles2.macports.org:80/tset/test.tar.bz2 \
                       http://distfiles3.macports.org:80/test/test.tar.bz2 \
                       http://distfiles4.macports.org:80/some/subdir/test/test.tar.bz2 \
                       http://distfiles5.macports.org:80/some/subdir/tset/test.tar.bz2]

    test_equal {$all_file_urls} {$expected}
}

# run all tests
foreach proc [info procs *] {
    puts "* ${proc}"
    $proc
}

# namespace eval tests
}
