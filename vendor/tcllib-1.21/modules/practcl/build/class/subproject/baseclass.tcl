###
# A subordinate project
###
::clay::define ::practcl::subproject {
  superclass ::practcl::module

  method _MorphPatterns {} {
    return {{::practcl::subproject.@name@} {::practcl::@name@} {@name@} {::practcl::subproject}}
  }


  method BuildDir {PWD} {
    return [my define get srcdir]
  }

  method child which {
    switch $which {
      delegate -
      organs {
	# A library can be a project, it can be a module. Any
	# subordinate modules will indicate their existance
        return [list project [self] module [self]]
      }
    }
  }

  method compile {} {}


  method go {} {
    ::practcl::distribution select [self]
    set name [my define get name]
    my define set builddir [my BuildDir [my define get masterpath]]
    my define set builddir [my BuildDir [my define get masterpath]]
    my sources
  }

  # Install project into the local build system
  method install args {}

  method linktype {} {
    return {subordinate package}
  }

  method linker-products {configdict} {}

  method linker-external {configdict} {
    if {[dict exists $configdict PRACTCL_PKG_LIBS]} {
      return [dict get $configdict PRACTCL_PKG_LIBS]
    }
    if {[dict exists $configdict LIBS]} {
      return [dict get $configdict LIBS]
    }
  }

  method linker-extra {configdict} {
    if {[dict exists $configdict PRACTCL_LINKER_EXTRA]} {
      return [dict get $configdict PRACTCL_LINKER_EXTRA]
    }
    return {}
  }

  ###
  # Methods for packages/tools that can be downloaded
  # possibly built and used internally by this Practcl
  # process
  ###

  ###
  # Load the facility into the interpreter
  ###
  method env-bootstrap {} {
    set pkg [my define get pkg_name [my define get name]]
    package require $pkg
  }

  ###
  # Return a file path that exec can call
  ###
  method env-exec {} {}

  ###
  # Install the tool into the local environment
  ###
  method env-install {} {
    my unpack
  }

  ###
  # Do whatever is necessary to get the tool
  # into the local environment
  ###
  method env-load {} {
    my variable loaded
    if {[info exists loaded]} {
      return 0
    }
    if {![my env-present]} {
      my env-install
    }
    my env-bootstrap
    set loaded 1
  }

  ###
  # Check if tool is available for load/already loaded
  ###
  method env-present {} {
    set pkg [my define get pkg_name [my define get name]]
    if {[catch [list package require $pkg]]} {
      return 0
    }
    return 1
  }

  method sources {} {}

  method update {} {
    my ScmUpdate
  }

  method unpack {} {
    cd $::CWD
    ::practcl::distribution select [self]
    my Unpack
    ::practcl::toolset select [self]
    cd $::CWD
  }
}

###
# Trivial implementations
###


###
# A project which the kit compiles and integrates
# the source for itself
###
::clay::define ::practcl::subproject.source {
  superclass ::practcl::subproject ::practcl::library

  method env-bootstrap {} {
    set LibraryRoot [file join [my define get srcdir] [my define get module_root modules]]
    if {[file exists $LibraryRoot] && $LibraryRoot ni $::auto_path} {
      set ::auto_path [linsert $::auto_path 0 $LibraryRoot]
    }
  }

  method env-present {} {
    set path [my define get srcdir]
    return [file exists $path]
  }

  method linktype {} {
    return {subordinate package source}
  }

}

# a copy from the teapot
::clay::define ::practcl::subproject.teapot {
  superclass ::practcl::subproject

  method env-bootstrap {} {
    set pkg [my define get pkg_name [my define get name]]
    package require $pkg
  }

  method env-install {} {
    set pkg [my define get pkg_name [my define get name]]
    set download [my <project> define get download]
    my unpack
    set prefix [string trimleft [my <project> define get prefix] /]
    ::practcl::tcllib_require zipfile::decode
    ::zipfile::decode::unzipfile [file join $download $pkg.zip] [file join $prefix lib $pkg]
  }

  method env-present {} {
    set pkg [my define get pkg_name [my define get name]]
    if {[catch [list package require $pkg]]} {
      return 0
    }
    return 1
  }

  method install DEST {
    set pkg [my define get pkg_name [my define get name]]
    set download [my <project> define get download]
    my unpack
    set prefix [string trimleft [my <project> define get prefix] /]
    ::practcl::tcllib_require zipfile::decode
    ::zipfile::decode::unzipfile [file join $download $pkg.zip] [file join $DEST $prefix lib $pkg]
  }
}

::clay::define ::practcl::subproject.kettle {
  superclass ::practcl::subproject

  method kettle {path args} {
    my variable kettle
    if {![info exists kettle]} {
      ::practcl::LOCAL tool kettle env-load
      set kettle [file join [::practcl::LOCAL tool kettle define get srcdir] kettle]
    }
    set srcdir [my SourceRoot]
    ::practcl::dotclexec $kettle -f [file join $srcdir build.tcl] {*}$args
  }

  method install DEST {
    my kettle reinstall --prefix $DEST
  }
}

::clay::define ::practcl::subproject.critcl {
  superclass ::practcl::subproject

  method install DEST {
    my critcl -pkg [my define get name]
    set srcdir [my SourceRoot]
    ::practcl::copyDir [file join $srcdir [my define get name]] [file join $DEST lib [my define get name]]
  }
}

::clay::define ::practcl::subproject.sak {
  superclass ::practcl::subproject

  method env-bootstrap {} {
    set LibraryRoot [file join [my define get srcdir] [my define get module_root modules]]
    if {[file exists $LibraryRoot] && $LibraryRoot ni $::auto_path} {
      set ::auto_path [linsert $::auto_path 0 $LibraryRoot]
    }
  }

  method env-install {} {
    ###
    # Handle teapot installs
    ###
    set pkg [my define get pkg_name [my define get name]]
    my unpack
    set prefix [my <project> define get prefix [file normalize [file join ~ tcl]]]
    set srcdir [my define get srcdir]
    ::practcl::dotclexec [file join $srcdir installer.tcl] \
      -apps -app-path [file join $prefix apps] \
      -html -html-path [file join $prefix doc html $pkg] \
      -pkg-path [file join $prefix lib $pkg]  \
      -no-nroff -no-wait -no-gui
  }

  method env-present {} {
    set path [my define get srcdir]
    return [file exists $path]
  }

  method install DEST {
    ###
    # Handle teapot installs
    ###
    set pkg [my define get pkg_name [my define get name]]
    my unpack
    set prefix [string trimleft [my <project> define get prefix] /]
    set srcdir [my define get srcdir]
    ::practcl::dotclexec [file join $srcdir installer.tcl] \
      -pkg-path [file join $DEST $prefix lib $pkg]  \
      -no-examples -no-html -no-nroff \
      -no-wait -no-gui -no-apps
  }

  method install-module {DEST args} {
    set srcdir [my define get srcdir]
    if {[llength $args]==1 && [lindex $args 0] in {* all}} {
      set pkg [my define get pkg_name [my define get name]]
      ::practcl::dotclexec [file join $srcdir installer.tcl] \
        -pkg-path [file join $DEST $pkg]  \
        -no-examples -no-html -no-nroff \
        -no-wait -no-gui -no-apps
    } else {
      foreach module $args {
        ::practcl::installModule [file join $srcdir modules $module] [file join $DEST $module]
      }
    }
  }
}


::clay::define ::practcl::subproject.practcl {
  superclass ::practcl::subproject

  method env-bootstrap {} {
    set LibraryRoot [file join [my define get srcdir] [my define get module_root modules]]
    if {[file exists $LibraryRoot] && $LibraryRoot ni $::auto_path} {
      set ::auto_path [linsert $::auto_path 0 $LibraryRoot]
    }
  }

  method env-install {} {
    ###
    # Handle teapot installs
    ###
    set pkg [my define get pkg_name [my define get name]]
    my unpack
    set prefix [my <project> define get prefix [file normalize [file join ~ tcl]]]
    set srcdir [my define get srcdir]
    ::practcl::dotclexec [file join $srcdir make.tcl] install [file join $prefix lib $pkg]
  }

  method install DEST {
    ###
    # Handle teapot installs
    ###
    set pkg [my define get pkg_name [my define get name]]
    my unpack
    set prefix [string trimleft [my <project> define get prefix] /]
    set srcdir [my define get srcdir]
    puts [list INSTALLING  [my define get name] to [file join $DEST $prefix lib $pkg]]
    ::practcl::dotclexec [file join $srcdir make.tcl] install [file join $DEST $prefix lib $pkg]
  }

  method install-module {DEST args} {
    set pkg [my define get pkg_name [my define get name]]
    set srcdir [my define get srcdir]
    ::practcl::dotclexec [file join $srcdir make.tcl] install-module $DEST {*}$args
  }
}


