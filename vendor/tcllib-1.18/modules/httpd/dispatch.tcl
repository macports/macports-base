###
# This file implements an extensible dispatch server for the httpd package
# The package is seperate because the code is equally applicable for either
# the httpd and scgi modes, and it also injects a suite of assumptions
# that may not be applicable to a general purpose tool
###
package require tool
package require httpd::content


package provide httpd::dispatch 4.0
