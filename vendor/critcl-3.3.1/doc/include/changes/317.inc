[section {Changes for version 3.1.7}]
[list_begin enumerated]

[enum]	Fixed issue #24. Extract and unconditionally display compiler
	warnings found in the build log. Prevents users from missing
	warnings which, while not causing the build to fail, may
	still indicate problems.

[enum] 	New feature. Output hook. All non-messaging user output is now
	routed through the command [cmd critcl::print], and users are
	allowed to override it when using the critcl application-as-package.

[enum]	New feature, by Ashok P. Nadkarni. Platform configurations can
	inherit values from configurations defined before them.

[list_end]
