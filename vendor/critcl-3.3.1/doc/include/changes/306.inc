[section {Changes for version 3.0.6}]
[list_begin enumerated]

[enum]	Fixed github issue 10. The critcl application now delivers a
	proper exit code (1) on build failure, instead of always
	indicating success (status 0).

[enum]	Fixed github issue 13. Handling of bufferoverflowU.lib for
	release builds was inconsistent with handling for debug
	builds. It is now identically handled (conditional) by
	both cases.

[enum] 	Documentation cleanup, mainly in the installation guide, and
	the README.md shown by github

[list_end]
