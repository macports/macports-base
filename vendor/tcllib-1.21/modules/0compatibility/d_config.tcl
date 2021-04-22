# (c) 2022 Andreas Kupries
# Error wrapper for deprecated package
# Deprecated:
# - doctools::config
# Replacement:
# - struct::map

error "The package doctools::config is stage 2 deprecated. Use struct::map instead."
package provide doctools::config 0.1
return
