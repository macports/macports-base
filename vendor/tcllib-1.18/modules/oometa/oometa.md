The oo::meta package
============

The *oo::meta* package provides a data registry service for TclOO classes. It works by
providing the following:

* The **oo::meta::info** command, providing data introspection and manipulation
* The **oo::meta::metadata** command, providing a snapshot of the data per class instance
* The **oo::meta::ancestors** command, providing a linear representation of a class's inheritance tree
* A **meta** keyword in *oo::define*, to provide easy access to the data from within class definition bodies.
* A **meta** method for *oo::class*, to provide easy access to the data from a class instance
* A **meta** method for *oo::object*, which combines data from the class with a local *meta* variable

## Usage
<pre><code>
oo::class create animal {
  meta set biodata animal: 1
}
oo::class create mammal {
  superclass animal
  meta set biodata mammal: 1
}
oo::class create cat {
  superclass mammal
  meta set biodata diet: carnivore
}

cat create felix
puts [felix meta dump biodata]
> animal: 1 mammal: 1 diet: carnivore

felix meta set biodata likes: {birds mice}
puts [felix meta get biodata]
> animal: 1 mammal: 1 diet: carnivore likes: {bird mice}

# Modify a class
mammal meta set biodata metabolism: warm-blooded
puts [felix meta get biodata]
> animal: 1 mammal: 1 metabolism: warm-blooded diet: carnivore likes: {birds mice}

# Overwrite class info
felix meta set biodata mammal: yes
puts [felix meta get biodata]
> animal: 1 mammal: yes metabolism: warm-blooded diet: carnivore likes: {birds mice}
</code></pre>

## Concept
The concept behind *oo::meta* is that each class contributes a snippet of *local* data. When
**oo::meta::metadata** is called, the system walks through the linear ancestry produced by
**oo::meta::ancestors**, and recursively combines all of that local data for all of a class'
ancestors into a single dict.

Instances of oo::object can also combine class data with a local dict stored in the *meta* variable.

### oo::meta::info
*oo::meta::info* is intended to work on the metadata of a class in a manner similar to if the aggregate
pieces where assembled into a single dict. The system mimics all of the standard dict commands, and addes
the following:

#### oo::meta::info *class* branchget *?key...?* key
Returns a dict representation of the element at *args*, but with any trailing : removed from field names.

<pre><code>
::oo::meta::info $myclass set option color {default: green widget: colorselect}
puts [::oo::meta::info $myclass get option color]
> {default: green widget: color}
puts [::oo::meta::info $myclass branchget option color]
> {default green widget color}
</code></pre>

#### oo::meta::info *class* branchset *?key...? key dict*
Merges *dict* with any other information contaned at node *?key...?*, and adding a trailing :
to all field names.

<pre><code>
::oo::meta::info $myclass branchset option color {default green widget colorselect}
puts [::oo::meta::info $myclass get option color]
> {default: green widget: color}
</code></pre>

#### oo::meta::dump *class*
Returns the complete snapshot of a class metadata, as producted by **oo::meta::metadata**

#### oo::meta::info *class* is *type* *args*
Returns a boolean true or false if the element *args* would match **string is *type* *value***
<pre><code>
::oo::meta::info $myclass set constant mammal 1
puts [::oo::meta::info $myclass is true constant mammal]
> 1
</code></pre>

#### oo::meta::info *class* merge *dict* *dict* ?*dict...*?
Combines all of the arguments into a single dict, which is then stored as the new
local representation for this class.

#### oo::meta::info *class* rebuild
Forces the meta system to destroy any cached representation of a class' metadata before
the next access to **oo::meta::metadata**

### oo::meta::metadata *class*
Returns an aggregate picture of the metadata for *class*, combining its *local* data
with the *local* data from every class it is descended from.

## **meta** keyword
The package injects a command **oo::define::meta** which works to provide a class in the
process of definition access to **oo::meta::info**, but without having to look the name up.

## **meta** keyword
The package injects a command **oo::define::meta** which works to provide a class in the
process of definition access to **oo::meta::info** *class*, but without having
to look the name up.

## oo::class method **meta**
The package injects a new method **meta** into *oo::class* which works to provide a class
instance access to **oo::meta::info**.

## oo::object method **meta**
The package injects a new method **meta** into *oo::object*. oo::object combines the data
for its class (as provided by **oo::meta::metadata**), with a local variable *meta* to
produce a local picture of metadata.

This method provides the following additional commands:

#### method meta cget *?field...? field*
Attempts to locate a singlar leaf, and return its value. For single option lookups, this
is faster than [my meta getnull *?field...? field*], because it performs a search instead
directly instead of producing the recursive merge product between the class metadata, the
local *meta* variable, and THEN performing the search.




