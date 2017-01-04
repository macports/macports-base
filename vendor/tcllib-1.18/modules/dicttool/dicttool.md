The dicttool Package
====================

The **dicttool** package enhances the standard *dict* command with several new
commands. In addition, the package also defines several "creature comfort" list commands as well.
Each command checks to see if a command already exists of the same name before adding itself,
just in case any of these slip into the core.

#### ladd *varname* *args*

This command will add a new instance of each element in *args* to *varname*,
but only if that element is not already present.

#### ldelete] *varname* *args*

This command will add a delete all instances of each element in *args* from *varname*.

#### dict getnull *args*

Operates like **dict get**, however if the key *args* does not exist, it returns an empty
list instead of throwing an error.

#### dict print *dict*

This command will produce a string representation of *dict*, with each nested branch on
a newline, and indented with two spaces for every level.

#### dict is_dict *value*

This command will return true if *value* can be interpreted as a dict. The command operates in
such a way as to not force an existing dict representation to shimmer into another internal rep.

#### dict rmerge *args*

Return a dict which is the product of a recursive merge of all of the arguments. Unlike **dict merge**,
this command descends into all of the levels of a dict. Dict keys which end in a : indicate a leaf, which
will be interpreted as a literal value, and not descended into further.

<pre><code>
set items [dict merge {
  option {color {default: green}}
} {
  option {fruit {default: mango}}
} {
  option {color {default: blue} fruit {widget: select values: {mango apple cherry grape}}}
}]
puts [dict print $items]
</code></pre>


Prints the following result:
<pre><code>
option {
  color {
    default: blue
  }
  fruit {
    widget: select
    values: {mango apple cherry grape}
  }
}
</pre></code>
