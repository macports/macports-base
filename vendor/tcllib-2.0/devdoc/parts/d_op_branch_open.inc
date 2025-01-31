
Be aware of where you are (see first definition).

[para] Ensure that you have clean checkout (see second definition).
       It is [emph required].

[para] In most situations you want to be on branch [term trunk], and
       you want to be on the latest commit for it. To get there use

[example {
    fossil pull
    fossil update trunk
}]

If some other branch is desired as the starting point for the coming
work replace [term trunk] in the commands above with the name of that
branch.

[para] With the base line established we now have two ways of creating
       the new branch, with differing (dis)advantages.

       The simpler way is to

[example {
    fossil branch new NAME_OF_NEW_BRANCH
}]

and start developing. The advantage here is that you cannot forget to
create the branch. The disadvantages are that we have a branch commit
unchanged from where we branched from, and that we have to use
high-handed techniques like hiding or shunning to get rid of the
commit should we decide to abandon the work before the first actual
commit on the branch.

[para] The other way of creating the branch is to start developing,
and then on the first commit use the option [option --branch] to tell
[syscmd fossil] that we are starting a branch now. I.e. run

[example {
    fossil commit --branch NAME_OF_NEW_BRANCH ...
}]

where [term ...] are any other options used to supply the commit
message, files to commit, etc.

[para] The (dis)advantages are now reversed.

[para] We have no superflous commit, only what is actually
       developed. The work is hidden until we commit to make our first
       commit.

[para] We may forget to use [option {--branch NAME_OF_NEW_BRANCH}] and
       then have to correct that oversight via the fossil web
       interface (I am currently unaware of ways of doing such from
       the command line, although some magic incantantion of
       [cmd {fossil tag create}] may work).

[para] It helps to keep awareness, like checking before any commit
       that we are on the desired branch.
