# (c) 2019 Andreas Kupries
# Redirection wrapper for deprecated package
# Deprecated:
# - configuration
# Replacement:
# - struct::map

error "The package configuration is stage 2 deprecated. Use struct::map instead."
package provide configuration 1
return
