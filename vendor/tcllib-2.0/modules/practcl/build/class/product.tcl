###
# A deliverable for the build system
###
::clay::define ::practcl::product {

  method code {section body} {
    my variable code
    ::practcl::cputs code($section) $body
  }

  method Collate_Source CWD {}

  method project-compile-products {} {
    set result {}
    noop {
    set filename [my define get filename]
    if {$filename ne {}} {
      ::practcl::debug [self] [self class] [self method] project-compile-products $filename
      if {[my define exists ofile]} {
        set ofile [my define get ofile]
      } else {
        set ofile [my Ofile $filename]
        my define set ofile $ofile
      }
      lappend result $ofile [list cfile $filename include [my define get include]  extra [my define get extra] external [string is true -strict [my define get external]] object [self]]
    }
    }
    foreach item [my link list subordinate] {
      lappend result {*}[$item project-compile-products]
    }
    return $result
  }

  method generate-debug {{spaces {}}} {
    set result {}
    ::practcl::cputs result "$spaces[list [self] [list class [info object class [self]] filename [my define get filename]] links [my link list]]"
    foreach item [my link list subordinate] {
      practcl::cputs result [$item generate-debug "$spaces  "]
    }
    return $result
  }

  method generate-cfile-constant {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set result {}
    my variable code cstruct methods tcltype
    if {[info exists code(constant)]} {
      ::practcl::cputs result "/* [my define get filename] CONSTANT */"
      ::practcl::cputs result $code(constant)
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      ::practcl::cputs result [$obj generate-cfile-constant]
    }
    return $result
  }

  ###
  # Populate const static data structures
  ###
  method generate-cfile-public-structure {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cstruct methods tcltype
    set result {}
    if {[info exists code(struct)]} {
      ::practcl::cputs result $code(struct)
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      ::practcl::cputs result [$obj generate-cfile-public-structure]
    }
    return $result
  }

  method generate-cfile-header {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cfunct cstruct methods tcltype tclprocs
    set result {}
    if {[info exists code(header)]} {
      ::practcl::cputs result $code(header)
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      set dat [$obj generate-cfile-header]
      if {[string length [string trim $dat]]} {
        ::practcl::cputs result "/* BEGIN [$obj define get filename] generate-cfile-header */"
        ::practcl::cputs result $dat
        ::practcl::cputs result "/* END [$obj define get filename] generate-cfile-header */"
      }
    }
    return $result
  }

  method generate-cfile-global {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cfunct cstruct methods tcltype tclprocs
    set result {}
    if {[info exists code(global)]} {
      ::practcl::cputs result $code(global)
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      set dat [$obj generate-cfile-global]
      if {[string length [string trim $dat]]} {
        ::practcl::cputs result "/* BEGIN [$obj define get filename] generate-cfile-global */"
        ::practcl::cputs result $dat
        ::practcl::cputs result "/* END [$obj define get filename] generate-cfile-global */"
      }
    }
    return $result
  }

  method generate-cfile-private-typedef {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cstruct
    set result {}
    if {[info exists code(private-typedef)]} {
      ::practcl::cputs result $code(private-typedef)
    }
    if {[info exists cstruct]} {
      # Add defintion for native c data structures
      foreach {name info} $cstruct {
        if {[dict get $info public]==1} continue
        ::practcl::cputs result "typedef struct $name ${name}\;"
        if {[dict exists $info aliases]} {
          foreach n [dict get $info aliases] {
            ::practcl::cputs result "typedef struct $name ${n}\;"
          }
        }
      }
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-cfile-private-typedef]
    }
    return $result
  }

  method generate-cfile-private-structure {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cstruct
    set result {}
    if {[info exists code(private-structure)]} {
      ::practcl::cputs result $code(private-structure)
    }
    if {[info exists cstruct]} {
      foreach {name info} $cstruct {
        if {[dict get $info public]==1} continue
        if {[dict exists $info comment]} {
          ::practcl::cputs result [dict get $info comment]
        }
        ::practcl::cputs result "struct $name \{[dict get $info body]\}\;"
      }
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-cfile-private-structure]
    }
    return $result
  }


  ###
  # Generate code that provides subroutines called by
  # Tcl API methods
  ###
  method generate-cfile-functions {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cfunct
    set result {}
    if {[info exists code(funct)]} {
      ::practcl::cputs result $code(funct)
    }
    if {[info exists cfunct]} {
      foreach {funcname info} $cfunct {
        ::practcl::cputs result "/* $funcname */"
        if {[dict get $info inline] && [dict get $info public]} {
          ::practcl::cputs result "\ninline [dict get $info header]\{[dict get $info body]\}"
        } else {
          ::practcl::cputs result "\n[dict get $info header]\{[dict get $info body]\}"
        }
      }
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} {
        continue
      }
      ::practcl::cputs result [$obj generate-cfile-functions]
    }
    return $result
  }

  ###
  # Generate code that provides implements Tcl API
  # calls
  ###
  method generate-cfile-tclapi {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code methods tclprocs
    set result {}
    if {[info exists code(method)]} {
      ::practcl::cputs result $code(method)
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      ::practcl::cputs result [$obj generate-cfile-tclapi]
    }
    return $result
  }


  method generate-hfile-public-define {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code
    set result {}
    if {[info exists code(public-define)]} {
      ::practcl::cputs result $code(public-define)
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-hfile-public-define]
    }
    return $result
  }

  method generate-hfile-public-macro {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code
    set result {}
    if {[info exists code(public-macro)]} {
      ::practcl::cputs result $code(public-macro)
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-hfile-public-macro]
    }
    return $result
  }

  method generate-hfile-public-typedef {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cstruct
    set result {}
    if {[info exists code(public-typedef)]} {
      ::practcl::cputs result $code(public-typedef)
    }
    if {[info exists cstruct]} {
      # Add defintion for native c data structures
      foreach {name info} $cstruct {
        if {[dict get $info public]==0} continue
        ::practcl::cputs result "typedef struct $name ${name}\;"
        if {[dict exists $info aliases]} {
          foreach n [dict get $info aliases] {
            ::practcl::cputs result "typedef struct $name ${n}\;"
          }
        }
      }
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-hfile-public-typedef]
    }
    return $result
  }

  method generate-hfile-public-structure {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cstruct
    set result {}
    if {[info exists code(public-structure)]} {
      ::practcl::cputs result $code(public-structure)
    }
    if {[info exists cstruct]} {
      foreach {name info} $cstruct {
        if {[dict get $info public]==0} continue
        if {[dict exists $info comment]} {
          ::practcl::cputs result [dict get $info comment]
        }
        ::practcl::cputs result "struct $name \{[dict get $info body]\}\;"
      }
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-hfile-public-structure]
    }
    return $result
  }

  method generate-hfile-public-headers {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code tcltype
    set result {}
    if {[info exists code(public-header)]} {
      ::practcl::cputs result $code(public-header)
    }
    if {[info exists tcltype]} {
      foreach {type info} $tcltype {
        if {![dict exists $info cname]} {
          set cname [string tolower ${type}]_tclobjtype
          dict set tcltype $type cname $cname
        } else {
          set cname [dict get $info cname]
        }
        ::practcl::cputs result "extern const Tcl_ObjType $cname\;"
      }
    }
    if {[info exists code(public)]} {
      ::practcl::cputs result $code(public)
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-hfile-public-headers]
    }
    return $result
  }

  method generate-hfile-public-function {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cfunct tcltype
    set result {}

    if {[my define get initfunc] ne {}} {
      ::practcl::cputs result "int [my define get initfunc](Tcl_Interp *interp);"
    }
    if {[info exists cfunct]} {
      foreach {funcname info} $cfunct {
        if {![dict get $info public]} continue
        ::practcl::cputs result "[dict get $info header]\;"
      }
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-hfile-public-function]
    }
    return $result
  }

  method generate-hfile-public-includes {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set includes {}
    foreach item [my define get public-include] {
      if {$item ni $includes} {
        lappend includes $item
      }
    }
    foreach mod [my link list product] {
      foreach item [$mod generate-hfile-public-includes] {
        if {$item ni $includes} {
          lappend includes $item
        }
      }
    }
    return $includes
  }

  method generate-hfile-public-verbatim {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set includes {}
    foreach item [my define get public-verbatim] {
      if {$item ni $includes} {
        lappend includes $item
      }
    }
    foreach mod [my link list subordinate] {
      foreach item [$mod generate-hfile-public-verbatim] {
        if {$item ni $includes} {
          lappend includes $item
        }
      }
    }
    return $includes
  }

  method generate-loader-external {} {
    if {[my define get initfunc] eq {}} {
      return "/*  [my define get filename] declared not initfunc */"
    }
    return "  if([my define get initfunc](interp)) return TCL_ERROR\;"
  }

  method generate-loader-module {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code
    set result {}
    if {[info exists code(cinit)]} {
      ::practcl::cputs result $code(cinit)
    }
    if {[my define get initfunc] ne {}} {
      ::practcl::cputs result "  if([my define get initfunc](interp)!=TCL_OK) return TCL_ERROR\;"
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach item [my link list product] {
      if {[$item define get output_c] ne {}} {
        ::practcl::cputs result [$item generate-loader-external]
      } else {
        ::practcl::cputs result [$item generate-loader-module]
      }
    }
    return $result
  }

  method generate-stub-function {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    my variable code cfunct tcltype
    set result {}
    foreach mod [my link list product] {
      foreach {funct def} [$mod generate-stub-function] {
        dict set result $funct $def
      }
    }
    if {[info exists cfunct]} {
      foreach {funcname info} $cfunct {
        if {![dict get $info export]} continue
        dict set result $funcname [dict get $info header]
      }
    }
    return $result
  }


  method IncludeAdd {headervar args} {
    upvar 1 $headervar headers
    foreach inc $args {
      if {[string index $inc 0] ni {< \"}} {
        set inc "\"$inc\""
      }
      if {$inc ni $headers} {
        lappend headers $inc
      }
    }
  }

  method generate-tcl-loader {} {
    set result {}
    set PKGINIT [my define get pkginit]
    set PKG_NAME [my define get name [my define get pkg_name]]
    set PKG_VERSION [my define get pkg_vers [my define get version]]
    if {[string is true [my define get SHARED_BUILD 0]]} {
      set LIBFILE [my define get libfile]
      ::practcl::cputs result [string map \
        [list @LIBFILE@ $LIBFILE @PKGINIT@ $PKGINIT @PKG_NAME@ $PKG_NAME @PKG_VERSION@ $PKG_VERSION] {
# Shared Library Style
load [file join [file dirname [file join [pwd] [info script]]] @LIBFILE@] @PKGINIT@
package provide @PKG_NAME@ @PKG_VERSION@
}]
    } else {
      ::practcl::cputs result [string map \
      [list @PKGINIT@ $PKGINIT @PKG_NAME@ $PKG_NAME @PKG_VERSION@ $PKG_VERSION] {
# Tclkit Style
load {} @PKGINIT@
package provide @PKG_NAME@ @PKG_VERSION@
}]
    }
    return $result
  }

  ###
  # This methods generates any Tcl script file
  # which is required to pre-initialize the C library
  ###
  method generate-tcl-pre {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set result {}
    my variable code
    if {[info exists code(tcl)]} {
      set result [::practcl::_tagblock $code(tcl) tcl [my define get filename]]
    }
    if {[info exists code(tcl-pre)]} {
      set result [::practcl::_tagblock $code(tcl) tcl [my define get filename]]
    }
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-tcl-pre]
    }
    return $result
  }

  method generate-tcl-post {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set result {}
    my variable code
    if {[info exists code(tcl-post)]} {
      set result [::practcl::_tagblock $code(tcl-post) tcl [my define get filename]]
    }
    foreach mod [my link list product] {
      ::practcl::cputs result [$mod generate-tcl-post]
    }
    return $result
  }


  method linktype {} {
    return {subordinate product}
  }

  method Ofile filename {
    set lpath [my <module> define get localpath]
    if {$lpath eq {}} {
      set lpath [my <module> define get name]
    }
    return ${lpath}_[file rootname [file tail $filename]]
  }

  ###
  # Methods called by the master project
  ###

  method project-static-packages {} {
    set result [my define get static_packages]
    set initfunc [my define get initfunc]
    if {$initfunc ne {}} {
      set pkg_name [my define get pkg_name]
      if {$pkg_name ne {}} {
        dict set result $pkg_name initfunc $initfunc
        dict set result $pkg_name version [my define get version [my define get pkg_vers]]
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

  ###
  # Methods called by the toolset
  ###

  method toolset-include-directory {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set result [my define get include_dir]
    foreach obj [my link list product] {
      foreach path [$obj toolset-include-directory] {
        lappend result $path
      }
    }
    return $result
  }

  method target {method args} {
    switch $method {
      is_unix { return [expr {$::tcl_platform(platform) eq "unix"}] }
    }
  }
}
oo::objdefine ::practcl::product {

  method select {object} {
    set class [$object define get class]
    set mixin [$object define get product]
    if {$class eq {} && $mixin eq {}} {
      set filename [$object define get filename]
      if {$filename ne {} && [file exists $filename]} {
        switch [file extension $filename] {
          .tcl {
            set mixin ::practcl::product.dynamic
          }
          .h {
            set mixin ::practcl::product.cheader
          }
          .c {
            set mixin ::practcl::product.csource
          }
          .ini {
            switch [file tail $filename] {
              module.ini {
                set class ::practcl::module
              }
              library.ini {
                set class ::practcl::subproject
              }
            }
          }
          .so -
          .dll -
          .dylib -
          .a {
            set mixin ::practcl::product.clibrary
          }
        }
      }
    }
    if {$class ne {}} {
      $object clay mixinmap core $class
    }
    if {$mixin ne {}} {
      $object clay mixinmap product $mixin
    }
  }
}

###
# A product which generated from a C header file. Which is to say, nothing.
###
::clay::define ::practcl::product.cheader {
  superclass ::practcl::product

  method project-compile-products {} {}
  method generate-loader-module {} {}
}

###
# A product which generated from a C source file. Normally an object (.o) file.
###
::clay::define ::practcl::product.csource {
  superclass ::practcl::product

  method project-compile-products {} {
    set result {}
    set filename [my define get filename]
    if {$filename ne {}} {
      ::practcl::debug [self] [self class] [self method] project-compile-products $filename
      if {[my define exists ofile]} {
        set ofile [my define get ofile]
      } else {
        set ofile [my Ofile $filename]
        my define set ofile $ofile
      }
      lappend result $ofile [list cfile $filename extra [my define get extra] external [string is true -strict [my define get external]] object [self]]
    }
    foreach item [my link list subordinate] {
      lappend result {*}[$item project-compile-products]
    }
    return $result
  }
}

###
# A product which is generated from a compiled C library.
# Usually a .a or a .dylib file, but in complex cases may
# actually just be a conduit for one project to integrate the
# source code of another
###
::clay::define ::practcl::product.clibrary {
  superclass ::practcl::product

  method linker-products {configdict} {
    return [my define get filename]
  }

}

###
# A product which is generated from C code that itself is generated
# by practcl or some other means. This C file may or may not produce
# its own .o file, depending on whether it is eligible to become part
# of an amalgamation
###
::clay::define ::practcl::product.dynamic {
  superclass ::practcl::dynamic ::practcl::product

  method initialize {} {
    set filename [my define get filename]
    if {$filename eq {}} {
      return
    }
    if {[my define get name] eq {}} {
      my define set name [file tail [file rootname $filename]]
    }
    if {[my define get localpath] eq {}} {
      my define set localpath [my <module> define get localpath]_[my define get name]
    }
    # Future Development:
    # Scan source file to see if it is encoded in criticl or practcl notation
    #set thisline {}
    #foreach line [split [::practcl::cat $filename] \n] {
    #
    #}
    ::source $filename
    if {[my define get output_c] ne {}} {
      # Turn into a module if we have an output_c file
      my morph ::practcl::module
    }
  }
}

###
# A binary product produced by critcl. Note: The implementation is not
# written yet, this class does nothing.
::clay::define ::practcl::product.critcl {
  superclass ::practcl::dynamic ::practcl::product
}

