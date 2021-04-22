if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded math                    1.2.5 [list source [file join $dir math.tcl]]
package ifneeded math::fuzzy             0.2.1 [list source [file join $dir fuzzy.tcl]]
package ifneeded math::complexnumbers    1.0.2 [list source [file join $dir qcomplex.tcl]]
package ifneeded math::constants         1.0.2 [list source [file join $dir constants.tcl]]
package ifneeded math::polynomials       1.0.1 [list source [file join $dir polynomials.tcl]]
package ifneeded math::rationalfunctions 1.0.1 [list source [file join $dir rational_funcs.tcl]]
package ifneeded math::fourier           1.0.2 [list source [file join $dir fourier.tcl]]

if {![package vsatisfies [package provide Tcl] 8.3]} {return}
package ifneeded math::roman             1.0   [list source [file join $dir romannumerals.tcl]]

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
package ifneeded math::optimize          1.0.1 [list source [file join $dir optimize.tcl]]
package ifneeded math::interpolate       1.1.2 [list source [file join $dir interpolate.tcl]]
package ifneeded math::bignum            3.1.1 [list source [file join $dir bignum.tcl]]
package ifneeded math::bigfloat          1.2.3 [list source [file join $dir bigfloat.tcl]]
package ifneeded math::machineparameters 0.1   [list source [file join $dir machineparameters.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded math::calculus          0.8.2 [list source [file join $dir calculus.tcl]]
# statistics depends on linearalgebra (for multi-variate linear regression).
# statistics depends on optimize (for logistic regression).
package ifneeded math::statistics        1.5.0 [list source [file join $dir statistics.tcl]]
package ifneeded math::linearalgebra     1.1.6 [list source [file join $dir linalg.tcl]]
package ifneeded math::calculus::symdiff 1.0.1 [list source [file join $dir symdiff.tcl]]
package ifneeded math::bigfloat          2.0.3 [list source [file join $dir bigfloat2.tcl]]
package ifneeded math::numtheory         1.1.3 [list source [file join $dir numtheory.tcl]]
package ifneeded math::decimal           1.0.4 [list source [file join $dir decimal.tcl]]
package ifneeded math::geometry          1.4.1 [list source [file join $dir geometry.tcl]]
package ifneeded math::trig              1.0   [list source [file join $dir trig.tcl]]
package ifneeded math::quasirandom       1.0   [list source [file join $dir quasirandom.tcl]]
package ifneeded math::special           0.5.2 [list source [file join $dir special.tcl]]

if {![package vsatisfies [package require Tcl] 8.6]} {return}
package ifneeded math::exact             1.0.1 [list source [file join $dir exact.tcl]]
package ifneeded math::PCA               1.0   [list source [file join $dir pca.tcl]]
package ifneeded math::figurate          1.0   [list source [file join $dir figurate.tcl]]
package ifneeded math::filters           0.1   [list source [file join $dir filtergen.tcl]]
package ifneeded math::probopt           1.0   [list source [file join $dir probopt.tcl]]
package ifneeded math::changepoint       0.1   [list source [file join $dir changepoint.tcl]]
package ifneeded math::combinatorics     2.0   [list source [file join $dir combinatoricsExt.tcl]]
