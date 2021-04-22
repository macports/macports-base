# (c) 2019 Andreas Kupries
# Redirection wrapper for deprecated package
# Deprecated:
# - doctools::paths
# Replacement:
# - fileutil::paths

error "The package doctools::paths is stage 2 deprecated. Use fileutil::paths instead."
package provide doctools::paths 0.1
return
