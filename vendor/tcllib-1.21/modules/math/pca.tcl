# pca.tcl --
#     Package for principal component analysis
#
package require Tcl 8.6
package require math::linearalgebra

namespace eval ::math::PCA {
    namespace export createPCA
}

# createPCA --
#     Create a PCA object. Based on the observations the principal
#     components are determined.
#
# Arguments:
#     data           List of observations to be analysed
#     args           Option-value pairs:
#                    -covariance 1/0 - use covariances instead of correlations
#
# Returns:
#     New object holding all information that is needed
#
proc ::math::PCA::createPCA {data args} {

    return [pcaClass new $data $args]
}

# pcaClass --
#     Class holding the variables and methods for PCA
#
::oo::class create ::math::PCA::pcaClass {
     variable eigenValues      {}
     variable eigenVectors     {}
     variable retainedValues   {}
     variable retainedVectors  {}
     variable numberComponents 0
     variable numberUsed       0
     variable numberData       0
     variable mean             {}
     variable scale            {}
     variable originalData     {}

     constructor {data options} {
         variable numberComponents
         variable numberUsed

         set originalData     $data
         set numberComponents [llength [lindex $data 0]]
         set numberUsed       $numberComponents
         set numberData       [llength $data]

         if { $numberComponents < 2 } {
             return -code error "The data should contain at least two components"
         }

         set correlation 1

         foreach {option value} $options {
             switch -- $option {
                 "" {
                     # Use default
                 }
                 "-covariance" {
                     set correlation [expr {$value? 0 : 1}]
                 }
                 default {
                     return -code error "Unknown option: $option"
                 }
             }
         }

         lassign [::math::PCA::Transform $data $correlation] observations mean scale

         #
         # Determine the singular value decomposition
         # Square and scale the singular values to get the proper eigenvalues
         #
         set usv          [::math::linearalgebra::determineSVD $observations]
         set eigenVectors [lindex $usv 2]
         set singular     [lindex $usv 1]

         set factor       [expr {1.0 / ([llength $data] - 1)}]
         set eigenValues  {}
         foreach c $singular {
             lappend eigenValues [expr {$c**2 * $factor}]
         }

         #
         # By default we use all principal components
         #
         set retainedVectors $eigenVectors
         set retainedValues  $eigenValues
     }

     #
     # Get the eigenvectors - either the ones to be used or all vectors
     #
     method eigenvectors {{option {}}} {
         variable eigenVectors
         variable retainedVectors

         if { $option eq "-all" } {
             return $eigenVectors
         } else {
             return $retainedVectors
         }
     }

     #
     # Get the eigenvalues - either the ones to be used or all values
     #
     method eigenvalues {{option {}}} {
         variable eigenValues
         variable retainedValues

         if { $option eq "-all" } {
             return $eigenValues
         } else {
             return $retainedValues
         }
     }

     #
     # Approximate an observation vector using the selected components
     #
     method approximate {observation} {
         variable retainedVectors
         variable mean
         variable scale

         set z      [::math::PCA::Normalise $observation $mean $scale]
         set t      [::math::linearalgebra::matmul $z $retainedVectors]
         set zhat   [::math::linearalgebra::matmul $t [::math::linearalgebra::transpose $retainedVectors]]
         set obshat [::math::PCA::Denormalise $zhat $mean $scale]

         return $obshat
     }

     #
     # Approximate the original data - convenience method
     #
     method approximateOriginal {} {
         variable originalData

         set approximation {}

         foreach observation $originalData {
             lappend approximation [my approximate $observation]
         }

         return $approximation
     }

     #
     # Return the scores
     #
     method scores {observation} {
         variable retainedVectors
         variable mean
         variable scale

         set z [::math::PCA::Normalise $observation $mean $scale]
         return [::math::linearalgebra::matmul $z $retainedVectors]
     }

     #
     # Return the distance
     #
     method distance {observation} {
         variable retainedVectors
         variable mean
         variable scale

         set z          [normalise $observation $mean $scale]
         set t          [::math::linearalgebra::matmul $z $retainedVectors]
         set zhat       [::math::linearalgebra::matmul $t [::math::linearalgebra::transpose $retainedVectors]]
         set difference [::math::linearalgebra::sub $z $zhat]
         return [::math::linearalgebra::norm [::math::PCA::Denormalise $difference $mean $scale]]
     }

     #
     # Return the Q statistic
     #
     method qstatistic {observation {option {}}} {
         variable mean
         variable scale

         set z          [::math::PCA::Normalise $observation $mean $scale]
         set t          [::math::linearalgebra::matmul $z $retainedVectors]
         set zhat       [::math::linearalgebra::matmul $t [::math::linearalgebra::transpose $retainedVectors]]
         set difference [::math::linearalgebra::sub $z $zhat]

         set qstat      [::math::linearalgebra::dotproduct $difference $difference]
         if { $option eq "" } {
             return $qstat
         } elseif { $option eq "-original" } {
             return [expr {$qstat * double($numberData) / double($numberData - $numberUsed - 1)}]
         } else {
             return -code error "Unknown option: $option - should be \"-original\""
         }
     }

     #
     # Get the proportions - the amount of variation explained by the components
     #
     method proportions {} {
         variable retainedValues

         set unscaledProportions {}
         foreach e $retainedValues {
             lappend unscaledProportions [expr {$e**2}]
         }

         set scale [lindex $unscaledProportions end]

         foreach p $unscaledProportions {
             lappend proportions [expr {$p / $scale}]
         }
         return $proportions
     }

     #
     # Set/get number of components to be used
     #
     method using {args} {
         variable numberComponents
         variable numberUsed
         variable eigenVectors
         variable retainedVectors

         if { [llength $args] == 0 } {

             return $numberUsed

         } elseif { [llength $args] == 1 } {

             set numberUsed [lindex $args 0]
             if { ![string is integer $numberUsed] || $numberUsed < 1 || $numberUsed > $numberComponents } {
                 return -code error "Number of components to be used must be between 1 and $numberComponents"
             }

         } elseif { [llength $args] == 2 } {

             if { [lindex $args 0] == "-minproportion" } {
                 set minimum [lindex $args 1]
                 if { [string is double $minimum] || $minimum <= 0.0 || $minimum > 1.0 } {
                     return -code error "Wrong arguments: the minimum proportion must be a number between 0 and 1 - it is \"$minimum\""
                 }

                 set sum    0.0
                 set number 0
                 foreach proportion [my proportions] {
                     set  sum    [expr {$sum + $proportion}]
                     incr number

                     if { $sum >= $minimum } {
                         break
                     }
                 }
             }
             if { $number == 0 } {
                 set number 1
             }
             set numberUsed $number

         } else {
             return -code error "Wrong arguments: use either the number of components or the minimal proportion"
         }

         if { $numberUsed < $numberComponents } {
             set retainedValues  [lrange $eigenValues 0 [expr {$numberUsed-1}]]
             set retainedVectors {}
             foreach row $eigenVectors {
                 lappend retainedVectors [lrange $row 0 [expr {$numberUsed-1}]]
             }
         } else {
             set retainedValues  $eigenValues
             set retainedVectors $eigenVectors
         }

         return $numberUsed
     }
}

# Normalise --
#     Normalise a vector, given mean and standard deviation
#
# Arguments:
#     observation       Observation vector to be normalised
#     mean              Mean value to be subtracted
#     scale             Scale factor for dividing the values by
#
proc ::math::PCA::Normalise {observation mean scale} {
    set result {}

    foreach o $observation m $mean s $scale {
        lappend result [expr {($o - $m) / $s}]
    }

    return $result
}

# Denormalise --
#     Denormalise a vector, given mean and standard deviation
#
# Arguments:
#     observation       Normalised observation vector
#     mean              Mean value to be added
#     scale             Scale factor for multiplying the values by
#
proc ::math::PCA::Denormalise {observation mean scale} {
    set result {}

    foreach o $observation m $mean s $scale {
        lappend result [expr {$o * $s + $m}]
    }

    return $result
}

# Transform
#     Transform the given observations and return the transformation parameters
#
# Arguments:
#     observations      List of observation vectors
#     correlation       Use correlation (1) or not
#
proc ::math::PCA::Transform {observations correlation} {
    set columns [llength [lindex $observations 0]]
    set number  [llength $observations]
    set mean    [lrepeat $columns [expr {0.0}]]
    set scale   [lrepeat $columns [expr {0.0}]]

    foreach observation $observations {
        set newMean  {}
        set newScale {}
        foreach o $observation m $mean s $scale {
            lappend newMean  [expr {$m + $o}]
            lappend newScale [expr {$s + $o**2}]
        }
        set mean  $newMean
        set scale $newScale
    }

    set mean  {}
    set scale {}

    foreach m $newMean s $newScale {
        lappend mean  [expr {$m / $number}]
        if { $correlation } {
            set sum [expr {($s - $m**2/$number)/($number-1)}]
            lappend scale [expr {$sum >= 0.0 ? sqrt($sum) : 0.0}]
        } else {
            lappend scale 1.0
        }
    }

    set result {}
    foreach observation $observations {
         lappend result [Normalise $observation $mean $scale]
    }
    return [list $result $mean $scale]
}

package provide math::PCA 1.0

# Test
if {0} {
set data {
    {7 4 3}
    {4 1 8}
    {6 3 5}
    {8 6 1}
    {8 5 7}
    {7 2 9}
    {5 3 3}
    {9 5 8}
    {7 4 5}
    {8 2 2}
}

set pca [::math::PCA::createPCA $data]

puts [$pca using]
puts [$pca using 2]

puts [::math::PCA::Transform $data 1]
puts [::math::PCA::Normalise {1.0 2.0 3.0} {0.0 1.0 2.0} {2.0 2.0 2.0}]
puts [::math::PCA::Denormalise {0.5 0.5 0.5} {0.0 1.0 2.0} {2.0 2.0 2.0}]

puts "Eigenvalues:  [$pca eigenvalues]"
puts "Eigenvectors: [::math::linearalgebra::show [$pca eigenvectors]]"
#puts [$pca proportions] -- check the definition!
$pca using 2
puts "Observation:   [lindex $data 0]"
puts "Approximation: [$pca approximate [lindex $data 0]]"
puts "Scores:        [$pca scores [lindex $data 0]]"
puts "Q-statistic:   [$pca qstatistic [lindex $data 0]]"
puts "(corrected)    [$pca qstatistic [lindex $data 0] -original]"

#puts [::math::PCA::createPCA $data -x 1]
}
