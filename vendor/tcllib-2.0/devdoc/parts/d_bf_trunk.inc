
The management and use of branches is an important part of working
with a [term {Distributed Version Control System}] ([term DVCS]) like
[uri https://www.fossil-scm.org/ fossil].

[para] For Tcllib the main branch of the collection is
       [term trunk]. In [term git] this branch would be called
       [term master], and this is exactly the case in the
       [uri https://github.com/tcltk/tcllib/ {github mirror}] of
       Tcllib.

[para] To properly support debugging [emph {each commit}] on this
       branch [emph {has to pass the entire testsuite}] of the
       collection. Using bisection to determine when an issue appeared
       is an example of an action made easier by this constraint.

[para] This is part of our collective responsibility for the usability
       of Tcllib in toto to the outside world.

       As [term fossil] has no mechanism to enforce this condition
       this is handled on the honor system for developers and maintainers.

[para] To make the task easier Tcllib comes with a tool
       ([file sak.tcl]) providing a number of commands in
       support. These commands are explained in the following sections
       of this guide.

[para] While it is possible and allowed to commit directly to trunk
       remember the above constraint regarding the testsuite, and the
       coming notes about other possible issues with a commit.
