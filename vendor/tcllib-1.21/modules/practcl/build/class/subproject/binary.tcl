###
# A subordinate binary package
###
::clay::define ::practcl::subproject.binary {
  superclass ::practcl::subproject

  method clean {} {
    set builddir [file normalize [my define get builddir]]
    if {![file exists $builddir]} return
    if {[file exists [file join $builddir make.tcl]]} {
      ::practcl::domake.tcl $builddir clean
    } else {
      catch {::practcl::domake $builddir clean}
    }
  }

 method env-install {} {
    ###
    # Handle tea installs
    ###
    set pkg [my define get pkg_name [my define get name]]
    set os [::practcl::local_os]
    my define set os $os
    my unpack
    set prefix [my <project> define get prefix [file normalize [file join ~ tcl]]]
    set srcdir [my define get srcdir]
    lappend options --prefix $prefix --exec-prefix $prefix
    my define set config_opts $options
    my go
    my clean
    my compile
    my make install {}
  }

  method project-compile-products {} {}

  method ComputeInstall {} {
    if {[my define exists install]} {
      switch [my define get install] {
        static {
          my define set static 1
          my define set autoload 0
        }
        static-autoload {
          my define set static 1
          my define set autoload 1
        }
        vfs {
          my define set static 0
          my define set autoload 0
          my define set vfsinstall 1
        }
        null {
          my define set static 0
          my define set autoload 0
          my define set vfsinstall 0
        }
        default {

        }
      }
    }
  }

  method go {} {
    next
    ::practcl::distribution select [self]
    my ComputeInstall
    my define set builddir [my BuildDir [my define get masterpath]]
  }

  method linker-products {configdict} {
    if {![my define get static 0]} {
      return {}
    }
    set srcdir [my define get builddir]
    if {[dict exists $configdict libfile]} {
      return " [file join $srcdir [dict get $configdict libfile]]"
    }
  }

  method project-static-packages {} {
    if {![my define get static 0]} {
      return {}
    }
    set result [my define get static_packages]
    set statpkg  [my define get static_pkg]
    set initfunc [my define get initfunc]
    if {$initfunc ne {}} {
      set pkg_name [my define get pkg_name]
      if {$pkg_name ne {}} {
        dict set result $pkg_name initfunc $initfunc
        set version [my define get version]
        if {$version eq {}} {
          my unpack
          set info [my read_configuration]
          set version [dict get $info version]
          set pl {}
          if {[dict exists $info patch_level]} {
            set pl [dict get $info patch_level]
            append version $pl
          }
          my define set version $version
        }
        dict set result $pkg_name version $version
        dict set result $pkg_name autoload [my define get autoload 0]
      }
    }
    foreach item [my link list subordinate] {
      foreach {pkg info} [$item project-static-packages] {
        dict set result $pkg $info
      }
    }
    return $result
  }

  method BuildDir {PWD} {
    set name [my define get name]
    set debug [my define get debug 0]
    if {[my <project> define get LOCAL 0]} {
      return [my define get builddir [file join $PWD local $name]]
    }
    if {$debug} {
      return [my define get builddir [file join $PWD debug $name]]
    } else {
      return [my define get builddir [file join $PWD pkg $name]]
    }
  }

  method compile {} {
    set name [my define get name]
    set PWD $::CWD
    cd $PWD
    my unpack
    set srcdir [file normalize [my SrcDir]]
    set localsrcdir [my MakeDir $srcdir]
    my define set localsrcdir $localsrcdir
    my Collate_Source $PWD
    ###
    # Build a starter VFS for both Tcl and wish
    ###
    set srcdir [my define get srcdir]
    if {[my define get static 1]} {
      puts "BUILDING Static $name $srcdir"
    } else {
      puts "BUILDING Dynamic $name $srcdir"
    }
    my make compile
    cd $PWD
  }

  method Configure {} {
    cd $::CWD
    my unpack
    ::practcl::toolset select [self]
    set srcdir [file normalize [my define get srcdir]]
    set builddir [file normalize [my define get builddir]]
    file mkdir $builddir
    my make autodetect
  }

  method install DEST {
    set PWD [pwd]
    set PREFIX  [my <project> define get prefix]
    ###
    # Handle teapot installs
    ###
    set pkg [my define get pkg_name [my define get name]]
    if {[my <project> define get teapot] ne {}} {
      set TEAPOT [my <project> define get teapot]
      set found 0
      foreach ver [my define get pkg_vers [my define get version]] {
        set teapath [file join $TEAPOT $pkg$ver]
        if {[file exists $teapath]} {
          set dest  [file join $DEST [string trimleft $PREFIX /] lib [file tail $teapath]]
          ::practcl::copyDir $teapath $dest
          return
        }
      }
    }
    my compile
    my make install $DEST
    cd $PWD
  }
}

###
# A subordinate TEA based binary package
###
::clay::define ::practcl::subproject.tea {
  superclass ::practcl::subproject.binary

}

###
# A subordinate C library built by this project
###
::clay::define ::practcl::subproject.library {
  superclass ::practcl::subproject.binary ::practcl::library
  method install DEST {
    my compile
  }
}

###
# A subordinate external C library
###
::clay::define ::practcl::subproject.external {
  superclass ::practcl::subproject.binary
  method install DEST {
    my compile
  }
}
