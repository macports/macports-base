###
# A file distribution from zip, tarball, or other non-scm archive format
###
::clay::define ::practcl::distribution.snapshot {
  superclass ::practcl::distribution

  method ScmUnpack {} {
    set srcdir [my SrcDir]
    if {[file exists [file join $srcdir .download]]} {
      return 0
    }
    set dpath [::practcl::LOCAL define get download]
    set url [my define get file_url]
    set fname [file tail $url]
    set archive [file join $dpath $fname]
    if {![file exists $archive]} {
      ::http::wget $url $archive
    }
    set CWD [pwd]
    switch [file extension $fname] {
      .zip {
        # Zipfile

      }
      .tar {
        ::practcl::tcllib_require tar
      }
      .tgz -
      .gz {
        # Tarball
        ::practcl::tcllib_require tcl::transform::zlib
        ::practcl::tcllib_require tar
        set fh [::open $archive]
        fconfigure $fh -encoding binary -translation lf -eofchar {}
        ::tcl::transform::zlib $fh
      }
    }
    set fosdb [my ScmClone]
    set tag [my ScmTag]
    file mkdir $srcdir
    ::practcl::fossil $srcdir open $fosdb $tag
    return 1
  }
}
oo::objdefine ::practcl::distribution.snapshot {

  method claim_object object {
    return false
  }

  method claim_option {} {
    return snapshot
  }

  method claim_path path {
    if {[file exists [file join $path .download]]} {
      return true
    }
    return false
  }
}
