Module: TOOL
============

TOOL is the Tcl Object Oriented Library, a standard object framework. TOOL
implements common design patterns in a standardized, tested, and documented
manner. 

# Major Concepts

* Metadata Interitance
* Variable and Array Initialization
* Option handling
* Delegation
* Method Ensembles

## Metadata Interitance

TOOL builds on the oo::meta package to allow data and configuration to be
passed along to descendents in the same way methods are.

<pre><code>tool::class create fruit {
  property taste sweet
}
tool::class create fruit.apple {
  property color red
}
tool::class create fruit.orange {
  property color orange
}
fruit.orange create cutie
cutie property color
> orange
cutie property taste
> sweet
</code></pre>

## Variable and Array Initialization

TOOL modifies the *variable* keyword and adds and *array* keyword. Using
either will cause a variable of the given name to be initialized with the
given value for this class AND any descendents.

<pre><code>tool::class create car {
  option color {
    default: white
  }
  variable location home
  array physics {
    speed 0
    accel 0
    position {0 0}
  }

  method physics {field args} {
    my variable physics
    if {[llength $args]} {
      set physics($field) $args
    }
    return $physics($field)
  }
  method location {} {
    my variable location
    return $location
  }
  method move newloc {
    my variable location
    set location $newloc
  }
}

car create car1 color green
car1 cget color
> green
car create car2
car2 cget color
> white

car1 location
> home
car1 move work
car1 location
> work
car1 physics speed
> 0
car1 physics speed 10
car1 physics speed
> 10
</code></pre>

## Delegation

TOOL is built around objects delegating functions to other objects. To
keep track of which object is handling what function, TOOL provides
two methods *graft* and *organ*.

<pre><code>tool::class create human {}

human create bob name Robert
car1 graft driver bob
bob graft car car1
bob &lt;car&gt; physics speed
> 10
car1 &lt;driver&gt; cget name
> Robert
car1 organ driver
> bob
bob organ car
> car1
</code></pre>

## Method Ensembles

TOOL also introduces the concept of a method ensemble. To declare an ensemble
use a :: delimter in the name of the method.

<pre><code>tool::class create special {

  method foo::bar {} {
    return bar
  }
  method foo::baz {} {
    return baz
  }
  method foo::bat {} {
    return bat
  }
}

special create blah
bah foo <list>
> bar bat baz
bah foo bar
> bar
bar foo bing
> ERROR: Invalid command "bing", Valid: bar, bat, baz
</code></pre>

Keep in mind that everything is changeable on demand in TOOL,
and if you define a *default* method that will override the standard
unknown reply:

<pre><code>tool::define special {
  method foo::default args {
    return [list $method $args]  
  }
}
bar foo bing
> bing
</code></pre>
