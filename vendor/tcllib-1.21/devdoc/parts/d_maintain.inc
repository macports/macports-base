
When contributing one or more packages for full inclusion into Tcllib
you are committing yourself to

[list_begin enumerated]

[enum] Keep the guidelines written down in
       [term {Tcl Community - Kind Communication}]
       (as any contributor) in your mind. The main point to take away
       from there is [emph {to be kind to each other}].

[enum] Your packages getting distributed under a BSD/MIT license.  For
       the details see [term {Tcllib - License}]

[enum] Maintenance of the new packages for a period of two years under
       the following rules, and responsibilities:

       [list_begin enumerated]

       [enum] A maintainer may step down after the mandatory period as
       	      they see fit.

       [enum] A maintainer may step down before the end of the
      	      mandatory period, under the condition that a replacement
      	      maintainer is immediately available and has agreed to
      	      serve the remainder of the period, plus their own
      	      mandatory period (see below).

       [enum] When stepping down without a replacement maintainer
      	      taking over the relevant packages have to be flagged as
      	      [const unmaintained].

       [enum] When a replacement mantainer is brought in for a package
      	      it is (kept) marked as [const maintained] (again).

       [para] A replacement maintainer is bound by the same rules as
	      the original maintainer, except that the mandatory
	      period of maintenance is shortened to one year.

       [enum] For any [const unmaintained] package a contributor
       	      interested in becoming its maintainer can become so by
       	      flagging them as [const maintained] with their name and
       	      contact information, committing themselves to the rules
       	      of a replacement maintainer (see previous point).

       [enum] For any already [const maintained] package a contributor
       	      interested in becoming a co-maintainer can become so
       	      with the agreement of the existing maintainer(s),
       	      committing themselves to the rules of a replacement
       	      maintainer (see two points previous).

       [list_end]

       [para] The responsibilities as a maintainer include:

       [list_begin enumerated]

       [enum] Watching Tcllib's ticket tracker for bugs, bug fixes,
       	      and feature requests related to the new packages.

       [enum] Reviewing the aforementioned tickets, rejecting or
       	      applying them

       [enum] Coordination and discussion with ticket submitter during
       	      the development and/or application of bug fixes.

       [list_end]

[enum] Follow the [sectref {Branching and Workflow}] of this guide.

[list_end]
