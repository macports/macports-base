
Given the constraints placed on the [term trunk] branch of the
repository it is (strongly) recommended to perform any development
going beyond trivial changes on a non-trunk branch.

[para] Outside of the trunk developers are allowed to commit
       intermediate broken states of their work.

       Only at the end of a development cycle, when the relevant
       branch is considered ready for merging, will it be necessary to
       perform full the set of validations ensuring that the merge to
       come will create a good commit on trunk.

[para] Note that while a review from a second developer is not a
       required condition for merging a branch it is recommended to
       seek out such an independent opinion as a means of
       cross-checking the work.

[para] It also recommended to give any new branch a name which aids in
       determining additional details about it. Examples of good
       things to stick into a branch name would be

[list_begin itemized]
[item]	Developer (nick)name
[item]	Ticket hash/reference
[item]	One or two keywords applicable to the work
[item]	...
[list_end]

[para] Further, while most development branches are likely quite
       short-lived, no prohibitions exist against making longer-lived
       branches.

       Creators should however be mindful that the longer such a
       branch exists without merges the more divergent they will tend
       to be, with an associated increase in the effort which will
       have to be spent on either merging from and merging to trunk.
