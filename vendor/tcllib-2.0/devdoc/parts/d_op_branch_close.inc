
Be aware of where you are (see first definition).

[para] Ensure that you have clean checkout (see second definition).

       In the full-blown sequence (zig-zag) it is [emph required], due
       to the merging from trunk. In the shorter sequence it is only
       desired. That said, keeping the checkout clean before
       any major operations is a good habit to have, in my opinion.

[para] The full-blown sequencing with checks all the way is to

[list_begin enumerated]

[enum] Validate the checkout, i.e. last commit on your branch. Run the
       full test suite and other validations, fix all the issues which
       have cropped up.

[enum] Merge the latest state of the [term trunk] (see next definition).

[enum] Validate the checkout again. The incoming trunk changes may
       have broken something now. Do any required fixes.

[enum] Now merge to the trunk using

[example {
    fossil update trunk
    fossil merge --integrate YOUR_BRANCH
}]

[enum] At this point the checkout should be in the same state as at
       the end of point (3) above, because we resolved any issues with
       the trunk already. Thus a simple

[example {
    fossil commit ...
}]

       should be sufficient now to commit the merge back and close the
       branch (due to the [option --integrate] we used on the merge).

[para] The more paranoid may validate the checkout a third time before
       commiting.
[list_end]

[para] I call this a [term {zig-zag merge}] because of how the arrows
       look in the timeline, from trunk to feature branch for the
       first merge, and then back for the final merge.

[para] A less paranoid can do what I call a [term {simple merge}],
       which moves step (2) after step (4) and skips step (3)
       entirely. The resulting shorter sequence is

[list_begin enumerated]
[enum] Validate
[enum] Merge to trunk
[enum] Validate again
[enum] Commit to trunk
[list_end]

The last step after either zig-zag or plain merge is to

[example {
    fossil sync
}]

This saves our work to the remote side, and further gives us any other
work done while we were doing our merge. It especially allows us to
check if we raced somebody else, resulting in a split trunk.

[para] When that happens we should coordinate with the other developer
       on who fixes the split, to ensure that we do not race each
       other again.
