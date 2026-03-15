The oo::dialect Package
=======================

*oo::dialect* is designed for building TclOO based domain specific languages. It does this
by providing:
* a meta class
* a core object
* A namespace in which to define additional keywords
* A "define" command to mirror the capabilties of *oo::define*

Example usage:
<pre>
<code>
package require oo::dialect
oo::dialect::create tool

# Add a new keyword
proc ::tool::define::option {name def} {
  set class [class_current]
  oo::meta::info $class branchset option $name $def
}

# Override the "constructor" keyword
proc ::tool::define::constructor {arglist body} {
  set class [class_current]
  set prebody {
my _optionInit
  }
  oo::define $class constructor $arglist "$prebody\n$body"
}

# Add functions to the core class
::tool::define ::tool::object {
  method _optionInit {} {
    my variable options
    foreach {opt info} [my meta getnull option] {
      set options($opt) [dict getnull $info default:]
    }
  }
  method cget option {
    my variable options
    return $options($option)
  }
}

</code>
</pre>

In practice, a new class of this dialect would look like:

<pre>
<code>
::tool::class create myclass {
  # Use our new option keyword
  option color {default: green}
}

myclass create myobj
puts [myobj cget color]
> green
</code>
</pre>

