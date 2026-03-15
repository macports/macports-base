Deprecations in Tcllib 2.0
===========================

Four packages are stage 3 deprecated in favor of two replacements.
This means that these packages are now fully removed from Tcllib.

|Module|Package|Replacement|Deprecation stage|
|:---|:---|:---|:---|
|doctools|doctools::paths|fileutil::paths|(D3) Attempts to use throw errors|
|doctools|doctools::config|struct::map|(D3) Attempts to use throw errors|
|pt|paths|fileutil::paths|(D3) Attempts to use throw errors|
|pt|configuration|struct::map|(D3) Attempts to use throw errors|

Future progress:

  - Nothing anymore, until other new deprecations come up
