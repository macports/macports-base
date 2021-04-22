
###
# Dynamic blocks do not generate their own .c files,
# instead the contribute to the amalgamation
# of the main library file
###
::clay::define ::practcl::dynamic {

  ###
  # Parser functions
  ###

  method cstructure {name definition {argdat {}}} {
    my variable cstruct
    dict set cstruct $name body $definition
    foreach {f v} $argdat {
      dict set cstruct $name $f $v
    }
    if {![dict exists $cstruct $name public]} {
      dict set cstruct $name public 1
    }
  }

  method include header {
    my define add include $header
  }

  method include_dir args {
    my define add include_dir {*}$args
  }

  method include_directory args {
    my define add include_dir {*}$args
  }

  method c_header body {
    my variable code
    ::practcl::cputs code(header) $body
  }

  method c_code body {
    my variable code
    ::practcl::cputs code(funct) $body
  }

  method c_function {header body {info {}}} {
    set header [string map "\t \  \n \ \ \  \ " $header]
    my variable code cfunct
    foreach regexp {
         {(.*) ([a-zA-Z_][a-zA-Z0-9_]*) *\((.*)\)}
         {(.*) (\x2a[a-zA-Z_][a-zA-Z0-9_]*) *\((.*)\)}
    } {
      if {[regexp $regexp $header all keywords funcname arglist]} {
        set dat [dict merge {export 0 extern 0 public 1 inline 0} $info]
        dict set dat header $header
        dict set dat body $body
        dict set dat keywords $keywords
        dict set dat arglist $arglist
        if {"IRM_INLINE" in $keywords || "CTHULHU_INLINE" in $keywords} {
          dict set dat public 1
          dict set dat extern 0
          dict set dat inline 1
        } else {
          if {"inline" in $keywords} {
            dict set dat inline 1
          }
          if {"STUB_EXPORT" in $keywords} {
            dict set dat extern 1
            dict set dat public 1
            dict set dat export 1
            dict set dat inline 0
          } elseif {"extern" in $keywords} {
            dict set dat extern 1
            dict set dat public 1
          } elseif {"static" in $keywords} {
            dict set dat public 0
          }
        }
        if {[dict get $dat inline] && [dict get $dat public]} {
          set header [string map {IRM_INLINE {} CTHULHU_INLINE {} static {} inline {} extern {}} [dict get $dat header]]
          dict set dat header "extern $header"
        }
        dict set cfunct $funcname $dat
        return
      }
    }
    puts "WARNING: NON CONFORMING FUNCTION DEFINITION: $headers $body"
    ::practcl::cputs code(header) "$header\;"
    # Could not parse that block as a function
    # append it verbatim to our c_implementation
    ::practcl::cputs code(funct) "$header [list $body]"
  }

  method c_tcloomethod {name body {arginfo {}}} {
    my variable methods code
    foreach {f v} $arginfo {
      dict set methods $name $f $v
    }
    dict set methods $name body "Tcl_Object thisObject = Tcl_ObjectContextObject(objectContext); /* The current connection object */
$body"
  }

  # Alias to classic name
  method cmethod {name body {arginfo {}}} {
    my variable methods code
    foreach {f v} $arginfo {
      dict set methods $name $f $v
    }
    dict set methods $name body "Tcl_Object thisObject = Tcl_ObjectContextObject(objectContext); /* The current connection object */
$body"
  }

  method c_tclproc_nspace nspace {
    my variable code
    if {![info exists code(nspace)]} {
      set code(nspace) {}
    }
    if {$nspace ni $code(nspace)} {
      lappend code(nspace) $nspace
    }
  }

  method c_tclcmd {name body {arginfo {}}} {
    my variable tclprocs code

    foreach {f v} $arginfo {
      dict set tclprocs $name $f $v
    }
    dict set tclprocs $name body $body
  }

  # Alias to classic name
  method c_tclproc_raw {name body {arginfo {}}} {
    my variable tclprocs code

    foreach {f v} $arginfo {
      dict set tclprocs $name $f $v
    }
    dict set tclprocs $name body $body
  }

  method tcltype {name argdat} {
    my variable tcltype
    foreach {f v} $argdat {
      dict set tcltype $name $f $v
    }
    if {![dict exists tcltype $name cname]} {
      dict set tcltype $name cname [string tolower $name]_tclobjtype
    }
    lappend map @NAME@ $name
    set info [dict get $tcltype $name]
    foreach {f v} $info {
      lappend map @[string toupper $f]@ $v
    }
    foreach {func fpat template} {
      freeproc         {@Name@Obj_freeIntRepProc}       {void @FNAME@(Tcl_Obj *objPtr)}
      dupproc          {@Name@Obj_dupIntRepProc}        {void @FNAME@(Tcl_Obj *srcPtr,Tcl_Obj *dupPtr)}
      updatestringproc {@Name@Obj_updateStringRepProc} {void @FNAME@(Tcl_Obj *objPtr)}
      setfromanyproc   {@Name@Obj_setFromAnyProc}       {int @FNAME@(Tcl_Interp *interp,Tcl_Obj *objPtr)}
    } {
      if {![dict exists $info $func]} {
        error "$name does not define $func"
      }
      set body [dict get $info $func]
      # We were given a function name to call
      if {[llength $body] eq 1} continue
      set fname [string map [list @Name@ [string totitle $name]] $fpat]
      my c_function [string map [list @FNAME@ $fname] $template] [string map $map $body]
      dict set tcltype $name $func $fname
    }
  }

  ###
  # Module interactions
  ###
  method project-compile-products {} {
    set filename [my define get output_c]
    set result {}
    if {$filename ne {}} {
      ::practcl::debug [self] [self class] [self method] project-compile-products $filename

      if {[my define exists ofile]} {
        set ofile [my define get ofile]
      } else {
        set ofile [my Ofile $filename]
        my define set ofile $ofile
      }
      lappend result $ofile [list cfile $filename extra [my define get extra] external [string is true -strict [my define get external]]]
    } else {
      set filename [my define get cfile]
      if {$filename ne {}} {
        ::practcl::debug [self] [self class] [self method] project-compile-products $filename
        if {[my define exists ofile]} {
          set ofile [my define get ofile]
        } else {
          set ofile [my Ofile $filename]
          my define set ofile $ofile
        }
        lappend result $ofile [list cfile $filename extra [my define get extra] external [string is true -strict [my define get external]]]
      }
    }
    foreach item [my link list subordinate] {
      lappend result {*}[$item project-compile-products]
    }
    return $result
  }

  method implement path {
    my go
    my Collate_Source $path
    if {[my define get output_c] eq {}} return
    set filename [file join $path [my define get output_c]]
    ::practcl::debug [self] [my define get filename] WANTS TO GENERATE $filename
    my define set cfile $filename
    set fout [open $filename w]
    puts $fout [my generate-c]
    if {[my define get initfunc] ne {}} {
      puts $fout "extern int DLLEXPORT [my define get initfunc]( Tcl_Interp *interp ) \x7B"
      puts $fout [my generate-loader-module]
      if {[my define get pkg_name] ne {}} {
        puts $fout "   Tcl_PkgProvide(interp, \"[my define get pkg_name]\", \"[my define get pkg_vers]\");"
      }
      puts $fout "  return TCL_OK\;"
      puts $fout "\x7D"
    }
    close $fout
  }

  ###
  # Practcl internals
  ###
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
    ::source $filename
  }

  method linktype {} {
    return {subordinate product dynamic}
  }

  method generate-cfile-constant {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set result {}
    my variable code cstruct methods tcltype
    if {[info exists code(constant)]} {
      ::practcl::cputs result "/* [my define get filename] CONSTANT */"
      ::practcl::cputs result $code(constant)
    }
    if {[info exists cstruct]} {
      foreach {name info} $cstruct {
        set map {}
        lappend map @NAME@ $name
        lappend map @MACRO@ GET[string toupper $name]

        if {[dict exists $info deleteproc]} {
          lappend map @DELETEPROC@ [dict get $info deleteproc]
        } else {
          lappend map @DELETEPROC@ NULL
        }
        if {[dict exists $info cloneproc]} {
          lappend map @CLONEPROC@ [dict get $info cloneproc]
        } else {
          lappend map @CLONEPROC@ NULL
        }
        ::practcl::cputs result [string map $map {
const static Tcl_ObjectMetadataType @NAME@DataType = {
  TCL_OO_METADATA_VERSION_CURRENT,
  "@NAME@",
  @DELETEPROC@,
  @CLONEPROC@
};
#define @MACRO@(OBJCONTEXT) (@NAME@ *) Tcl_ObjectGetMetadata(OBJCONTEXT,&@NAME@DataType)
}]
      }
    }
    if {[info exists tcltype]} {
      foreach {type info} $tcltype {
        dict with info {}
        ::practcl::cputs result "const Tcl_ObjType $cname = \{\n .name=\"$type\",\n .freeIntRepProc = &${freeproc},\n  .dupIntRepProc = &${dupproc},\n  .updateStringProc = &${updatestringproc},\n  .setFromAnyProc = &${setfromanyproc}\n\}\;"
      }
    }

    if {[info exists methods]} {
      set mtypes {}
      foreach {name info} $methods {
        set callproc   [dict get $info callproc]
        set methodtype [dict get $info methodtype]
        if {$methodtype in $mtypes} continue
        lappend mtypes $methodtype
        ###
        # Build the data struct for this method
        ###
        ::practcl::cputs result "const static Tcl_MethodType $methodtype = \{"
        ::practcl::cputs result "  .version = TCL_OO_METADATA_VERSION_CURRENT,\n  .name = \"$name\",\n  .callProc = $callproc,"
        if {[dict exists $info deleteproc]} {
          set deleteproc [dict get $info deleteproc]
        } else {
          set deleteproc NULL
        }
        if {$deleteproc ni { {} NULL }} {
          ::practcl::cputs result "  .deleteProc = $deleteproc,"
        } else {
          ::practcl::cputs result "  .deleteProc = NULL,"
        }
        if {[dict exists $info cloneproc]} {
          set cloneproc [dict get $info cloneproc]
        } else {
          set cloneproc NULL
        }
        if {$cloneproc ni { {} NULL }} {
          ::practcl::cputs result "  .cloneProc = $cloneproc\n\}\;"
        } else {
          ::practcl::cputs result "  .cloneProc = NULL\n\}\;"
        }
        dict set methods $name methodtype $methodtype
      }
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      ::practcl::cputs result [$obj generate-cfile-constant]
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
    ::practcl::debug [list cfunct [info exists cfunct]]
    if {[info exists cfunct]} {
      foreach {funcname info} $cfunct {
        if {[dict get $info public]} continue
        ::practcl::cputs result "[dict get $info header]\;"
      }
    }
    ::practcl::debug [list tclprocs [info exists tclprocs]]
    if {[info exists tclprocs]} {
      foreach {name info} $tclprocs {
        if {[dict exists $info header]} {
          ::practcl::cputs result "[dict get $info header]\;"
        }
      }
    }
    ::practcl::debug [list methods [info exists methods] [my define get cclass]]
    if {[info exists methods]} {
      set thisclass [my define get cclass]
      foreach {name info} $methods {
        if {[dict exists $info header]} {
          ::practcl::cputs result "[dict get $info header]\;"
        }
      }
      # Add the initializer wrapper for the class
      ::practcl::cputs result "static int ${thisclass}_OO_Init(Tcl_Interp *interp)\;"
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

    if {[info exists tclprocs]} {
      foreach {name info} $tclprocs {
        if {![dict exists $info body]} continue
        set callproc [dict get $info callproc]
        set header [dict get $info header]
        set body [dict get $info body]
        ::practcl::cputs result "/* Tcl Proc $name */"
        ::practcl::cputs result "${header} \{${body}\}"
      }
    }


    if {[info exists methods]} {
      set thisclass [my define get cclass]
      foreach {name info} $methods {
        if {![dict exists $info body]} continue
        set callproc [dict get $info callproc]
        set header [dict get $info header]
        set body [dict get $info body]
        ::practcl::cputs result "/* OO Method $thisclass $name */"
        ::practcl::cputs result "${header} \{${body}\}"
      }
      # Build the OO_Init function
      ::practcl::cputs result "/* Loader for $thisclass */"
      ::practcl::cputs result "static int ${thisclass}_OO_Init(Tcl_Interp *interp) \{"
      ::practcl::cputs result [string map [list @CCLASS@ $thisclass @TCLCLASS@ [my define get class]] {
  /*
  ** Build the "@TCLCLASS@" class
  */
  Tcl_Obj* nameObj;		/* Name of a class or method being looked up */
  Tcl_Object curClassObject;  /* Tcl_Object representing the current class */
  Tcl_Class curClass;		/* Tcl_Class representing the current class */

  /*
   * Find the "@TCLCLASS@" class, and attach an 'init' method to it.
   */

  nameObj = Tcl_NewStringObj("@TCLCLASS@", -1);
  Tcl_IncrRefCount(nameObj);
  if ((curClassObject = Tcl_GetObjectFromObj(interp, nameObj)) == NULL) {
      Tcl_DecrRefCount(nameObj);
      return TCL_ERROR;
  }
  Tcl_DecrRefCount(nameObj);
  curClass = Tcl_GetObjectAsClass(curClassObject);
}]
      if {[dict exists $methods constructor]} {
        set mtype [dict get $methods constructor methodtype]
        ::practcl::cputs result [string map [list @MTYPE@ $mtype] {
  /* Attach the constructor to the class */
  Tcl_ClassSetConstructor(interp, curClass, Tcl_NewMethod(interp, curClass, NULL, 1, &@MTYPE@, NULL));
    }]
      }
      foreach {name info} $methods {
        dict with info {}
        if {$name in {constructor destructor}} continue
        ::practcl::cputs result [string map [list @NAME@ $name @MTYPE@ $methodtype] {
  nameObj=Tcl_NewStringObj("@NAME@",-1);
  Tcl_NewMethod(interp, curClass, nameObj, 1, &@MTYPE@, (ClientData) NULL);
  Tcl_DecrRefCount(nameObj);
}]
        if {[dict exists $info aliases]} {
          foreach alias [dict get $info aliases] {
            if {[dict exists $methods $alias]} continue
            ::practcl::cputs result [string map [list @NAME@ $alias @MTYPE@ $methodtype] {
  nameObj=Tcl_NewStringObj("@NAME@",-1);
  Tcl_NewMethod(interp, curClass, nameObj, 1, &@MTYPE@, (ClientData) NULL);
  Tcl_DecrRefCount(nameObj);
}]
          }
        }
      }
      ::practcl::cputs result "  return TCL_OK\;\n\}\n"
    }
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} continue
      ::practcl::cputs result [$obj generate-cfile-tclapi]
    }
    return $result
  }

  ###
  # Generate code that runs when the package/module is
  # initialized into the interpreter
  ###
  method generate-loader-module {} {
    ::practcl::debug [list [self] [self method] [self class] -- [my define get filename] [info object class [self]]]
    set result {}
    my variable code methods tclprocs
    if {[info exists code(nspace)]} {
      ::practcl::cputs result "  \{\n    Tcl_Namespace *modPtr;"
      foreach nspace $code(nspace) {
        ::practcl::cputs result [string map [list @NSPACE@ $nspace] {
    modPtr=Tcl_FindNamespace(interp,"@NSPACE@",NULL,TCL_NAMESPACE_ONLY);
    if(!modPtr) {
      modPtr = Tcl_CreateNamespace(interp, "@NSPACE@", NULL, NULL);
    }
}]
      }
      ::practcl::cputs result "  \}"
    }
    if {[info exists code(tclinit)]} {
      ::practcl::cputs result $code(tclinit)
    }
    if {[info exists code(cinit)]} {
      ::practcl::cputs result $code(cinit)
    }
    if {[info exists code(initfuncts)]} {
      foreach func $code(initfuncts) {
        ::practcl::cputs result "  if (${func}(interp) != TCL_OK) return TCL_ERROR\;"
      }
    }
    if {[info exists tclprocs]} {
      foreach {name info} $tclprocs {
        set map [list @NAME@ $name @CALLPROC@ [dict get $info callproc]]
        ::practcl::cputs result [string map $map {  Tcl_CreateObjCommand(interp,"@NAME@",(Tcl_ObjCmdProc *)@CALLPROC@,NULL,NULL);}]
        if {[dict exists $info aliases]} {
          foreach alias [dict get $info aliases] {
            set map [list @NAME@ $alias @CALLPROC@ [dict get $info callproc]]
            ::practcl::cputs result [string map $map {  Tcl_CreateObjCommand(interp,"@NAME@",(Tcl_ObjCmdProc *)@CALLPROC@,NULL,NULL);}]
          }
        }
      }
    }

    if {[info exists code(nspace)]} {
      ::practcl::cputs result "  \{\n    Tcl_Namespace *modPtr;"
      foreach nspace $code(nspace) {
        ::practcl::cputs result [string map [list @NSPACE@ $nspace] {
    modPtr=Tcl_FindNamespace(interp,"@NSPACE@",NULL,TCL_NAMESPACE_ONLY);
    Tcl_CreateEnsemble(interp, modPtr->fullName, modPtr, TCL_ENSEMBLE_PREFIX);
    Tcl_Export(interp, modPtr, "[a-z]*", 1);
}]
      }
      ::practcl::cputs result "  \}"
    }
    set result [::practcl::_tagblock $result c [my define get filename]]
    foreach obj [my link list product] {
      # Exclude products that will generate their own C files
      if {[$obj define get output_c] ne {}} {
        ::practcl::cputs result [$obj generate-loader-external]
      } else {
        ::practcl::cputs result [$obj generate-loader-module]
      }
    }
    return $result
  }

  method Collate_Source CWD {
    my variable methods code cstruct tclprocs
    if {[info exists methods]} {
      ::practcl::debug [self] methods [my define get cclass]
      set thisclass [my define get cclass]
      foreach {name info} $methods {
        # Provide a callproc
        if {![dict exists $info callproc]} {
          set callproc [string map {____ _ ___ _ __ _} [string map {{ } _ : _} OOMethod_${thisclass}_${name}]]
          dict set methods $name callproc $callproc
        } else {
          set callproc [dict get $info callproc]
        }
        if {[dict exists $info body] && ![dict exists $info header]} {
          dict set methods $name header "static int ${callproc}(ClientData clientData, Tcl_Interp *interp, Tcl_ObjectContext objectContext ,int objc ,Tcl_Obj *const *objv)"
        }
        if {![dict exists $info methodtype]} {
          set methodtype [string map {{ } _ : _} OOMethodType_${thisclass}_${name}]
          dict set methods $name methodtype $methodtype
        }
      }
      if {![info exists code(initfuncts)] || "${thisclass}_OO_Init" ni $code(initfuncts)} {
        lappend code(initfuncts) "${thisclass}_OO_Init"
      }
    }
    set thisnspace [my define get nspace]

    if {[info exists tclprocs]} {
      ::practcl::debug [self] tclprocs [dict keys $tclprocs]
      foreach {name info} $tclprocs {
        if {![dict exists $info callproc]} {
          set callproc [string map {____ _ ___ _ __ _} [string map {{ } _ : _} TclCmd_${thisnspace}_${name}]]
          dict set tclprocs $name callproc $callproc
        } else {
          set callproc [dict get $info callproc]
        }
        if {[dict exists $info body] && ![dict exists $info header]} {
          dict set tclprocs $name header "static int ${callproc}(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv\[\])"
        }
      }
    }
  }

  # Once an object marks itself as some
  # flavor of dynamic, stop trying to morph
  # it into something else
  method select {} {}

}


