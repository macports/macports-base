The file RELEASE_TAG in this directory is used by the rsync infrastructure
at macports to control the tag from which "released" code is provided,
ultimately, at rsync://rsync.darwinports.org/dpupdate1/base.

The script handling that operation checks out from cvs the code tagged by the
contents of the RELEASE_TAG file, and makes that code available via rsync.
