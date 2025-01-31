###
# A file distribution based on git
###
::clay::define ::practcl::distribution.git {
  superclass ::practcl::distribution

  method ScmTag {} {
    if {[my define exists scm_tag]} {
      return [my define get scm_tag]
    }
    if {[my define exists tag]} {
      set tag [my define get tag]
    } else {
      set tag master
    }
    my define set scm_tag $tag
    return $tag
  }

  method ScmUnpack {} {
    set srcdir [my SrcDir]
    if {[file exists [file join $srcdir .git]]} {
      return 0
    }
    set CWD [pwd]
    set tag [my ScmTag]
    set pkg [my define get name]
    if {[my define exists git_url]} {
      ::practcl::doexec git clone --branch $tag [my define get git_url] $srcdir
    } else {
      ::practcl::doexec git clone --branch $tag https://github.com/eviltwinskippy/$pkg $srcdir
    }
    return 1
  }

  method ScmUpdate {} {
    if {[my ScmUnpack]} {
      return
    }
    set CWD [pwd]
    set srcdir [my SrcDir]
    set tag [my ScmTag]
    ::practcl::doexec_in $srcdir git pull
    cd $CWD
  }
}

oo::objdefine ::practcl::distribution.git {

  method claim_object obj {
    set path [$obj define get srcdir]
    if {[my claim_path $path]} {
      return true
    }
    if {[$obj define get git_url] ne {}} {
      return true
    }
    return false
  }

  method claim_option {} {
    return git
  }

  method claim_path path {
   if {[file exists [file join $path .git]]} {
      return true
    }
    return false
  }
}
