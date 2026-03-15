###
# A toplevel project that is a collection of other projects
###
::clay::define ::practcl::project {
  superclass ::practcl::module

  method _MorphPatterns {} {
    return {{@name@} {::practcl::@name@} {::practcl::project.@name@} {::practcl::project}}
  }

  constructor args {
    my variable define
    if {[llength $args] == 1} {
      set rawcontents [lindex $args 0]
    } else {
      set rawcontents $args
    }
    if {[catch {uplevel 1 [list subst $rawcontents]} contents]} {
      set contents $rawcontents
    }
    ###
    # The first instance of ::practcl::project (or its descendents)
    # registers itself as the ::practcl::MAIN. If a project other
    # than ::practcl::LOCAL is created, odds are that was the one
    # the developer intended to be the main project
    ###
    if {$::practcl::MAIN eq "::practcl::LOCAL"} {
      set ::practcl::MAIN [self]
    }
    # DEFS fields need to be passed unchanged and unsubstituted
    # as we need to preserve their escape characters
    foreach field {TCL_DEFS DEFS TK_DEFS} {
      if {[dict exists $rawcontents $field]} {
        dict set contents $field [dict get $rawcontents $field]
      }
    }
    my graft module [self]
    array set define $contents
    ::practcl::toolset select [self]
    my initialize
  }

  method add_object object {
    my link object $object
  }

  method add_project {pkg info {oodefine {}}} {
    ::practcl::debug [self] add_project $pkg $info
    set os [my define get TEACUP_OS]
    if {$os eq {}} {
      set os [::practcl::os]
      my define set os $os
    }
    set fossilinfo [list download [my define get download] tag trunk sandbox [my define get sandbox]]
    if {[dict exists $info os] && ($os ni [dict get $info os])} return
    # Select which tag to use here.
    # For production builds: tag-release
    set profile [my define get profile release]:
    if {[dict exists $info profile $profile]} {
      dict set info tag [dict get $info profile $profile]
    }
    dict set info USEMSVC [my define get USEMSVC 0]
    dict set info debug [my define get debug 0]
    set obj [namespace current]::PROJECT.$pkg
    if {[info command $obj] eq {}} {
      set obj [::practcl::subproject create $obj [self] [dict merge $fossilinfo [list name $pkg pkg_name $pkg static 0 class subproject.binary] $info]]
    }
    my link object $obj
    oo::objdefine $obj $oodefine
    $obj define set masterpath $::CWD
    $obj go
    return $obj
  }

  method add_tool {pkg info {oodefine {}}} {
    ::practcl::debug [self] add_tool $pkg $info
    set info [dict merge [::practcl::local_os] $info]

    set os [dict get $info TEACUP_OS]
    set fossilinfo [list download [my define get download] tag trunk sandbox [my define get sandbox]]
    if {[dict exists $info os] && ($os ni [dict get $info os])} return
    # Select which tag to use here.
    # For production builds: tag-release
    set profile [my define get profile release]:
    if {[dict exists $info profile $profile]} {
      dict set info tag [dict get $info profile $profile]
    }
    set obj ::practcl::OBJECT::TOOL.$pkg
    if {[info command $obj] eq {}} {
      set obj [::practcl::subproject create $obj [self] [dict merge $fossilinfo [list name $pkg pkg_name $pkg static 0] $info]]
    }
    my link add tool $obj
    oo::objdefine $obj $oodefine
    $obj define set masterpath $::CWD
    $obj go
    return $obj
  }

  ###
  # Compile the Tcl core. If the define [emph tk] is true, compile the
  # Tk core as well
  ###
  method build-tclcore {} {
    set os [my define get TEACUP_OS]
    set tcl_config_opts [::practcl::platform::tcl_core_options $os]
    set tk_config_opts  [::practcl::platform::tk_core_options $os]

    lappend tcl_config_opts --prefix [my define get prefix] --exec-prefix [my define get prefix]
    set tclobj [my tclcore]
    if {[my define get debug 0]} {
      $tclobj define set debug 1
      lappend tcl_config_opts --enable-symbols=true
    }
    $tclobj define set config_opts $tcl_config_opts
    $tclobj go
    $tclobj compile

    set _TclSrcDir [$tclobj define get localsrcdir]
    my define set tclsrcdir $_TclSrcDir
    if {[my define get tk 0]} {
      set tkobj [my tkcore]
      lappend tk_config_opts --with-tcl=[::practcl::file_relative [$tkobj define get builddir]  [$tclobj define get builddir]]
      if {[my define get debug 0]} {
        $tkobj define set debug 1
        lappend tk_config_opts --enable-symbols=true
      }
      $tkobj define set config_opts $tk_config_opts
      $tkobj compile
    }
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

  method linktype {} {
    return project
  }


  # Exercise the methods of a sub-object
  method project {pkg args} {
    set obj [namespace current]::PROJECT.$pkg
    if {[llength $args]==0} {
      return $obj
    }
    ${obj} {*}$args
  }


  method tclcore {} {
    if {[info commands [set obj [my clay delegate tclcore]]] ne {}} {
      return $obj
    }
    if {[info commands [set obj [my project TCLCORE]]] ne {}} {
      my graft tclcore $obj
      return $obj
    }
    if {[info commands [set obj [my project tcl]]] ne {}} {
      my graft tclcore $obj
      return $obj
    }
    if {[info commands [set obj [my tool tcl]]] ne {}} {
      my graft tclcore $obj
      return $obj
    }
    # Provide a fallback
    set obj [my add_tool tcl {
      tag release class subproject.core
      fossil_url http://core.tcl.tk/tcl
    }]
    my graft tclcore $obj
    return $obj
  }

  method tkcore {} {
    if {[set obj [my clay delegate tkcore]] ne {}} {
      return $obj
    }
    if {[set obj [my project tk]] ne {}} {
      my graft tkcore $obj
      return $obj
    }
    if {[set obj [my tool tk]] ne {}} {
      my graft tkcore $obj
      return $obj
    }
    # Provide a fallback
    set obj [my add_tool tk {
      tag release class tool.core
      fossil_url http://core.tcl.tk/tk
    }]
    my graft tkcore $obj
    return $obj
  }

  method tool {pkg args} {
    set obj ::practcl::OBJECT::TOOL.$pkg
    if {[llength $args]==0} {
      return $obj
    }
    ${obj} {*}$args
  }
}
