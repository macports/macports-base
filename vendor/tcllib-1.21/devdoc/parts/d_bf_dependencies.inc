
Regarding packages and dependencies between them Tcllib occupies a
middle position between two extremes:

[list_begin enumerated]

[enum] On one side a strongly interdependent set of packages, usually
       by a single author, for a single project. Looking at my
       (Andreas Kupries) own work examples of such are
       [uri https://core.tcl.tk/akupries/marpa/index Marpa],
       [uri https://core.tcl.tk/akupries/crimp/index CRIMP],
       [uri https://core.tcl.tk/akupries/kinetcl/index Kinetcl], etc.

[para] For every change the author of the project handles all the
       modifications cascading from any incompatibilities it
       introduced to the system.

[enum] On the other side, the world of semi-independent projects by
       many different authors where authors know what packages their
       own creations depend on, yet usually do not know who else
       depends on them.

[para] The best thing an author making an (incompatible) change to
       their project can do is to for one announce such changes in
       some way, and for two use versioning to distinguish the code
       before and after the change.

[para] The world is then responsible for adapting, be it by updating
       their own projects to the new version, or by sticking to the
       old.

[list_end]

As mentioned already, Tcllib lives in the middle of that.

[para] While we as maintainers cannot be aware of all users of
       Tcllib's packages, and thus have to rely on the mechanisms
       touched on in point 2 above for that, the dependencies between
       the packages contained in Tcllib are a different matter.

[para] As we are collectively responsible for the usability of Tcllib
       in toto to the outside world, it behooves us to be individually
       mindful even of Tcllib packages we are not directly
       maintaining, when they depend on packages under our
       maintainership.

       This may be as simple as coordinating with the maintainers of
       the affected packages.

       It may also require us to choose how to adapt affected packages
       which do not have maintainers, i.e. modify them to use our
       changed package properly, or modify them to properly depend on
       the unchanged version of our package.

[para] Note that the above is not only a chore but an opportunity as
       well.

       Additional insight can be had by forcing ourselves to look at
       our package and the planned change(s) from an outside
       perspective, to consider the ramifications of our actions on
       others in general, and on dependent packages in particular.
