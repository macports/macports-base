[example {
    package require fileutil::traverse

    proc NoLinks {fileName} {
        if {[string equal [file type $fileName] link]} {
            return 0
        }
        return 1
    }

    fileutil::traverse T /sys/devices -prefilter NoLinks
    T foreach p {
        puts $p
    }
    T destroy
}]
