::clay::define ::practcl::toolset.msvc {
  superclass ::practcl::toolset

  # MSVC always builds in the source directory
  method BuildDir {PWD} {
    set srcdir [my define get srcdir]
    return $srcdir
  }


  # Do nothing
  Ensemble make::autodetect {} {
  }

  Ensemble make::clean {} {
    set PWD [pwd]
    set srcdir [my define get srcdir]
    cd $srcdir
    catch {::practcl::doexec nmake -f makefile.vc clean}
    cd $PWD
  }

  Ensemble make::compile {} {
    set srcdir [my define get srcdir]
    if {[my define get static 1]} {
      puts "BUILDING Static $name $srcdir"
    } else {
      puts "BUILDING Dynamic $name $srcdir"
    }
    cd $srcdir
    if {[file exists [file join $srcdir make.tcl]]} {
      if {[my define get debug 0]} {
        ::practcl::domake.tcl $srcdir debug all
      } else {
        ::practcl::domake.tcl $srcdir all
      }
    } else {
      if {[file exists [file join $srcdir makefile.vc]]} {
        ::practcl::doexec nmake -f makefile.vc INSTALLDIR=[my <project> define get installdir]  {*}[my NmakeOpts] release
      } elseif {[file exists [file join $srcdir win makefile.vc]]} {
        cd [file join $srcdir win]
        ::practcl::doexec nmake -f makefile.vc INSTALLDIR=[my <project> define get installdir]  {*}[my NmakeOpts] release
      } else {
        error "No make.tcl or makefile.vc found for project $name"
      }
    }
  }

  Ensemble make::install DEST {
    set PWD [pwd]
    set srcdir [my define get srcdir]
    cd $srcdir
    if {$DEST eq {}} {
      error "No destination given"
    }
    if {[my <project> define get LOCAL 0] || $DEST eq {}} {
      if {[file exists [file join $srcdir make.tcl]]} {
        # Practcl builds can inject right to where we need them
        puts "[self] Local Install (Practcl)"
        ::practcl::domake.tcl $srcdir install
      } else {
        puts "[self] Local Install (Nmake)"
        ::practcl::doexec nmake -f makefile.vc {*}[my NmakeOpts] install
      }
    } else {
      if {[file exists [file join $srcdir make.tcl]]} {
        # Practcl builds can inject right to where we need them
        puts "[self] VFS INSTALL $DEST (Practcl)"
        ::practcl::domake.tcl $srcdir install-package $DEST
      } else {
        puts "[self] VFS INSTALL $DEST"
        ::practcl::doexec nmake -f makefile.vc INSTALLDIR=$DEST {*}[my NmakeOpts] install
      }
    }
    cd $PWD
  }

  # Detect what directory contains the Makefile template
  method MakeDir {srcdir} {
    set localsrcdir $srcdir
    if {[file exists [file join $srcdir generic]]} {
      my define add include_dir [file join $srcdir generic]
    }
    if {[file exists [file join $srcdir win]]} {
       my define add include_dir [file join $srcdir win]
    }
    if {[file exists [file join $srcdir makefile.vc]]} {
      set localsrcdir [file join $srcdir win]
    }
    return $localsrcdir
  }

  method NmakeOpts {} {
    set opts {}
    set builddir [file normalize [my define get builddir]]

    if {[my <project> define exists tclsrcdir]} {
      ###
      # On Windows we are probably running under MSYS, which doesn't deal with
      # spaces in filename well
      ###
      set TCLSRCDIR  [::practcl::file_relative [file normalize $builddir] [file normalize [file join $::CWD [my <project> define get tclsrcdir] ..]]]
      set TCLGENERIC [::practcl::file_relative [file normalize $builddir] [file normalize [file join $::CWD [my <project> define get tclsrcdir] .. generic]]]
      lappend opts TCLDIR=[file normalize $TCLSRCDIR]
      #--with-tclinclude=$TCLGENERIC
    }
    if {[my <project> define exists tksrcdir]} {
      set TKSRCDIR  [::practcl::file_relative [file normalize $builddir] [file normalize [file join $::CWD [my <project> define get tksrcdir] ..]]]
      set TKGENERIC [::practcl::file_relative [file normalize $builddir] [file normalize [file join $::CWD [my <project> define get tksrcdir] .. generic]]]
      #lappend opts --with-tk=$TKSRCDIR --with-tkinclude=$TKGENERIC
      lappend opts TKDIR=[file normalize $TKSRCDIR]
    }
    return $opts
  }
}
