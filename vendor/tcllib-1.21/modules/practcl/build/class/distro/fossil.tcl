###
# A file distribution based on fossil
###
::clay::define ::practcl::distribution.fossil {
  superclass ::practcl::distribution

  method scm_info {} {
    set info [next]
    dict set info scm fossil
    foreach {field value} [::practcl::fossil_status [my define get srcdir]] {
      dict set info $field $value
    }
    return $info
  }

  # Clone the source
  method ScmClone  {} {
    set srcdir [my SrcDir]
    if {[file exists [file join $srcdir .fslckout]]} {
      return
    }
    if {[file exists [file join $srcdir _FOSSIL_]]} {
      return
    }
    if {![::info exists ::practcl::fossil_dbs]} {
      # Get a list of local fossil databases
      set ::practcl::fossil_dbs [exec fossil all list]
    }
    set pkg [my define get name]
    # Return an already downloaded fossil repo
    foreach line [split $::practcl::fossil_dbs \n] {
      set line [string trim $line]
      if {[file rootname [file tail $line]] eq $pkg} {
        return $line
      }
    }
    set download [::practcl::LOCAL define get download]
    set fosdb [file join $download $pkg.fos]
    if {[file exists $fosdb]} {
      return $fosdb
    }

    file mkdir [file join $download fossil]
    set fosdb [file join $download fossil $pkg.fos]
    if {[file exists $fosdb]} {
      return $fosdb
    }

    set cloned 0
    # Attempt to clone from a local network mirror
    if {[::practcl::LOCAL define exists fossil_mirror]} {
      set localmirror [::practcl::LOCAL define get fossil_mirror]
      catch {
        ::practcl::doexec fossil clone $localmirror/$pkg $fosdb
        set cloned 1
      }
      if {$cloned} {
        return $fosdb
      }
    }
    # Attempt to clone from the canonical source
    if {[my define get fossil_url] ne {}} {
      catch {
        ::practcl::doexec fossil clone [my define get fossil_url] $fosdb
        set cloned 1
      }
      if {$cloned} {
        return $fosdb
      }
    }
    # Fall back to the fossil mirror on the island of misfit toys
    ::practcl::doexec fossil clone http://fossil.etoyoc.com/fossil/$pkg $fosdb
    return $fosdb
  }

  method ScmTag {} {
    if {[my define exists scm_tag]} {
      return [my define get scm_tag]
    }
    if {[my define exists tag]} {
      set tag [my define get tag]
    } else {
      set tag trunk
    }
    my define set scm_tag $tag
    return $tag
  }

  method ScmUnpack {} {
    set srcdir [my SrcDir]
    if {[file exists [file join $srcdir .fslckout]]} {
      return 0
    }
    if {[file exists [file join $srcdir _FOSSIL_]]} {
      return 0
    }
    set CWD [pwd]
    set fosdb [my ScmClone]
    set tag [my ScmTag]
    file mkdir $srcdir
    ::practcl::fossil $srcdir open $fosdb $tag
    return 1
  }

  method ScmUpdate {} {
    if {[my ScmUnpack]} {
      return
    }
    set srcdir [my SrcDir]
    set tag [my ScmTag]
    ::practcl::fossil $srcdir update $tag
  }
}

oo::objdefine ::practcl::distribution.fossil {

  # Check for markers in the metadata
  method claim_object obj {
    set path [$obj define get srcdir]
    if {[my claim_path $path]} {
      return true
    }
    if {[$obj define get fossil_url] ne {}} {
      return true
    }
    return false
  }

  method claim_option {} {
    return fossil
  }

  # Check for markers in the source root
  method claim_path path {
    if {[file exists [file join $path .fslckout]]} {
      return true
    }
    if {[file exists [file join $path _FOSSIL_]]} {
      return true
    }
    return false
  }
}
