###
# clay.tcl
#
# Copyright (c) 2018 Sean Woods
#
# BSD License
###
# @@ Meta Begin
# Package clay 0.8.6
# Meta platform     tcl
# Meta summary      A minimalist framework for complex TclOO development
# Meta description  This package introduces the method "clay" to both oo::object
# Meta description  and oo::class which facilitate complex interactions between objects
# Meta description  and their ancestor and mixed in classes.
# Meta category     TclOO
# Meta subject      framework
# Meta require      {Tcl 8.6}
# Meta author       Sean Woods
# Meta license      BSD
# @@ Meta End

###
# Amalgamated package for clay
# Do not edit directly, tweak the source in build/ and rerun
# build.tcl
###
package provide clay 0.8.6
namespace eval ::clay {}

###
# START: procs.tcl
###
namespace eval ::clay {
}
set ::clay::trace 0
if {[info commands ::cron::object_destroy] eq {}} {
  # Provide a noop if we aren't running with the cron scheduler
  namespace eval ::cron {}
  proc ::cron::object_destroy args {}
}
proc ::clay::PROC {name arglist body {ninja {}}} {
  if {[info commands $name] ne {}} return
  proc $name $arglist $body
  eval $ninja
}
if {[info commands ::PROC] eq {}} {
  namespace eval ::clay { namespace export PROC }
  namespace eval :: { namespace import ::clay::PROC }
}
proc ::clay::_ancestors {resultvar class} {
  upvar 1 $resultvar result
  if {$class in $result} {
    return
  }
  lappend result $class
  foreach aclass [::info class superclasses $class] {
    _ancestors result $aclass
  }
}
proc ::clay::ancestors {args} {
  set result {}
  set queue  {}
  set metaclasses {}

  foreach class $args {
    set ancestors($class) {}
    _ancestors ancestors($class) $class
  }
  foreach class [lreverse $args] {
    foreach aclass $ancestors($class) {
      if {$aclass in $result} continue
      set skip 0
      foreach bclass $args {
        if {$class eq $bclass} continue
        if {$aclass in $ancestors($bclass)} {
          set skip 1
          break
        }
      }
      if {$skip} continue
      lappend result $aclass
    }
  }
  foreach class [lreverse $args] {
    foreach aclass $ancestors($class) {
      if {$aclass in $result} continue
      lappend result $aclass
    }
  }
  ###
  # Screen out classes that do not participate in clay
  # interactions
  ###
  set output {}
  foreach {item} $result {
    if {[catch {$item clay noop} err]} {
      continue
    }
    lappend output $item
  }
  return $output
}
proc ::clay::args_to_dict args {
  if {[llength $args]==1} {
    return [lindex $args 0]
  }
  return $args
}
proc ::clay::args_to_options args {
  set result {}
  foreach {var val} [args_to_dict {*}$args] {
    lappend result [string trim $var -:] $val
  }
  return $result
}
proc ::clay::dynamic_arguments {ensemble method arglist args} {
  set idx 0
  set len [llength $args]
  if {$len > [llength $arglist]} {
    ###
    # Catch if the user supplies too many arguments
    ###
    set dargs 0
    if {[lindex $arglist end] ni {args dictargs}} {
      return -code error -level 2 "Usage: $ensemble $method [string trim [dynamic_wrongargs_message $arglist]]"
    }
  }
  foreach argdef $arglist {
    if {$argdef eq "args"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      break
    }
    if {$argdef eq "dictargs"} {
      ###
      # Perform args processing in the style of tcl
      ###
      uplevel 1 [list set args [lrange $args $idx end]]
      ###
      # Perform args processing in the style of clay
      ###
      set dictargs [::clay::args_to_options {*}[lrange $args $idx end]]
      uplevel 1 [list set dictargs $dictargs]
      break
    }
    if {$idx > $len} {
      ###
      # Catch if the user supplies too few arguments
      ###
      if {[llength $argdef]==1} {
        return -code error -level 2 "Usage: $ensemble $method [string trim [dynamic_wrongargs_message $arglist]]"
      } else {
        uplevel 1 [list set [lindex $argdef 0] [lindex $argdef 1]]
      }
    } else {
      uplevel 1 [list set [lindex $argdef 0] [lindex $args $idx]]
    }
    incr idx
  }
}
proc ::clay::dynamic_wrongargs_message {arglist} {
  set result ""
  set dargs 0
  foreach argdef $arglist {
    if {$argdef in {args dictargs}} {
      set dargs 1
      break
    }
    if {[llength $argdef]==1} {
      append result " $argdef"
    } else {
      append result " ?[lindex $argdef 0]?"
    }
  }
  if { $dargs } {
    append result " ?option value?..."
  }
  return $result
}
proc ::clay::is_dict { d } {
  # is it a dict, or can it be treated like one?
  if {[catch {::dict size $d} err]} {
    #::set ::errorInfo {}
    return 0
  }
  return 1
}
proc ::clay::is_null value {
  return [expr {$value in {{} NULL}}]
}
proc ::clay::leaf args {
  set marker [string index [lindex $args end] end]
  set result [path {*}${args}]
  if {$marker eq "/"} {
    return $result
  }
  return [list {*}[lrange $result 0 end-1] [string trim [string trim [lindex $result end]] /]]
}
proc ::clay::K {a b} {set a}
if {[info commands ::K] eq {}} {
  namespace eval ::clay { namespace export K }
  namespace eval :: { namespace import ::clay::K }
}
proc ::clay::noop args {}
if {[info commands ::noop] eq {}} {
  namespace eval ::clay { namespace export noop }
  namespace eval :: { namespace import ::clay::noop }
}
proc ::clay::cleanup {} {
  set count 0
  if {![info exists ::clay::idle_destroy]} return
  set objlist $::clay::idle_destroy
  set ::clay::idle_destroy {}
  foreach obj $objlist {
    if {![catch {$obj destroy}]} {
      incr count
    }
  }
  return $count
}
proc ::clay::object_create {objname {class {}}} {
  #if {$::clay::trace>0} {
  #  puts [list $objname CREATE]
  #}
}
proc ::clay::object_rename {object newname} {
  if {$::clay::trace>0} {
    puts [list $object RENAME -> $newname]
  }
}
proc ::clay::object_destroy args {
  if {![info exists ::clay::idle_destroy]} {
    set ::clay::idle_destroy {}
  }
  foreach objname $args {
    if {$::clay::trace>0} {
      puts [list $objname DESTROY]
    }
    ::cron::object_destroy $objname
    if {$objname in $::clay::idle_destroy} continue
    lappend ::clay::idle_destroy $objname
  }
}
proc ::clay::path args {
  set result {}
  foreach item $args {
    set item [string trim $item :./]
    foreach subitem [split $item /] {
      lappend result [string trim ${subitem}]/
    }
  }
  return $result
}
proc ::clay::putb {buffername args} {
  upvar 1 $buffername buffer
  switch [llength $args] {
    1 {
      append buffer [lindex $args 0] \n
    }
    2 {
      append buffer [string map {*}$args] \n
    }
    default {
      error "usage: putb buffername ?map? string"
    }
  }
}
if {[info command ::putb] eq {}} {
  namespace eval ::clay { namespace export putb }
  namespace eval :: { namespace import ::clay::putb }
}
proc ::clay::script_path {} {
  set path [file dirname [file join [pwd] [info script]]]
  return $path
}
proc ::clay::NSNormalize qualname {
  if {![string match ::* $qualname]} {
    set qualname ::clay::classes::$qualname
  }
  regsub -all {::+} $qualname "::"
}
proc ::clay::uuid_generate args {
  return [uuid generate]
}
namespace eval ::clay {
  variable option_class {}
  variable core_classes {::oo::class ::oo::object}
}

###
# END: procs.tcl
###
###
# START: core.tcl
###
package require Tcl 8.6 ;# try in pipeline.tcl. Possibly other things.
if {[info commands irmmd5] eq {}} {
  if {[catch {package require odielibc}]} {
    package require md5 2
  }
}
::namespace eval ::clay {
}
::namespace eval ::clay::classes {
}
::namespace eval ::clay::define {
}
::namespace eval ::clay::tree {
}
::namespace eval ::clay::dict {
}
::namespace eval ::clay::list {
}
::namespace eval ::clay::uuid {
}
if {![info exists ::clay::idle_destroy]} {
  set ::clay::idle_destroy {}
}

###
# END: core.tcl
###
###
# START: uuid.tcl
###
namespace eval ::clay::uuid {
    namespace export uuid
}
proc ::clay::uuid::generate_tcl_machinfo {} {
  variable machinfo
  if {[info exists machinfo]} {
    return $machinfo
  }
  lappend machinfo [clock seconds]; # timestamp
  lappend machinfo [clock clicks];  # system incrementing counter
  lappend machinfo [info hostname]; # spatial unique id (poor)
  lappend machinfo [pid];           # additional entropy
  lappend machinfo [array get ::tcl_platform]

  ###
  # If we have /dev/urandom just stream 128 bits from that
  ###
  if {[file exists /dev/urandom]} {
    set fin [open /dev/urandom r]
    binary scan [read $fin 128] H* machinfo
    close $fin
  } elseif {[catch {package require nettool}]} {
    # More spatial information -- better than hostname.
    # bug 1150714: opening a server socket may raise a warning messagebox
    #   with WinXP firewall, using ipconfig will return all IP addresses
    #   including ipv6 ones if available. ipconfig is OK on win98+
    if {[string equal $::tcl_platform(platform) "windows"]} {
      catch {exec ipconfig} config
      lappend machinfo $config
    } else {
      catch {
          set s [socket -server void -myaddr [info hostname] 0]
          ::clay::K [fconfigure $s -sockname] [close $s]
      } r
      lappend machinfo $r
    }

    if {[package provide Tk] != {}} {
      lappend machinfo [winfo pointerxy .]
      lappend machinfo [winfo id .]
    }
  } else {
    ###
    # If the nettool package works on this platform
    # use the stream of hardware ids from it
    ###
    lappend machinfo {*}[::nettool::hwid_list]
  }
  return $machinfo
}
if {[info commands irmmd5] ne {}} {
proc ::clay::uuid::generate {{type {}}} {
    variable nextuuid
    set s [irmmd5 "$type [incr nextuuid(type)] [generate_tcl_machinfo]"]
    foreach {a b} {0 7 8 11 12 15 16 19 20 31} {
         append r [string range $s $a $b] -
     }
     return [string tolower [string trimright $r -]]
}
proc ::clay::uuid::short {{type {}}} {
  variable nextuuid
  set r [irmmd5 "$type [incr nextuuid(type)] [generate_tcl_machinfo]"]
  return [string range $r 0 16]
}

} else {
package require md5 2
proc ::clay::uuid::raw {{type {}}} {
    variable nextuuid
    set tok [md5::MD5Init]
    md5::MD5Update $tok "$type [incr nextuuid($type)] [generate_tcl_machinfo]"
    set r [md5::MD5Final $tok]
    return $r
    #return [::clay::uuid::tostring $r]
}
proc ::clay::uuid::generate {{type {}}} {
    return [::clay::uuid::tostring [::clay::uuid::raw  $type]]
}
proc ::clay::uuid::short {{type {}}} {
  set r [::clay::uuid::raw $type]
  binary scan $r H* s
  return [string range $s 0 16]
}
}
proc ::clay::uuid::tostring {uuid} {
    binary scan $uuid H* s
    foreach {a b} {0 7 8 11 12 15 16 19 20 31} {
        append r [string range $s $a $b] -
    }
    return [string tolower [string trimright $r -]]
}
proc ::clay::uuid::fromstring {uuid} {
    return [binary format H* [string map {- {}} $uuid]]
}
proc ::clay::uuid::equal {left right} {
    set l [fromstring $left]
    set r [fromstring $right]
    return [string equal $l $r]
}
proc ::clay::uuid {cmd args} {
    switch -exact -- $cmd {
        generate {
           return [::clay::uuid::generate {*}$args]
        }
        short {
          set uuid [::clay::uuid::short {*}$args]
        }
        equal {
            tailcall ::clay::uuid::equal {*}$args
        }
        default {
            return -code error "bad option \"$cmd\":\
                must be generate or equal"
        }
    }
}

###
# END: uuid.tcl
###
###
# START: dict.tcl
###
::clay::PROC ::tcl::dict::getnull {dictionary args} {
  if {[exists $dictionary {*}$args]} {
    get $dictionary {*}$args
  }
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] getnull ::tcl::dict::getnull]
}
::clay::PROC ::tcl::dict::is_dict { d } {
  # is it a dict, or can it be treated like one?
  if {[catch {dict size $d} err]} {
    #::set ::errorInfo {}
    return 0
  }
  return 1
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] is_dict ::tcl::dict::is_dict]
}
::clay::PROC ::tcl::dict::rmerge {args} {
  ::set result [dict create . {}]
  # Merge b into a, and handle nested dicts appropriately
  ::foreach b $args {
    for { k v } $b {
      ::set field [string trim $k :/]
      if {![::clay::tree::is_branch $b $k]} {
        # Element names that end in ":" are assumed to be literals
        set result $k $v
      } elseif { [exists $result $k] } {
        # key exists in a and b?  let's see if both values are dicts
        # both are dicts, so merge the dicts
        if { [is_dict [get $result $k]] && [is_dict $v] } {
          set result $k [rmerge [get $result $k] $v]
        } else {
          set result $k $v
        }
      } else {
        set result $k $v
      }
    }
  }
  return $result
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] rmerge ::tcl::dict::rmerge]
}
::clay::PROC ::clay::tree::is_branch { dict path } {
  set field [lindex $path end]
  if {[string index $field end] eq ":"} {
    return 0
  }
  if {[string index $field 0] eq "."} {
    return 0
  }
  if {[string index $field end] eq "/"} {
    return 1
  }
  return [dict exists $dict {*}$path .]
}
::clay::PROC ::clay::tree::print {dict} {
  ::set result {}
  ::set level -1
  ::clay::tree::_dictputb $level result $dict
  return $result
}
::clay::PROC ::clay::tree::_dictputb {level varname dict} {
  upvar 1 $varname result
  incr level
  dict for {field value} $dict {
    if {$field eq "."} continue
    if {[clay::tree::is_branch $dict $field]} {
      putb result "[string repeat "  " $level]$field \{"
      _dictputb $level result $value
      putb result "[string repeat "  " $level]\}"
    } else {
      putb result "[string repeat "  " $level][list $field $value]"
    }
  }
}
proc ::clay::tree::sanitize {dict} {
  ::set result {}
  ::set level -1
  ::clay::tree::_sanitizeb {} result $dict
  return $result
}
proc ::clay::tree::_sanitizeb {path varname dict} {
  upvar 1 $varname result
  dict for {field value} $dict {
    if {$field eq "."} continue
    if {[clay::tree::is_branch $dict $field]} {
      _sanitizeb [list {*}$path $field] result $value
    } else {
      dict set result {*}$path $field $value
    }
  }
}
proc ::clay::tree::storage {rawpath} {
  set isleafvar 0
  set path {}
  set tail [string index $rawpath end]
  foreach element $rawpath {
    set items [split [string trim $element /] /]
    foreach item $items {
      if {$item eq {}} continue
      lappend path $item
    }
  }
  return $path
}
proc ::clay::tree::dictset {varname args} {
  upvar 1 $varname result
  if {[llength $args] < 2} {
    error "Usage: ?path...? path value"
  } elseif {[llength $args]==2} {
    set rawpath [lindex $args 0]
  } else {
    set rawpath  [lrange $args 0 end-1]
  }
  set value [lindex $args end]
  set path [storage $rawpath]
  set dot .
  set one {}
  dict set result $dot $one
  set dpath {}
  foreach item [lrange $path 0 end-1] {
    set field $item
    lappend dpath [string trim $item /]
    dict set result {*}$dpath $dot $one
  }
  set field [lindex $rawpath end]
  set ext   [string index $field end]
  if {$ext eq {:} || ![dict is_dict $value]} {
    dict set result {*}$path $value
    return
  }
  if {$ext eq {/} && ![dict exists $result {*}$path $dot]} {
    dict set result {*}$path $dot $one
  }
  if {[dict exists $result {*}$path $dot]} {
    dict set result {*}$path [::clay::tree::merge [dict get $result {*}$path] $value]
    return
  }
  dict set result {*}$path $value
}
proc ::clay::tree::dictmerge {varname args} {
  upvar 1 $varname result
  set dot .
  set one {}
  dict set result $dot $one
  foreach dict $args {
    dict for {f v} $dict {
      set field [string trim $f /]
      set bbranch [clay::tree::is_branch $dict $f]
      if {![dict exists $result $field]} {
        dict set result $field $v
        if {$bbranch} {
          dict set result $field [clay::tree::merge $v]
        } else {
          dict set result $field $v
        }
      } elseif {[dict exists $result $field $dot]} {
        if {$bbranch} {
          dict set result $field [clay::tree::merge [dict get $result $field] $v]
        } else {
          dict set result $field $v
        }
      }
    }
  }
  return $result
}
proc ::clay::tree::merge {args} {
  ###
  # The result of a merge is always a dict with branches
  ###
  set dot .
  set one {}
  dict set result $dot $one
  set argument 0
  foreach b $args {
    # Merge b into a, and handle nested dicts appropriately
    if {![dict is_dict $b]} {
      error "Element $b is not a dictionary"
    }
    dict for { k v } $b {
      if {$k eq $dot} {
        dict set result $dot $one
        continue
      }
      set bbranch [is_branch $b $k]
      set field [string trim $k /]
      if { ![dict exists $result $field] } {
        if {$bbranch} {
          dict set result $field [merge $v]
        } else {
          dict set result $field $v
        }
      } else {
        set abranch [dict exists $result $field $dot]
        if {$abranch && $bbranch} {
          dict set result $field [merge [dict get $result $field] $v]
        } else {
          dict set result $field $v
          if {$bbranch} {
            dict set result $field $dot $one
          }
        }
      }
    }
  }
  return $result
}
::clay::PROC ::tcl::dict::isnull {dictionary args} {
  if {![exists $dictionary {*}$args]} {return 1}
  return [expr {[get $dictionary {*}$args] in {{} NULL null}}]
} {
  namespace ensemble configure dict -map [dict replace\
      [namespace ensemble configure dict -map] isnull ::tcl::dict::isnull]
}

###
# END: dict.tcl
###
###
# START: list.tcl
###
::clay::PROC ::clay::ladd {varname args} {
  upvar 1 $varname var
  if ![info exists var] {
      set var {}
  }
  foreach item $args {
    if {$item in $var} continue
    lappend var $item
  }
  return $var
}
::clay::PROC ::clay::ldelete {varname args} {
  upvar 1 $varname var
  if ![info exists var] {
      return
  }
  foreach item [lsort -unique $args] {
    while {[set i [lsearch $var $item]]>=0} {
      set var [lreplace $var $i $i]
    }
  }
  return $var
}
::clay::PROC ::clay::lrandom list {
  set len [llength $list]
  set idx [expr int(rand()*$len)]
  return [lindex $list $idx]
}

###
# END: list.tcl
###
###
# START: dictargs.tcl
###
namespace eval ::dictargs {
}
if {[info commands ::dictargs::parse] eq {}} {
  proc ::dictargs::parse {argdef argdict} {
    set result {}
    dict for {field info} $argdef {
      if {![string is alnum [string index $field 0]]} {
        error "$field is not a simple variable name"
      }
      upvar 1 $field _var
      set aliases {}
      if {[dict exists $argdict $field]} {
        set _var [dict get $argdict $field]
        continue
      }
      if {[dict exists $info aliases:]} {
        set found 0
        foreach {name} [dict get $info aliases:] {
          if {[dict exists $argdict $name]} {
            set _var [dict get $argdict $name]
            set found 1
            break
          }
        }
        if {$found} continue
      }
      if {[dict exists $info default:]} {
        set _var [dict get $info default:]
        continue
      }
      set mandatory 1
      if {[dict exists $info mandatory:]} {
        set mandatory [dict get $info mandatory:]
      }
      if {$mandatory} {
        error "$field is required"
      }
    }
  }
}
proc ::dictargs::proc {name argspec body} {
  set result {}
  append result "::dictargs::parse \{$argspec\} \$args" \;
  append result $body
  uplevel 1 [list ::proc $name [list [list args [list dictargs $argspec]]] $result]
}
proc ::dictargs::method {name argspec body} {
  set class [lindex [::info level -1] 1]
  set result {}
  append result "::dictargs::parse \{$argspec\} \$args" \;
  append result $body
  oo::define $class method $name [list [list args [list dictargs $argspec]]] $result
}

###
# END: dictargs.tcl
###
###
# START: dialect.tcl
###
namespace eval ::clay::dialect {
  namespace export create
  foreach {flag test} {
    tip470 {package vsatisfies [package provide Tcl] 8.7}
  } {
    if {![info exists ::clay::dialect::has($flag)]} {
      set ::clay::dialect::has($flag) [eval $test]
    }
  }
}
proc ::clay::dialect::Push {class} {
  ::variable class_stack
  lappend class_stack $class
}
proc ::clay::dialect::Peek {} {
  ::variable class_stack
  return [lindex $class_stack end]
}
proc ::clay::dialect::Pop {} {
  ::variable class_stack
  set class_stack [lrange $class_stack 0 end-1]
}
if {$::clay::dialect::has(tip470)} {
proc ::clay::dialect::current_class {} {
  return [uplevel 1 self]
}
} else {
proc ::clay::dialect::current_class {} {
  tailcall Peek
}
}
proc ::clay::dialect::create {name {parent ""}} {
  variable has
  set NSPACE [NSNormalize [uplevel 1 {namespace current}] $name]
  ::namespace eval $NSPACE {::namespace eval define {}}
  ###
  # Build the "define" namespace
  ###

  if {$parent eq ""} {
    ###
    # With no "parent" language, begin with all of the keywords in
    # oo::define
    ###
    foreach command [info commands ::oo::define::*] {
      set procname [namespace tail $command]
      interp alias {} ${NSPACE}::define::$procname {} \
        ::clay::dialect::DefineThunk $procname
    }
    # Create an empty dynamic_methods proc
    proc ${NSPACE}::dynamic_methods {class} {}
    namespace eval $NSPACE {
      ::namespace export dynamic_methods
      ::namespace eval define {::namespace export *}
    }
    set ANCESTORS {}
  } else {
    ###
    # If we have a parent language, that language already has the
    # [oo::define] keywords as well as additional keywords and behaviors.
    # We should begin with that
    ###
    set pnspace [NSNormalize [uplevel 1 {namespace current}] $parent]
    apply [list parent {
      ::namespace export dynamic_methods
      ::namespace import -force ${parent}::dynamic_methods
    } $NSPACE] $pnspace

    apply [list parent {
      ::namespace import -force ${parent}::define::*
      ::namespace export *
    } ${NSPACE}::define] $pnspace
      set ANCESTORS [list ${pnspace}::object]
  }
  ###
  # Build our dialect template functions
  ###
  proc ${NSPACE}::define {oclass args} [string map [list %NSPACE% $NSPACE] {
  ###
  # To facilitate library reloading, allow
  # a dialect to create a class from DEFINE
  ###
  set class [::clay::dialect::NSNormalize [uplevel 1 {namespace current}] $oclass]
    if {[info commands $class] eq {}} {
      %NSPACE%::class create $class {*}${args}
    } else {
      ::clay::dialect::Define %NSPACE% $class {*}${args}
    }
}]
  interp alias {} ${NSPACE}::define::current_class {} \
    ::clay::dialect::current_class
  interp alias {} ${NSPACE}::define::aliases {} \
    ::clay::dialect::Aliases $NSPACE
  interp alias {} ${NSPACE}::define::superclass {} \
    ::clay::dialect::SuperClass $NSPACE

  if {[info command ${NSPACE}::class] ne {}} {
    ::rename ${NSPACE}::class {}
  }
  ###
  # Build the metaclass for our language
  ###
  ::oo::class create ${NSPACE}::class {
    superclass ::clay::dialect::MotherOfAllMetaClasses
  }
  # Wire up the create method to add in the extra argument we need; the
  # MotherOfAllMetaClasses will know what to do with it.
  ::oo::objdefine ${NSPACE}::class \
    method create {name {definitionScript ""}} \
      "next \$name [list ${NSPACE}::define] \$definitionScript"

  ###
  # Build the mother of all classes. Note that $ANCESTORS is already
  # guaranteed to be a list in canonical form.
  ###
  uplevel #0 [string map [list %NSPACE% [list $NSPACE] %name% [list $name] %ANCESTORS% $ANCESTORS] {
    %NSPACE%::class create %NSPACE%::object {
     superclass %ANCESTORS%
      # Put MOACish stuff in here
    }
  }]
  if { "${NSPACE}::class" ni $::clay::dialect::core_classes } {
    lappend ::clay::dialect::core_classes "${NSPACE}::class"
  }
  if { "${NSPACE}::object" ni $::clay::dialect::core_classes } {
    lappend ::clay::dialect::core_classes "${NSPACE}::object"
  }
}
proc ::clay::dialect::NSNormalize {namespace qualname} {
  if {![string match ::* $qualname]} {
    set qualname ${namespace}::$qualname
  }
  regsub -all {::+} $qualname "::"
}
proc ::clay::dialect::DefineThunk {target args} {
  tailcall ::oo::define [Peek] $target {*}$args
}
proc ::clay::dialect::Canonical {namespace NSpace class} {
  namespace upvar $namespace cname cname
  #if {[string match ::* $class]} {
  #  return $class
  #}
  if {[info exists cname($class)]} {
    return $cname($class)
  }
  if {[info exists ::clay::dialect::cname($class)]} {
    return $::clay::dialect::cname($class)
  }
  if {[info exists ::clay::dialect::cname(${NSpace}::${class})]} {
    return $::clay::dialect::cname(${NSpace}::${class})
  }
  foreach item [list "${NSpace}::$class" "::$class"] {
    if {[info commands $item] ne {}} {
      return $item
    }
  }
  return ${NSpace}::$class
}
proc ::clay::dialect::Define {namespace class args} {
  Push $class
  try {
  	if {[llength $args]==1} {
      namespace eval ${namespace}::define [lindex $args 0]
    } else {
      ${namespace}::define::[lindex $args 0] {*}[lrange $args 1 end]
    }
  	${namespace}::dynamic_methods $class
  } finally {
    Pop
  }
}
proc ::clay::dialect::Aliases {namespace args} {
  set class [Peek]
  namespace upvar $namespace cname cname
  set NSpace [join [lrange [split $class ::] 1 end-2] ::]
  set cname($class) $class
  foreach name $args {
    set cname($name) $class
    #set alias $name
    set alias [NSNormalize $NSpace $name]
    # Add a local metaclass reference
    if {![info exists ::clay::dialect::cname($alias)]} {
      lappend ::clay::dialect::aliases($class) $alias
      ##
      # Add a global reference, first come, first served
      ##
      set ::clay::dialect::cname($alias) $class
    }
  }
}
proc ::clay::dialect::SuperClass {namespace args} {
  set class [Peek]
  namespace upvar $namespace class_info class_info
  dict set class_info($class) superclass 1
  set ::clay::dialect::cname($class) $class
  set NSpace [join [lrange [split $class ::] 1 end-2] ::]
  set unique {}
  foreach item $args {
    set Item [Canonical $namespace $NSpace $item]
    dict set unique $Item $item
  }
  set root ${namespace}::object
  if {$class ne $root} {
    dict set unique $root $root
  }
  tailcall ::oo::define $class superclass {*}[dict keys $unique]
}
if {[info command ::clay::dialect::MotherOfAllMetaClasses] eq {}} {
::oo::class create ::clay::dialect::MotherOfAllMetaClasses {
  superclass ::oo::class
  constructor {define definitionScript} {
    $define [self] {
      superclass
    }
    $define [self] $definitionScript
  }
  method aliases {} {
    if {[info exists ::clay::dialect::aliases([self])]} {
      return $::clay::dialect::aliases([self])
    }
  }
}
}
namespace eval ::clay::dialect {
  variable core_classes {::oo::class ::oo::object}
}

###
# END: dialect.tcl
###
###
# START: metaclass.tcl
###
::clay::dialect::create ::clay
proc ::clay::dynamic_methods class {
  foreach command [info commands [namespace current]::dynamic_methods_*] {
    $command $class
  }
}
proc ::clay::dynamic_methods_class {thisclass} {
  set methods {}
  set mdata [$thisclass clay find class_typemethod]
  foreach {method info} $mdata {
    if {$method eq {.}} continue
    set method [string trimright $method :/-]
    if {$method in $methods} continue
    lappend methods $method
    set arglist [dict getnull $info arglist]
    set body    [dict getnull $info body]
    ::oo::objdefine $thisclass method $method $arglist $body
  }
}
proc ::clay::define::Array {name {values {}}} {
  set class [current_class]
  set name [string trim $name :/]
  $class clay branch array $name
  dict for {var val} $values {
    $class clay set array/ $name $var $val
  }
}
proc ::clay::define::Delegate {name info} {
  set class [current_class]
  foreach {field value} $info {
    $class clay set component/ [string trim $name :/]/ $field $value
  }
}
proc ::clay::define::constructor {arglist rawbody} {
  set body {
my variable DestroyEvent
set DestroyEvent 0
::clay::object_create [self] [info object class [self]]
# Initialize public variables and options
my InitializePublic
  }
  append body $rawbody
  set class [current_class]
  ::oo::define $class constructor $arglist $body
}
proc ::clay::define::Class_Method {name arglist body} {
  set class [current_class]
  $class clay set class_typemethod/ [string trim $name :/] [dict create arglist $arglist body $body]
}
proc ::clay::define::class_method {name arglist body} {
  set class [current_class]
  $class clay set class_typemethod/ [string trim $name :/] [dict create arglist $arglist body $body]
}
proc ::clay::define::clay {args} {
  set class [current_class]
  if {[lindex $args 0] in "cget set branch"} {
    $class clay {*}$args
  } else {
    $class clay set {*}$args
  }
}
proc ::clay::define::destructor rawbody {
  set body {
# Run the destructor once and only once
set self [self]
my variable DestroyEvent
if {$DestroyEvent} return
set DestroyEvent 1
}
  append body $rawbody
  ::oo::define [current_class] destructor $body
}
proc ::clay::define::Dict {name {values {}}} {
  set class [current_class]
  set name [string trim $name :/]
  $class clay branch dict $name
  foreach {var val} $values {
    $class clay set dict/ $name/ $var $val
  }
}
proc ::clay::define::Option {name args} {
  set class [current_class]
  set dictargs {default {}}
  foreach {var val} [::clay::args_to_dict {*}$args] {
    dict set dictargs [string trim $var -:/] $val
  }
  set name [string trimleft $name -]

  ###
  # Option Class handling
  ###
  set optclass [dict getnull $dictargs class]
  if {$optclass ne {}} {
    foreach {f v} [$class clay find option_class $optclass] {
      if {![dict exists $dictargs $f]} {
        dict set dictargs $f $v
      }
    }
    if {$optclass eq "variable"} {
      variable $name [dict getnull $dictargs default]
    }
  }
  foreach {f v} $dictargs {
    $class clay set option $name $f $v
  }
}
proc ::clay::define::Method {name argstyle argspec body} {
  set class [current_class]
  set result {}
  switch $argstyle {
    dictargs {
      append result "::dictargs::parse \{$argspec\} \$args" \;
    }
  }
  append result $body
  oo::define $class method $name [list [list args [list dictargs $argspec]]] $result
}
proc ::clay::define::Option_Class {name args} {
  set class [current_class]
  set dictargs {default {}}
  set name [string trimleft $name -:]
  foreach {f v} [::clay::args_to_dict {*}$args] {
    $class clay set option_class $name [string trim $f -/:] $v
  }
}
proc ::clay::define::Variable {name {default {}}} {
  set class [current_class]
  set name [string trimright $name :/]
  $class clay set variable/ $name $default
}

###
# END: metaclass.tcl
###
###
# START: ensemble.tcl
###
::namespace eval ::clay::define {
}
proc ::clay::ensemble_methodbody {ensemble einfo} {
  set default standard
  set preamble {}
  set eswitch {}
  set Ensemble [string totitle $ensemble]
  if {$Ensemble eq "."} continue
  foreach {msubmethod minfo} [lsort -dictionary -stride 2 $einfo] {
    if {$msubmethod eq "."} continue
    if {![dict exists $minfo body:]} {
      continue
    }
    set submethod [string trim $msubmethod :/-]
    if {$submethod eq "default"} {
      set default [dict get $minfo body:]
    } else {
      dict set eswitch $submethod [dict get $minfo body:]
    }
    if {[dict exists $submethod aliases:]} {
      foreach alias [dict get $minfo aliases:] {
        if {![dict exists $eswitch $alias]} {
          dict set eswitch $alias [dict get $minfo body:]
        }
      }
    }
  }
  set methodlist [lsort -dictionary [dict keys $eswitch]]
  if {![dict exists $eswitch <list>]} {
    dict set eswitch <list> {return $methodlist}
  }
  if {$default eq "standard"} {
    set default "error \"unknown method $ensemble \$method. Valid: \$methodlist\""
  }
  dict set eswitch default $default
  set mbody {}
  append mbody \n [list set methodlist $methodlist]
  append mbody \n "switch -- \$method \{$eswitch\}" \n
  return $mbody
}
::proc ::clay::define::Ensemble {rawmethod args} {
  if {[llength $args]==2} {
    lassign $args argspec body
    set argstyle tcl
  } elseif {[llength $args]==3} {
    lassign $args argstyle argspec body
  } else {
    error "Usage: Ensemble name ?argstyle? argspec body"
  }
  set class [current_class]
  #if {$::clay::trace>2} {
  #  puts [list $class Ensemble $rawmethod $argspec $body]
  #}
  set mlist [split $rawmethod "::"]
  set ensemble [string trim [lindex $mlist 0] :/]
  set method   [string trim [lindex $mlist 2] :/]
  if {[string index $method 0] eq "_"} {
    $class clay set method_ensemble $ensemble $method $body
    return
  }
  set realmethod  [string totitle $ensemble]_${method}
  set realbody {}
  if {$argstyle eq "dictargs"} {
    append realbody "::dictargs::parse \{$argspec\} \$args" \n
  }
  if {[$class clay exists method_ensemble $ensemble _preamble]} {
    append realbody [$class clay get method_ensemble $ensemble _preamble] \n
  }
  append realbody $body
  if {$method eq "default"} {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod \$method {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::define $class method $realmethod [list method [list args $argspec]] $realbody
    } else {
      oo::define $class method $realmethod [list method {*}$argspec] $realbody
    }
  } else {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::define $class method $realmethod [list [list args $argspec]] $realbody
    } else {
      oo::define $class method $realmethod $argspec $realbody
    }
  }
  if {$::clay::trace>2} {
    puts [list $class clay set method_ensemble/ $ensemble [string trim $method :/]  ...]
  }
}

###
# END: ensemble.tcl
###
###
# START: class.tcl
###
::oo::define ::clay::class {
  method clay {submethod args} {
    my variable clay
    if {![info exists clay]} {
      set clay {}
    }
    switch $submethod {
      ancestors {
        tailcall ::clay::ancestors [self]
      }
      branch {
        set path [::clay::tree::storage $args]
        if {![dict exists $clay {*}$path .]} {
          dict set clay {*}$path . {}
        }
      }
      exists {
        if {![info exists clay]} {
          return 0
        }
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path]} {
          return 1
        }
        if {[dict exists $clay {*}[lrange $path 0 end-1] [lindex $path end]:]} {
          return 1
        }
        return 0
      }
      dump {
        return $clay
      }
      dget {
         if {![info exists clay]} {
          return {}
        }
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path]} {
          return [dict get $clay {*}$path]
        }
        if {[dict exists $clay {*}[lrange $path 0 end-1] [lindex $path end]:]} {
          return [dict get $clay {*}[lrange $path 0 end-1] [lindex $path end]:]
        }
        return {}
      }
      is_branch {
        set path [::clay::tree::storage $args]
        return [dict exists $clay {*}$path .]
      }
      getnull -
      get {
        if {![info exists clay]} {
          return {}
        }
        set path [::clay::tree::storage $args]
        if {[llength $path]==0} {
          return $clay
        }
        if {[dict exists $clay {*}$path .]} {
          return [::clay::tree::sanitize [dict get $clay {*}$path]]
        }
        if {[dict exists $clay {*}$path]} {
          return [dict get $clay {*}$path]
        }
        if {[dict exists $clay {*}[lrange $path 0 end-1] [lindex $path end]:]} {
          return [dict get $clay {*}[lrange $path 0 end-1] [lindex $path end]:]
        }
        return {}
      }
      find {
        set path [::clay::tree::storage $args]
        if {![info exists clay]} {
          set clay {}
        }
        set clayorder [::clay::ancestors [self]]
        set found 0
        if {[llength $path]==0} {
          set result [dict create . {}]
          foreach class $clayorder {
            ::clay::tree::dictmerge result [$class clay dump]
          }
          return [::clay::tree::sanitize $result]
        }
        foreach class $clayorder {
          if {[$class clay exists {*}$path .]} {
            # Found a branch break
            set found 1
            break
          }
          if {[$class clay exists {*}$path]} {
            # Found a leaf. Return that value immediately
            return [$class clay get {*}$path]
          }
          if {[dict exists $clay {*}[lrange $path 0 end-1] [lindex $path end]:]} {
            return [dict get $clay {*}[lrange $path 0 end-1] [lindex $path end]:]
          }
        }
        if {!$found} {
          return {}
        }
        set result {}
        # Leaf searches return one data field at a time
        # Search in our local dict
        # Search in the in our list of classes for an answer
        foreach class [lreverse $clayorder] {
          ::clay::tree::dictmerge result [$class clay dget {*}$path]
        }
        return [::clay::tree::sanitize $result]
      }
      merge {
        foreach arg $args {
          ::clay::tree::dictmerge clay {*}$arg
        }
      }
      noop {
        # Do nothing. Used as a sign of clay savviness
      }
      search {
        foreach aclass [::clay::ancestors [self]] {
          if {[$aclass clay exists {*}$args]} {
            return [$aclass clay get {*}$args]
          }
        }
      }
      set {
        ::clay::tree::dictset clay {*}$args
      }
      unset {
        dict unset clay {*}$args
      }
      default {
        dict $submethod clay {*}$args
      }
    }
  }
}

###
# END: class.tcl
###
###
# START: object.tcl
###
::oo::define ::clay::object {
  method clay {submethod args} {
    my variable clay claycache clayorder config option_canonical
    if {![info exists clay]} {set clay {}}
    if {![info exists claycache]} {set claycache {}}
    if {![info exists config]} {set config {}}
    if {![info exists clayorder] || [llength $clayorder]==0} {
      set clayorder {}
      if {[dict exists $clay cascade]} {
        dict for {f v} [dict get $clay cascade] {
          if {$f eq "."} continue
          if {[info commands $v] ne {}} {
            lappend clayorder $v
          }
        }
      }
      lappend clayorder {*}[::clay::ancestors [info object class [self]] {*}[lreverse [info object mixins [self]]]]
    }
    switch $submethod {
      ancestors {
        return $clayorder
      }
      branch {
        set path [::clay::tree::storage $args]
        if {![dict exists $clay {*}$path .]} {
          dict set clay {*}$path . {}
        }
      }
      busy {
        my variable clay_busy
        if {[llength $args]} {
          set clay_busy [string is true [lindex $args 0]]
          set claycache {}
        }
        if {![info exists clay_busy]} {
          set clay_busy 0
        }
        return $clay_busy
      }
      cache {
        set path [lindex $args 0]
        set value [lindex $args 1]
        dict set claycache $path $value
      }
      cget {
        # Leaf searches return one data field at a time
        # Search in our local dict
        if {[llength $args]==1} {
          set field [string trim [lindex $args 0] -:/]
          if {[info exists option_canonical($field)]} {
            set field $option_canonical($field)
          }
          if {[dict exists $config $field]} {
            return [dict get $config $field]
          }
        }
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path]} {
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[dict exists $claycache {*}$path]} {
          if {[dict exists $claycache {*}$path .]} {
            return [dict remove [dict get $claycache {*}$path] .]
          } else {
            return [dict get $claycache {*}$path]
          }
        }
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          if {[$class clay exists {*}$path]} {
            set value [$class clay get {*}$path]
            dict set claycache {*}$path $value
            return $value
          }
          if {[$class clay exists const {*}$path]} {
            set value [$class clay get const {*}$path]
            dict set claycache {*}$path $value
            return $value
          }
          if {[$class clay exists option {*}$path default]} {
            set value [$class clay get option {*}$path default]
            dict set claycache {*}$path $value
            return $value
          }
        }
        return {}
      }
      delegate {
        if {![dict exists $clay .delegate <class>]} {
          dict set clay .delegate <class> [info object class [self]]
        }
        if {[llength $args]==0} {
          return [dict get $clay .delegate]
        }
        if {[llength $args]==1} {
          set stub <[string trim [lindex $args 0] <>]>
          if {![dict exists $clay .delegate $stub]} {
            return {}
          }
          return [dict get $clay .delegate $stub]
        }
        if {([llength $args] % 2)} {
          error "Usage: delegate
    OR
    delegate stub
    OR
    delegate stub OBJECT ?stub OBJECT? ..."
        }
        foreach {stub object} $args {
          set stub <[string trim $stub <>]>
          dict set clay .delegate $stub $object
          oo::objdefine [self] forward ${stub} $object
          oo::objdefine [self] export ${stub}
        }
      }
      dump {
        # Do a full dump of clay data
        set result {}
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          ::clay::tree::dictmerge result [$class clay dump]
        }
        ::clay::tree::dictmerge result $clay
        return $result
      }
      ensemble_map {
        set path [::clay::tree::storage method_ensemble]
        if {[dict exists $claycache {*}$path]} {
          return [dict get $claycache {*}$path]
        }
        set emap {}
        foreach class $clayorder {
          if {![$class clay exists {*}$path .]} continue
          dict for {ensemble einfo} [$class clay dget {*}$path] {
            if {$ensemble eq "."} continue
            dict for {method body} $einfo {
              if {$method eq "."} continue
              dict set emap $ensemble $method class: $class
              dict set emap $ensemble $method body: $body
            }
          }
        }
        if {[dict exists $clay {*}$path]} {
          dict for {ensemble einfo} [dict get $clay {*}$path] {
            dict for {method body} $einfo {
              if {$method eq "."} continue
              dict set emap $ensemble $method class: $class
              dict set emap $ensemble $method body: $body
            }
          }
        }
        dict set claycache {*}$path $emap
        return $emap
      }
      eval {
        set script [lindex $args 0]
        set buffer {}
        set thisline {}
        foreach line [split $script \n] {
          append thisline $line
          if {![info complete $thisline]} {
            append thisline \n
            continue
          }
          set thisline [string trim $thisline]
          if {[string index $thisline 0] eq "#"} continue
          if {[string length $thisline]==0} continue
          if {[lindex $thisline 0] eq "my"} {
            # Line already calls out "my", accept verbatim
            append buffer $thisline \n
          } elseif {[string range $thisline 0 2] eq "::"} {
            # Fully qualified commands accepted verbatim
            append buffer $thisline \n
          } elseif {
            append buffer "my $thisline" \n
          }
          set thisline {}
        }
        eval $buffer
      }
      evolve -
      initialize {
        my InitializePublic
      }
      exists {
        # Leaf searches return one data field at a time
        # Search in our local dict
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path]} {
          return 1
        }
        # Search in our local cache
        if {[dict exists $claycache {*}$path]} {
          return 2
        }
        set count 2
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          incr count
          if {[$class clay exists {*}$path]} {
            return $count
          }
        }
        return 0
      }
      flush {
        set claycache {}
        set clayorder [::clay::ancestors [info object class [self]] {*}[lreverse [info object mixins [self]]]]
      }
      forward {
        oo::objdefine [self] forward {*}$args
      }
      dget {
        set path [::clay::tree::storage $args]
        if {[llength $path]==0} {
          # Do a full dump of clay data
          set result {}
          # Search in the in our list of classes for an answer
          foreach class $clayorder {
            ::clay::tree::dictmerge result [$class clay dump]
          }
          ::clay::tree::dictmerge result $clay
          return $result
        }
        if {[dict exists $clay {*}$path] && ![dict exists $clay {*}$path .]} {
          # Path is a leaf
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[my clay search $path value isleaf]} {
          return $value
        }

        set found 0
        set branch [dict exists $clay {*}$path .]
        foreach class $clayorder {
          if {[$class clay exists {*}$path .]} {
            set found 1
            break
          }
          if {!$branch && [$class clay exists {*}$path]} {
            set result [$class clay dget {*}$path]
            my clay cache $path $result
            return $result
          }
        }
        # Path is a branch
        set result [dict getnull $clay {*}$path]
        foreach class $clayorder {
          if {![$class clay exists {*}$path .]} continue
          ::clay::tree::dictmerge result [$class clay dget {*}$path]
        }
        #if {[dict exists $clay {*}$path .]} {
        #  ::clay::tree::dictmerge result
        #}
        my clay cache $path $result
        return $result
      }
      getnull -
      get {
        set path [::clay::tree::storage $args]
        if {[llength $path]==0} {
          # Do a full dump of clay data
          set result {}
          # Search in the in our list of classes for an answer
          foreach class $clayorder {
            ::clay::tree::dictmerge result [$class clay dump]
          }
          ::clay::tree::dictmerge result $clay
          return [::clay::tree::sanitize $result]
        }
        if {[dict exists $clay {*}$path] && ![dict exists $clay {*}$path .]} {
          # Path is a leaf
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[my clay search $path value isleaf]} {
          if {!$isleaf} {
            return [clay::tree::sanitize $value]
          } else {
            return $value
          }
        }
        set found 0
        set branch [dict exists $clay {*}$path .]
        foreach class $clayorder {
          if {[$class clay exists {*}$path .]} {
            set found 1
            break
          }
          if {!$branch && [$class clay exists {*}$path]} {
            set result [$class clay dget {*}$path]
            my clay cache $path $result
            return $result
          }
        }
        # Path is a branch
        set result [dict getnull $clay {*}$path]
        #foreach class [lreverse $clayorder] {
        #  if {![$class clay exists {*}$path .]} continue
        #  ::clay::tree::dictmerge result [$class clay dget {*}$path]
        #}
        foreach class $clayorder {
          if {![$class clay exists {*}$path .]} continue
          ::clay::tree::dictmerge result [$class clay dget {*}$path]
        }
        #if {[dict exists $clay {*}$path .]} {
        #  ::clay::tree::dictmerge result [dict get $clay {*}$path]
        #}
        my clay cache $path $result
        return [clay::tree::sanitize $result]
      }
      leaf {
        # Leaf searches return one data field at a time
        # Search in our local dict
        set path [::clay::tree::storage $args]
        if {[dict exists $clay {*}$path .]} {
          return [clay::tree::sanitize [dict get $clay {*}$path]]
        }
        if {[dict exists $clay {*}$path]} {
          return [dict get $clay {*}$path]
        }
        # Search in our local cache
        if {[my clay search $path value isleaf]} {
          if {!$isleaf} {
            return [clay::tree::sanitize $value]
          } else {
            return $value
          }
        }
        # Search in the in our list of classes for an answer
        foreach class $clayorder {
          if {[$class clay exists {*}$path]} {
            set value [$class clay get {*}$path]
            my clay cache $path $value
            return $value
          }
        }
      }
      merge {
        foreach arg $args {
          ::clay::tree::dictmerge clay {*}$arg
        }
      }
      mixin {
        ###
        # Mix in the class
        ###
        my clay flush
        set prior  [info object mixins [self]]
        set newmixin {}
        foreach item $args {
          lappend newmixin ::[string trimleft $item :]
        }
        set newmap $args
        foreach class $prior {
          if {$class ni $newmixin} {
            set script [$class clay search mixin/ unmap-script]
            if {[string length $script]} {
              if {[catch $script err errdat]} {
                puts stderr "[self] MIXIN ERROR POPPING $class:\n[dict get $errdat -errorinfo]"
              }
            }
          }
        }
        ::oo::objdefine [self] mixin {*}$args
        ###
        # Build a compsite map of all ensembles defined by the object's current
        # class as well as all of the classes being mixed in
        ###
        my InitializePublic
        foreach class $newmixin {
          if {$class ni $prior} {
            set script [$class clay search mixin/ map-script]
            if {[string length $script]} {
              if {[catch $script err errdat]} {
                puts stderr "[self] MIXIN ERROR PUSHING $class:\n[dict get $errdat -errorinfo]"
              }
            }
          }
        }
        foreach class $newmixin {
          set script [$class clay search mixin/ react-script]
          if {[string length $script]} {
            if {[catch $script err errdat]} {
              puts stderr "[self] MIXIN ERROR PEEKING $class:\n[dict get $errdat -errorinfo]"
            }
            break
          }
        }
      }
      mixinmap {
        if {![dict exists $clay .mixin]} {
          dict set clay .mixin {}
        }
        if {[llength $args]==0} {
          return [dict get $clay .mixin]
        } elseif {[llength $args]==1} {
          return [dict getnull $clay .mixin [lindex $args 0]]
        } else {
          dict for {slot classes} $args {
            dict set clay .mixin $slot $classes
          }
          set classlist {}
          dict for {item class} [dict get $clay .mixin] {
            if {$class ne {}} {
              lappend classlist $class
            }
          }
          my clay mixin {*}[lreverse $classlist]
        }
      }
      provenance {
        if {[dict exists $clay {*}$args]} {
          return self
        }
        foreach class $clayorder {
          if {[$class clay exists {*}$args]} {
            return $class
          }
        }
        return {}
      }
      refcount {
        my variable refcount
        if {![info exists refcount]} {
          return 0
        }
        return $refcount
      }
      refcount_incr {
        my variable refcount
        incr refcount
      }
      refcount_decr {
        my variable refcount
        incr refcount -1
        if {$refcount <= 0} {
          ::clay::object_destroy [self]
        }
      }
      replace {
        set clay [lindex $args 0]
      }
      search {
        set path [lindex $args 0]
        upvar 1 [lindex $args 1] value [lindex $args 2] isleaf
        set isleaf [expr {![dict exists $claycache $path .]}]
        if {[dict exists $claycache $path]} {
          set value [dict get $claycache $path]
          return 1
        }
        return 0
      }
      source {
        source [lindex $args 0]
      }
      set {
        #puts [list [self] clay SET {*}$args]
        ::clay::tree::dictset clay {*}$args
      }
      default {
        dict $submethod clay {*}$args
      }
    }
  }
  method InitializePublic {} {
    my variable clayorder clay claycache config option_canonical clay_busy
    if {[info exists clay_busy] && $clay_busy} {
      # Avoid repeated calls to InitializePublic if we know that someone is
      # going to invoke it at the end of whatever process is going on
      return
    }
    set claycache {}
    set clayorder [::clay::ancestors [info object class [self]] {*}[lreverse [info object mixins [self]]]]
    if {![info exists clay]} {
      set clay {}
    }
    if {![info exists config]} {
      set config {}
    }
    dict for {var value} [my clay get variable] {
      if { $var in {. clay} } continue
      set var [string trim $var :/]
      my variable $var
      if {![info exists $var]} {
        if {$::clay::trace>2} {puts [list initialize variable $var $value]}
        set $var $value
      }
    }
    dict for {var value} [my clay get dict/] {
      if { $var in {. clay} } continue
      set var [string trim $var :/]
      my variable $var
      if {![info exists $var]} {
        set $var {}
      }
      foreach {f v} $value {
        if {$f eq "."} continue
        if {![dict exists ${var} $f]} {
          if {$::clay::trace>2} {puts [list initialize dict $var $f $v]}
          dict set ${var} $f $v
        }
      }
    }
    foreach {var value} [my clay get array/] {
      if { $var in {. clay} } continue
      set var [string trim $var :/]
      if { $var eq {clay} } continue
      my variable $var
      if {![info exists $var]} { array set $var {} }
      foreach {f v} $value {
        if {![array exists ${var}($f)]} {
          if {$f eq "."} continue
          if {$::clay::trace>2} {puts [list initialize array $var\($f\) $v]}
          set ${var}($f) $v
        }
      }
    }
    foreach {field info} [my clay get option/] {
      if { $field in {. clay} } continue
      set field [string trim $field -/:]
      foreach alias [dict getnull $info aliases] {
        set option_canonical($alias) $field
      }
      if {[dict exists $config $field]} continue
      set getcmd [dict getnull $info default-command]
      if {$getcmd ne {}} {
        set value [{*}[string map [list %field% $field %self% [namespace which my]] $getcmd]]
      } else {
        set value [dict getnull $info default]
      }
      dict set config $field $value
      set setcmd [dict getnull $info set-command]
      if {$setcmd ne {}} {
        {*}[string map [list %field% [list $field] %value% [list $value] %self% [namespace which my]] $setcmd]
      }
    }

    foreach {ensemble einfo} [my clay ensemble_map] {
      #if {[dict exists $einfo _body]} continue
      if {$ensemble eq "."} continue
      set body [::clay::ensemble_methodbody $ensemble $einfo]
      if {$::clay::trace>2} {
        set rawbody $body
        set body {puts [list [self] <object> [self method]]}
        append body \n $rawbody
      }
      oo::objdefine [self] method $ensemble {{method default} args} $body
    }
  }
}
::clay::object clay branch array
::clay::object clay branch mixin
::clay::object clay branch option
::clay::object clay branch dict clay
::clay::object clay set variable DestroyEvent 0

###
# END: object.tcl
###
###
# START: event.tcl
###
if {[info commands ::cron::object_destroy] eq {}} {
  # Provide a noop if we aren't running with the cron scheduler
  namespace eval ::cron {}
  proc ::cron::object_destroy args {}
}
::namespace eval ::clay::event {
}
proc ::clay::cleanup {} {
  if {![info exists ::clay::idle_destroy]} return
  foreach obj $::clay::idle_destroy {
    if {[info commands $obj] ne {}} {
      catch {$obj destroy}
    }
  }
  set ::clay::idle_destroy {}
}
proc ::clay::object_create {objname {class {}}} {
  #if {$::clay::trace>0} {
  #  puts [list $objname CREATE]
  #}
}
proc ::clay::object_rename {object newname} {
  if {$::clay::trace>0} {
    puts [list $object RENAME -> $newname]
  }
}
proc ::clay::object_destroy args {
  if {![info exists ::clay::idle_destroy]} {
    set ::clay::idle_destroy {}
  }
  foreach objname $args {
    if {$::clay::trace>0} {
      puts [list $objname DESTROY]
    }
    ::cron::object_destroy $objname
    if {$objname in $::clay::idle_destroy} continue
    lappend ::clay::idle_destroy $objname
  }
}
proc ::clay::event::cancel {self {task *}} {
  variable timer_event
  variable timer_script

  foreach {id event} [array get timer_event $self:$task] {
    ::after cancel $event
    set timer_event($id) {}
    set timer_script($id) {}
  }
}
proc ::clay::event::generate {self event args} {
  set wholist [Notification_list $self $event]
  if {$wholist eq {}} return
  set dictargs [::oo::meta::args_to_options {*}$args]
  set info $dictargs
  set strict 0
  set debug 0
  set sender $self
  dict with dictargs {}
  dict set info id     [::clay::event::nextid]
  dict set info origin $self
  dict set info sender $sender
  dict set info rcpt   {}
  foreach who $wholist {
    catch {::clay::event::notify $who $self $event $info}
  }
}
proc ::clay::event::nextid {} {
  return "event#[format %0.8x [incr ::clay::event_count]]"
}
proc ::clay::event::Notification_list {self event {stackvar {}}} {
  set notify_list {}
  foreach {obj patternlist} [array get ::clay::object_subscribe] {
    if {$obj eq $self} continue
    if {$obj in $notify_list} continue
    set match 0
    foreach {objpat eventlist} $patternlist {
      if {![string match $objpat $self]} continue
      foreach eventpat $eventlist {
        if {![string match $eventpat $event]} continue
        set match 1
        break
      }
      if {$match} {
        break
      }
    }
    if {$match} {
      lappend notify_list $obj
    }
  }
  return $notify_list
}
proc ::clay::event::notify {rcpt sender event eventinfo} {
  if {[info commands $rcpt] eq {}} return
  if {$::clay::trace} {
    puts [list event notify rcpt $rcpt sender $sender event $event info $eventinfo]
  }
  $rcpt notify $event $sender $eventinfo
}
proc ::clay::event::process {self handle script} {
  variable timer_event
  variable timer_script

  array unset timer_event $self:$handle
  array unset timer_script $self:$handle

  set err [catch {uplevel #0 $script} result errdat]
  if $err {
    puts "BGError: $self $handle $script
ERR: $result
[dict get $errdat -errorinfo]
***"
  }
}
proc ::clay::event::schedule {self handle interval script} {
  variable timer_event
  variable timer_script
  if {$::clay::trace} {
    puts [list $self schedule $handle $interval]
  }
  if {[info exists timer_event($self:$handle)]} {
    if {$script eq $timer_script($self:$handle)} {
      return
    }
    ::after cancel $timer_event($self:$handle)
  }
  set timer_script($self:$handle) $script
  set timer_event($self:$handle) [::after $interval [list ::clay::event::process $self $handle $script]]
}
proc ::clay::event::subscribe {self who event} {
  upvar #0 ::clay::object_subscribe($self) subscriptions
  if {![info exists subscriptions]} {
    set subscriptions {}
  }
  set match 0
  foreach {objpat eventlist} $subscriptions {
    if {![string match $objpat $who]} continue
    foreach eventpat $eventlist {
      if {[string match $eventpat $event]} {
        # This rule already exists
        return
      }
    }
  }
  dict lappend subscriptions $who $event
}
proc ::clay::event::unsubscribe {self args} {
  upvar #0 ::clay::object_subscribe($self) subscriptions
  if {![info exists subscriptions]} {
    return
  }
  switch [llength $args] {
    1 {
      set event [lindex $args 0]
      if {$event eq "*"} {
        # Shortcut, if the
        set subscriptions {}
      } else {
        set newlist {}
        foreach {objpat eventlist} $subscriptions {
          foreach eventpat $eventlist {
            if {[string match $event $eventpat]} continue
            dict lappend newlist $objpat $eventpat
          }
        }
        set subscriptions $newlist
      }
    }
    2 {
      set who [lindex $args 0]
      set event [lindex $args 1]
      if {$who eq "*" && $event eq "*"} {
        set subscriptions {}
      } else {
        set newlist {}
        foreach {objpat eventlist} $subscriptions {
          if {[string match $who $objpat]} {
            foreach eventpat $eventlist {
              if {[string match $event $eventpat]} continue
              dict lappend newlist $objpat $eventpat
            }
          }
        }
        set subscriptions $newlist
      }
    }
  }
}

###
# END: event.tcl
###
###
# START: singleton.tcl
###
proc ::clay::singleton {name script} {
  if {[info commands $name] eq {}} {
    ::clay::object create $name
  }
  oo::objdefine $name {
method SingletonProcs {} {
proc class class {
  uplevel 1 "oo::objdefine \[self\] class $class"
  my clay delegate class $class
}
proc clay args {
  my clay {*}$args
}
proc Ensemble {rawmethod args} {
  if {[llength $args]==2} {
    lassign $args argspec body
    set argstyle tcl
  } elseif {[llength $args]==3} {
    lassign $args argstyle argspec body
  } else {
    error "Usage: Ensemble name ?argstyle? argspec body"
  }
  set class [uplevel 1 self]
  #if {$::clay::trace>2} {
  #  puts [list $class Ensemble $rawmethod $argspec $body]
  #}
  set mlist [split $rawmethod "::"]
  set ensemble [string trim [lindex $mlist 0] :/]
  set method   [string trim [lindex $mlist 2] :/]
  if {[string index $method 0] eq "_"} {
    $class clay set method_ensemble $ensemble $method $body
    return
  }
  set realmethod  [string totitle $ensemble]_${method}
  set realbody {}
  if {$argstyle eq "dictargs"} {
    append realbody "::dictargs::parse \{$argspec\} \$args" \n
  }
  if {[$class clay exists method_ensemble $ensemble _preamble]} {
    append realbody [$class clay get method_ensemble $ensemble _preamble] \n
  }
  append realbody $body
  if {$method eq "default"} {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod \$method {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::objdefine $class method $realmethod [list method [list args $argspec]] $realbody
    } else {
      oo::objdefine $class method $realmethod [list method {*}$argspec] $realbody
    }
  } else {
    $class clay set method_ensemble $ensemble $method: "tailcall my $realmethod {*}\$args"
    if {$argstyle eq "dictargs"} {
      oo::objdefine $class method $realmethod [list [list args $argspec]] $realbody
    } else {
      oo::objdefine $class method $realmethod $argspec $realbody
    }
  }
  if {$::clay::trace>2} {
    puts [list $class clay set method_ensemble/ $ensemble [string trim $method :/]  ...]
  }
}
proc method args {
  uplevel 1 "oo::objdefine \[self\] method {*}$args"
}
}
method script script {
  my clay busy 1
  my SingletonProcs
  eval $script
  my clay busy 0
  my InitializePublic
}
}
  $name script $script
  return $name
}

###
# END: singleton.tcl
###

namespace eval ::clay {
  namespace export *
}

