
proc stream {{size 128000}} {
    set chan [tcl::chan::memchan]
    set line {}
    while 1 {
	incr i
	set istring $i
	set ilen [string length $istring]
	if {$line ne {}} {
	    append line { }
	    incr size -1 
	}
	append line $istring
	incr size -$ilen
	if {$size < 1} {
	    set line [string range $line 0 end-[expr {abs(1-$size)}]]
	    puts $chan $line
	    break
	}

	if {$i % 10 == 0} {
	    puts $chan $line 
	    incr size -1 ;# for the [puts] newline
	    set line {}
	}
    }

    seek $chan 0
    return $chan
}

proc header_posix {tarball} {
    dict with tarball {} 
    tar::formatHeader $path \
	[dict create \
	     mode $mode \
	     type $type \
	     uid  $uid \
	     gid  $gid \
	     size $size \
	     mtime $mtime]
}

proc setup1 {} {
    variable chan1
    variable res {}
    variable tmpdir tartest

    tcltest::makeDirectory $tmpdir

    foreach directory {
	one
	one/two
	one/three
    } {
	tcltest::makeDirectory $tmpdir/$directory
	set    chan [open $tmpdir/$directory/a w]
	puts  $chan hello[incr i]
	close $chan
    }
    set chan1 [stream]
}

proc large-path {} {
    return aaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbaaaaa/bbbbtcllib/modules/tar
}

proc setup2 {} {
    variable chan1
    variable res {}
    variable tmpdir tartest
    variable tmpfile tarX

    tcltest::makeDirectory $tmpdir
    tcltest::makeFile {} $tmpfile

    foreach directory [list [large-path]] {
	tcltest::makeDirectory $tmpdir/$directory
	set    chan [open $tmpdir/$directory/a w]
	puts  $chan hello[incr i]
	close $chan
    }
    set chan1 [open $tmpfile w+]
}

proc cleanup1 {} {
    variable chan1
    close $chan1
    tcltest::removeDirectory tartest
    return
}

proc cleanup2 {} {
    variable chan1
    variable tmpdir
    variable tmpfile
    catch { close $chan1 }
    tcltest::removeDirectory $tmpdir
    tcltest::removeFile      $tmpfile
    tcltest::removeFile      $tmpfile.err
    return
}

variable filesys {
    Dir1 {
	File1 {
	    type 0
	    mode 755
	    uid 13103
	    gid 18103
	    size 100
	    mtime 5706756101
	}
    }

    Dir2 {
	File1 {
	    type 0
	    mode 644
	    uid 15103
	    gid 19103
	    size 100
	    mtime 5706776103
	}
    }
}
