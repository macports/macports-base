
Be aware of where you are (see first definition).

[para] Ensure that you have clean checkout (see second definition).
       It is [emph required].
       
[para] In most situations you want to import the latest commit of
       branch [term trunk] (or other origin). To get it use

[example {
    fossil pull
}]

[para] With that done we can now import this commit into our current
       branch with

[example {
    fossil merge trunk
}]

[para] Even if [syscmd fossil] does not report any conflicts it is a
       good idea to check that the operation has not broken the new
       and/or changed functionality we are working on.

[para] With the establishment of a good merge we then save the state
       with

[example {
    fossil commit ...
}]

before continuing development.
