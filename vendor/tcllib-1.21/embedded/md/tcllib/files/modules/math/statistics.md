
[//000000001]: # (math::statistics \- Tcl Math Library)
[//000000002]: # (Generated from file 'statistics\.man' by tcllib/doctools with format 'markdown')
[//000000003]: # (math::statistics\(n\) 1 tcllib "Tcl Math Library")

<hr> [ <a href="../../../../toc.md">Main Table Of Contents</a> &#124; <a
href="../../../toc.md">Table Of Contents</a> &#124; <a
href="../../../../index.md">Keyword Index</a> &#124; <a
href="../../../../toc0.md">Categories</a> &#124; <a
href="../../../../toc1.md">Modules</a> &#124; <a
href="../../../../toc2.md">Applications</a> ] <hr>

# NAME

math::statistics \- Basic statistical functions and procedures

# <a name='toc'></a>Table Of Contents

  - [Table Of Contents](#toc)

  - [Synopsis](#synopsis)

  - [Description](#section1)

  - [GENERAL PROCEDURES](#section2)

  - [MULTIVARIATE LINEAR REGRESSION](#section3)

  - [STATISTICAL DISTRIBUTIONS](#section4)

  - [DATA MANIPULATION](#section5)

  - [PLOT PROCEDURES](#section6)

  - [THINGS TO DO](#section7)

  - [EXAMPLES](#section8)

  - [Bugs, Ideas, Feedback](#section9)

  - [Keywords](#keywords)

  - [Category](#category)

# <a name='synopsis'></a>SYNOPSIS

package require Tcl 8\.5  
package require math::statistics 1  

[__::math::statistics::mean__ *data*](#1)  
[__::math::statistics::min__ *data*](#2)  
[__::math::statistics::max__ *data*](#3)  
[__::math::statistics::number__ *data*](#4)  
[__::math::statistics::stdev__ *data*](#5)  
[__::math::statistics::var__ *data*](#6)  
[__::math::statistics::pstdev__ *data*](#7)  
[__::math::statistics::pvar__ *data*](#8)  
[__::math::statistics::median__ *data*](#9)  
[__::math::statistics::basic\-stats__ *data*](#10)  
[__::math::statistics::histogram__ *limits* *values* ?weights?](#11)  
[__::math::statistics::histogram\-alt__ *limits* *values* ?weights?](#12)  
[__::math::statistics::corr__ *data1* *data2*](#13)  
[__::math::statistics::interval\-mean\-stdev__ *data* *confidence*](#14)  
[__::math::statistics::t\-test\-mean__ *data* *est\_mean* *est\_stdev* *alpha*](#15)  
[__::math::statistics::test\-normal__ *data* *significance*](#16)  
[__::math::statistics::lillieforsFit__ *data*](#17)  
[__::math::statistics::test\-Duckworth__ *list1* *list2* *significance*](#18)  
[__::math::statistics::test\-anova\-F__ *alpha* *args*](#19)  
[__::math::statistics::test\-Tukey\-range__ *alpha* *args*](#20)  
[__::math::statistics::test\-Dunnett__ *alpha* *control* *args*](#21)  
[__::math::statistics::quantiles__ *data* *confidence*](#22)  
[__::math::statistics::quantiles__ *limits* *counts* *confidence*](#23)  
[__::math::statistics::autocorr__ *data*](#24)  
[__::math::statistics::crosscorr__ *data1* *data2*](#25)  
[__::math::statistics::mean\-histogram\-limits__ *mean* *stdev* *number*](#26)  
[__::math::statistics::minmax\-histogram\-limits__ *min* *max* *number*](#27)  
[__::math::statistics::linear\-model__ *xdata* *ydata* *intercept*](#28)  
[__::math::statistics::linear\-residuals__ *xdata* *ydata* *intercept*](#29)  
[__::math::statistics::test\-2x2__ *n11* *n21* *n12* *n22*](#30)  
[__::math::statistics::print\-2x2__ *n11* *n21* *n12* *n22*](#31)  
[__::math::statistics::control\-xbar__ *data* ?nsamples?](#32)  
[__::math::statistics::control\-Rchart__ *data* ?nsamples?](#33)  
[__::math::statistics::test\-xbar__ *control* *data*](#34)  
[__::math::statistics::test\-Rchart__ *control* *data*](#35)  
[__::math::statistics::test\-Kruskal\-Wallis__ *confidence* *args*](#36)  
[__::math::statistics::analyse\-Kruskal\-Wallis__ *args*](#37)  
[__::math::statistics::test\-Levene__ *groups*](#38)  
[__::math::statistics::test\-Brown\-Forsythe__ *groups*](#39)  
[__::math::statistics::group\-rank__ *args*](#40)  
[__::math::statistics::test\-Wilcoxon__ *sample\_a* *sample\_b*](#41)  
[__::math::statistics::spearman\-rank__ *sample\_a* *sample\_b*](#42)  
[__::math::statistics::spearman\-rank\-extended__ *sample\_a* *sample\_b*](#43)  
[__::math::statistics::kernel\-density__ *data* opt *\-option value* \.\.\.](#44)  
[__::math::statistics::bootstrap__ *data* *sampleSize* ?numberSamples?](#45)  
[__::math::statistics::wasserstein\-distance__ *prob1* *prob2*](#46)  
[__::math::statistics::kl\-divergence__ *prob1* *prob2*](#47)  
[__::math::statistics::logistic\-model__ *xdata* *ydata*](#48)  
[__::math::statistics::logistic\-probability__ *coeffs* *x*](#49)  
[__::math::statistics::tstat__ *dof* ?alpha?](#50)  
[__::math::statistics::mv\-wls__ *wt1* *weights\_and\_values*](#51)  
[__::math::statistics::mv\-ols__ *values*](#52)  
[__::math::statistics::pdf\-normal__ *mean* *stdev* *value*](#53)  
[__::math::statistics::pdf\-lognormal__ *mean* *stdev* *value*](#54)  
[__::math::statistics::pdf\-exponential__ *mean* *value*](#55)  
[__::math::statistics::pdf\-uniform__ *xmin* *xmax* *value*](#56)  
[__::math::statistics::pdf\-triangular__ *xmin* *xmax* *value*](#57)  
[__::math::statistics::pdf\-symmetric\-triangular__ *xmin* *xmax* *value*](#58)  
[__::math::statistics::pdf\-gamma__ *alpha* *beta* *value*](#59)  
[__::math::statistics::pdf\-poisson__ *mu* *k*](#60)  
[__::math::statistics::pdf\-chisquare__ *df* *value*](#61)  
[__::math::statistics::pdf\-student\-t__ *df* *value*](#62)  
[__::math::statistics::pdf\-gamma__ *a* *b* *value*](#63)  
[__::math::statistics::pdf\-beta__ *a* *b* *value*](#64)  
[__::math::statistics::pdf\-weibull__ *scale* *shape* *value*](#65)  
[__::math::statistics::pdf\-gumbel__ *location* *scale* *value*](#66)  
[__::math::statistics::pdf\-pareto__ *scale* *shape* *value*](#67)  
[__::math::statistics::pdf\-cauchy__ *location* *scale* *value*](#68)  
[__::math::statistics::pdf\-laplace__ *location* *scale* *value*](#69)  
[__::math::statistics::pdf\-kumaraswamy__ *a* *b* *value*](#70)  
[__::math::statistics::pdf\-negative\-binomial__ *r* *p* *value*](#71)  
[__::math::statistics::cdf\-normal__ *mean* *stdev* *value*](#72)  
[__::math::statistics::cdf\-lognormal__ *mean* *stdev* *value*](#73)  
[__::math::statistics::cdf\-exponential__ *mean* *value*](#74)  
[__::math::statistics::cdf\-uniform__ *xmin* *xmax* *value*](#75)  
[__::math::statistics::cdf\-triangular__ *xmin* *xmax* *value*](#76)  
[__::math::statistics::cdf\-symmetric\-triangular__ *xmin* *xmax* *value*](#77)  
[__::math::statistics::cdf\-students\-t__ *degrees* *value*](#78)  
[__::math::statistics::cdf\-gamma__ *alpha* *beta* *value*](#79)  
[__::math::statistics::cdf\-poisson__ *mu* *k*](#80)  
[__::math::statistics::cdf\-beta__ *a* *b* *value*](#81)  
[__::math::statistics::cdf\-weibull__ *scale* *shape* *value*](#82)  
[__::math::statistics::cdf\-gumbel__ *location* *scale* *value*](#83)  
[__::math::statistics::cdf\-pareto__ *scale* *shape* *value*](#84)  
[__::math::statistics::cdf\-cauchy__ *location* *scale* *value*](#85)  
[__::math::statistics::cdf\-F__ *nf1* *nf2* *value*](#86)  
[__::math::statistics::cdf\-laplace__ *location* *scale* *value*](#87)  
[__::math::statistics::cdf\-kumaraswamy__ *a* *b* *value*](#88)  
[__::math::statistics::cdf\-negative\-binomial__ *r* *p* *value*](#89)  
[__::math::statistics::empirical\-distribution__ *values*](#90)  
[__::math::statistics::random\-normal__ *mean* *stdev* *number*](#91)  
[__::math::statistics::random\-lognormal__ *mean* *stdev* *number*](#92)  
[__::math::statistics::random\-exponential__ *mean* *number*](#93)  
[__::math::statistics::random\-uniform__ *xmin* *xmax* *number*](#94)  
[__::math::statistics::random\-triangular__ *xmin* *xmax* *number*](#95)  
[__::math::statistics::random\-symmetric\-triangular__ *xmin* *xmax* *number*](#96)  
[__::math::statistics::random\-gamma__ *alpha* *beta* *number*](#97)  
[__::math::statistics::random\-poisson__ *mu* *number*](#98)  
[__::math::statistics::random\-chisquare__ *df* *number*](#99)  
[__::math::statistics::random\-student\-t__ *df* *number*](#100)  
[__::math::statistics::random\-beta__ *a* *b* *number*](#101)  
[__::math::statistics::random\-weibull__ *scale* *shape* *number*](#102)  
[__::math::statistics::random\-gumbel__ *location* *scale* *number*](#103)  
[__::math::statistics::random\-pareto__ *scale* *shape* *number*](#104)  
[__::math::statistics::random\-cauchy__ *location* *scale* *number*](#105)  
[__::math::statistics::random\-laplace__ *location* *scale* *number*](#106)  
[__::math::statistics::random\-kumaraswamy__ *a* *b* *number*](#107)  
[__::math::statistics::random\-negative\-binomial__ *r* *p* *number*](#108)  
[__::math::statistics::histogram\-uniform__ *xmin* *xmax* *limits* *number*](#109)  
[__::math::statistics::incompleteGamma__ *x* *p* ?tol?](#110)  
[__::math::statistics::incompleteBeta__ *a* *b* *x* ?tol?](#111)  
[__::math::statistics::estimate\-pareto__ *values*](#112)  
[__::math::statistics::estimate\-exponential__ *values*](#113)  
[__::math::statistics::estimate\-laplace__ *values*](#114)  
[__::math::statistics::estimante\-negative\-binomial__ *r* *values*](#115)  
[__::math::statistics::filter__ *varname* *data* *expression*](#116)  
[__::math::statistics::map__ *varname* *data* *expression*](#117)  
[__::math::statistics::samplescount__ *varname* *list* *expression*](#118)  
[__::math::statistics::subdivide__](#119)  
[__::math::statistics::plot\-scale__ *canvas* *xmin* *xmax* *ymin* *ymax*](#120)  
[__::math::statistics::plot\-xydata__ *canvas* *xdata* *ydata* *tag*](#121)  
[__::math::statistics::plot\-xyline__ *canvas* *xdata* *ydata* *tag*](#122)  
[__::math::statistics::plot\-tdata__ *canvas* *tdata* *tag*](#123)  
[__::math::statistics::plot\-tline__ *canvas* *tdata* *tag*](#124)  
[__::math::statistics::plot\-histogram__ *canvas* *counts* *limits* *tag*](#125)  

# <a name='description'></a>DESCRIPTION

The __math::statistics__ package contains functions and procedures for basic
statistical data analysis, such as:

  - Descriptive statistical parameters \(mean, minimum, maximum, standard
    deviation\)

  - Estimates of the distribution in the form of histograms and quantiles

  - Basic testing of hypotheses

  - Probability and cumulative density functions

It is meant to help in developing data analysis applications or doing ad hoc
data analysis, it is not in itself a full application, nor is it intended to
rival with full \(non\-\)commercial statistical packages\.

The purpose of this document is to describe the implemented procedures and
provide some examples of their usage\. As there is ample literature on the
algorithms involved, we refer to relevant text books for more explanations\. The
package contains a fairly large number of public procedures\. They can be
distinguished in three sets: general procedures, procedures that deal with
specific statistical distributions, list procedures to select or transform data
and simple plotting procedures \(these require Tk\)\. *Note:* The data that need
to be analyzed are always contained in a simple list\. Missing values are
represented as empty list elements\. *Note:* With version 1\.0\.1 a mistake in
the procs *pdf\-lognormal*, *cdf\-lognormal* and *random\-lognormal* has been
corrected\. In previous versions the argument for the standard deviation was
actually used as if it was the variance\.

# <a name='section2'></a>GENERAL PROCEDURES

The general statistical procedures are:

  - <a name='1'></a>__::math::statistics::mean__ *data*

    Determine the *mean* value of the given list of data\.

      * list *data*

        \- List of data

  - <a name='2'></a>__::math::statistics::min__ *data*

    Determine the *[minimum](\.\./\.\./\.\./\.\./index\.md\#minimum)* value of the
    given list of data\.

      * list *data*

        \- List of data

  - <a name='3'></a>__::math::statistics::max__ *data*

    Determine the *[maximum](\.\./\.\./\.\./\.\./index\.md\#maximum)* value of the
    given list of data\.

      * list *data*

        \- List of data

  - <a name='4'></a>__::math::statistics::number__ *data*

    Determine the *number* of non\-missing data in the given list

      * list *data*

        \- List of data

  - <a name='5'></a>__::math::statistics::stdev__ *data*

    Determine the *sample standard deviation* of the data in the given list

      * list *data*

        \- List of data

  - <a name='6'></a>__::math::statistics::var__ *data*

    Determine the *sample variance* of the data in the given list

      * list *data*

        \- List of data

  - <a name='7'></a>__::math::statistics::pstdev__ *data*

    Determine the *population standard deviation* of the data in the given
    list

      * list *data*

        \- List of data

  - <a name='8'></a>__::math::statistics::pvar__ *data*

    Determine the *population variance* of the data in the given list

      * list *data*

        \- List of data

  - <a name='9'></a>__::math::statistics::median__ *data*

    Determine the *median* of the data in the given list \(Note that this
    requires sorting the data, which may be a costly operation\)

      * list *data*

        \- List of data

  - <a name='10'></a>__::math::statistics::basic\-stats__ *data*

    Determine a list of all the descriptive parameters: mean, minimum, maximum,
    number of data, sample standard deviation, sample variance, population
    standard deviation and population variance\.

    \(This routine is called whenever either or all of the basic statistical
    parameters are required\. Hence all calculations are done and the relevant
    values are returned\.\)

      * list *data*

        \- List of data

  - <a name='11'></a>__::math::statistics::histogram__ *limits* *values* ?weights?

    Determine histogram information for the given list of data\. Returns a list
    consisting of the number of values that fall into each interval\. \(The first
    interval consists of all values lower than the first limit, the last
    interval consists of all values greater than the last limit\. There is one
    more interval than there are limits\.\)

    Optionally, you can use weights to influence the histogram\.

      * list *limits*

        \- List of upper limits \(in ascending order\) for the intervals of the
        histogram\.

      * list *values*

        \- List of data

      * list *weights*

        \- List of weights, one weight per value

  - <a name='12'></a>__::math::statistics::histogram\-alt__ *limits* *values* ?weights?

    Alternative implementation of the histogram procedure: the open end of the
    intervals is at the lower bound instead of the upper bound\.

      * list *limits*

        \- List of upper limits \(in ascending order\) for the intervals of the
        histogram\.

      * list *values*

        \- List of data

      * list *weights*

        \- List of weights, one weight per value

  - <a name='13'></a>__::math::statistics::corr__ *data1* *data2*

    Determine the correlation coefficient between two sets of data\.

      * list *data1*

        \- First list of data

      * list *data2*

        \- Second list of data

  - <a name='14'></a>__::math::statistics::interval\-mean\-stdev__ *data* *confidence*

    Return the interval containing the mean value and one containing the
    standard deviation with a certain level of confidence \(assuming a normal
    distribution\)

      * list *data*

        \- List of raw data values \(small sample\)

      * float *confidence*

        \- Confidence level \(0\.95 or 0\.99 for instance\)

  - <a name='15'></a>__::math::statistics::t\-test\-mean__ *data* *est\_mean* *est\_stdev* *alpha*

    Test whether the mean value of a sample is in accordance with the estimated
    normal distribution with a certain probability\. Returns 1 if the test
    succeeds or 0 if the mean is unlikely to fit the given distribution\.

      * list *data*

        \- List of raw data values \(small sample\)

      * float *est\_mean*

        \- Estimated mean of the distribution

      * float *est\_stdev*

        \- Estimated stdev of the distribution

      * float *alpha*

        \- Probability level \(0\.95 or 0\.99 for instance\)

  - <a name='16'></a>__::math::statistics::test\-normal__ *data* *significance*

    Test whether the given data follow a normal distribution with a certain
    level of significance\. Returns 1 if the data are normally distributed within
    the level of significance, returns 0 if not\. The underlying test is the
    Lilliefors test\. Smaller values of the significance mean a stricter testing\.

      * list *data*

        \- List of raw data values

      * float *significance*

        \- Significance level \(one of 0\.01, 0\.05, 0\.10, 0\.15 or 0\.20\)\. For
        compatibility reasons the values "1\-significance", 0\.80, 0\.85, 0\.90,
        0\.95 or 0\.99 are also accepted\.

    Compatibility issue: the original implementation and documentation used the
    term "confidence" and used a value 1\-significance \(see ticket 2812473fff\)\.
    This has been corrected as of version 0\.9\.3\.

  - <a name='17'></a>__::math::statistics::lillieforsFit__ *data*

    Returns the goodness of fit to a normal distribution according to
    Lilliefors\. The higher the number, the more likely the data are indeed
    normally distributed\. The test requires at least *five* data points\.

      * list *data*

        \- List of raw data values

  - <a name='18'></a>__::math::statistics::test\-Duckworth__ *list1* *list2* *significance*

    Determine if two data sets have the same median according to the
    Tukey\-Duckworth test\. The procedure returns 0 if the medians are unequal, 1
    if they are equal, \-1 if the test can not be conducted \(the smallest value
    must be in a different set than the greatest value\)\. \# \# Arguments: \# list1
    Values in the first data set \# list2 Values in the second data set \#
    significance Significance level \(either 0\.05, 0\.01 or 0\.001\) \# \# Returns:
    Test whether the given data follow a normal distribution with a certain
    level of significance\. Returns 1 if the data are normally distributed within
    the level of significance, returns 0 if not\. The underlying test is the
    Lilliefors test\. Smaller values of the significance mean a stricter testing\.

      * list *list1*

        \- First list of data

      * list *list2*

        \- Second list of data

      * float *significance*

        \- Significance level \(either 0\.05, 0\.01 or 0\.001\)

  - <a name='19'></a>__::math::statistics::test\-anova\-F__ *alpha* *args*

    Determine if two or more groups with normally distributed data have the same
    means\. The procedure returns 0 if the means are likely unequal, 1 if they
    are\. This is a one\-way ANOVA test\. The groups may also be stored in a nested
    list: The procedure returns a list of the comparison results for each pair
    of groups\. Each element of this list contains: the index of the first group
    and that of the second group, whether the means are likely to be different
    \(1\) or not \(0\) and the confidence interval the conclusion is based on\. The
    groups may also be stored in a nested list:

        test-anova-F 0.05 $A $B $C
        #
        # Or equivalently:
        #
        test-anova-F 0.05 [list $A $B $C]

      * float *alpha*

        \- Significance level

      * list *args*

        \- Two or more groups of data to be checked

  - <a name='20'></a>__::math::statistics::test\-Tukey\-range__ *alpha* *args*

    Determine if two or more groups with normally distributed data have the same
    means, using Tukey's range test\. It is complementary to the ANOVA test\. The
    procedure returns a list of the comparison results for each pair of groups\.
    Each element of this list contains: the index of the first group and that of
    the second group, whether the means are likely to be different \(1\) or not
    \(0\) and the confidence interval the conclusion is based on\. The groups may
    also be stored in a nested list, just as with the ANOVA test\.

      * float *alpha*

        \- Significance level \- either 0\.05 or 0\.01

      * list *args*

        \- Two or more groups of data to be checked

  - <a name='21'></a>__::math::statistics::test\-Dunnett__ *alpha* *control* *args*

    Determine if one or more groups with normally distributed data have the same
    means as the group of control data, using Dunnett's test\. It is
    complementary to the ANOVA test\. The procedure returns a list of the
    comparison results for each group with the control group\. Each element of
    this list contains: whether the means are likely to be different \(1\) or not
    \(0\) and the confidence interval the conclusion is based on\. The groups may
    also be stored in a nested list, just as with the ANOVA test\.

    Note: some care is required if there is only one group to compare the
    control with:

        test-Dunnett-F 0.05 $control [list $A]

    Otherwise the group A is split up into groups of one element \- this is due
    to an ambiguity\.

      * float *alpha*

        \- Significance level \- either 0\.05 or 0\.01

      * list *args*

        \- One or more groups of data to be checked

  - <a name='22'></a>__::math::statistics::quantiles__ *data* *confidence*

    Return the quantiles for a given set of data

      * list *data*

        \- List of raw data values

      * float *confidence*

        \- Confidence level \(0\.95 or 0\.99 for instance\) or a list of confidence
        levels\.

  - <a name='23'></a>__::math::statistics::quantiles__ *limits* *counts* *confidence*

    Return the quantiles based on histogram information \(alternative to the call
    with two arguments\)

      * list *limits*

        \- List of upper limits from histogram

      * list *counts*

        \- List of counts for for each interval in histogram

      * float *confidence*

        \- Confidence level \(0\.95 or 0\.99 for instance\) or a list of confidence
        levels\.

  - <a name='24'></a>__::math::statistics::autocorr__ *data*

    Return the autocorrelation function as a list of values \(assuming
    equidistance between samples, about 1/2 of the number of raw data\)

    The correlation is determined in such a way that the first value is always 1
    and all others are equal to or smaller than 1\. The number of values involved
    will diminish as the "time" \(the index in the list of returned values\)
    increases

      * list *data*

        \- Raw data for which the autocorrelation must be determined

  - <a name='25'></a>__::math::statistics::crosscorr__ *data1* *data2*

    Return the cross\-correlation function as a list of values \(assuming
    equidistance between samples, about 1/2 of the number of raw data\)

    The correlation is determined in such a way that the values can never exceed
    1 in magnitude\. The number of values involved will diminish as the "time"
    \(the index in the list of returned values\) increases\.

      * list *data1*

        \- First list of data

      * list *data2*

        \- Second list of data

  - <a name='26'></a>__::math::statistics::mean\-histogram\-limits__ *mean* *stdev* *number*

    Determine reasonable limits based on mean and standard deviation for a
    histogram Convenience function \- the result is suitable for the histogram
    function\.

      * float *mean*

        \- Mean of the data

      * float *stdev*

        \- Standard deviation

      * int *number*

        \- Number of limits to generate \(defaults to 8\)

  - <a name='27'></a>__::math::statistics::minmax\-histogram\-limits__ *min* *max* *number*

    Determine reasonable limits based on a minimum and maximum for a histogram

    Convenience function \- the result is suitable for the histogram function\.

      * float *min*

        \- Expected minimum

      * float *max*

        \- Expected maximum

      * int *number*

        \- Number of limits to generate \(defaults to 8\)

  - <a name='28'></a>__::math::statistics::linear\-model__ *xdata* *ydata* *intercept*

    Determine the coefficients for a linear regression between two series of
    data \(the model: Y = A \+ B\*X\)\. Returns a list of parameters describing the
    fit

      * list *xdata*

        \- List of independent data

      * list *ydata*

        \- List of dependent data to be fitted

      * boolean *intercept*

        \- \(Optional\) compute the intercept \(1, default\) or fit to a line through
        the origin \(0\)

        The result consists of the following list:

          + \(Estimate of\) Intercept A

          + \(Estimate of\) Slope B

          + Standard deviation of Y relative to fit

          + Correlation coefficient R2

          + Number of degrees of freedom df

          + Standard error of the intercept A

          + Significance level of A

          + Standard error of the slope B

          + Significance level of B

  - <a name='29'></a>__::math::statistics::linear\-residuals__ *xdata* *ydata* *intercept*

    Determine the difference between actual data and predicted from the linear
    model\.

    Returns a list of the differences between the actual data and the predicted
    values\.

      * list *xdata*

        \- List of independent data

      * list *ydata*

        \- List of dependent data to be fitted

      * boolean *intercept*

        \- \(Optional\) compute the intercept \(1, default\) or fit to a line through
        the origin \(0\)

  - <a name='30'></a>__::math::statistics::test\-2x2__ *n11* *n21* *n12* *n22*

    Determine if two set of samples, each from a binomial distribution, differ
    significantly or not \(implying a different parameter\)\.

    Returns the "chi\-square" value, which can be used to the determine the
    significance\.

      * int *n11*

        \- Number of outcomes with the first value from the first sample\.

      * int *n21*

        \- Number of outcomes with the first value from the second sample\.

      * int *n12*

        \- Number of outcomes with the second value from the first sample\.

      * int *n22*

        \- Number of outcomes with the second value from the second sample\.

  - <a name='31'></a>__::math::statistics::print\-2x2__ *n11* *n21* *n12* *n22*

    Determine if two set of samples, each from a binomial distribution, differ
    significantly or not \(implying a different parameter\)\.

    Returns a short report, useful in an interactive session\.

      * int *n11*

        \- Number of outcomes with the first value from the first sample\.

      * int *n21*

        \- Number of outcomes with the first value from the second sample\.

      * int *n12*

        \- Number of outcomes with the second value from the first sample\.

      * int *n22*

        \- Number of outcomes with the second value from the second sample\.

  - <a name='32'></a>__::math::statistics::control\-xbar__ *data* ?nsamples?

    Determine the control limits for an xbar chart\. The number of data in each
    subsample defaults to 4\. At least 20 subsamples are required\.

    Returns the mean, the lower limit, the upper limit and the number of data
    per subsample\.

      * list *data*

        \- List of observed data

      * int *nsamples*

        \- Number of data per subsample

  - <a name='33'></a>__::math::statistics::control\-Rchart__ *data* ?nsamples?

    Determine the control limits for an R chart\. The number of data in each
    subsample \(nsamples\) defaults to 4\. At least 20 subsamples are required\.

    Returns the mean range, the lower limit, the upper limit and the number of
    data per subsample\.

      * list *data*

        \- List of observed data

      * int *nsamples*

        \- Number of data per subsample

  - <a name='34'></a>__::math::statistics::test\-xbar__ *control* *data*

    Determine if the data exceed the control limits for the xbar chart\.

    Returns a list of subsamples \(their indices\) that indeed violate the limits\.

      * list *control*

        \- Control limits as returned by the "control\-xbar" procedure

      * list *data*

        \- List of observed data

  - <a name='35'></a>__::math::statistics::test\-Rchart__ *control* *data*

    Determine if the data exceed the control limits for the R chart\.

    Returns a list of subsamples \(their indices\) that indeed violate the limits\.

      * list *control*

        \- Control limits as returned by the "control\-Rchart" procedure

      * list *data*

        \- List of observed data

  - <a name='36'></a>__::math::statistics::test\-Kruskal\-Wallis__ *confidence* *args*

    Check if the population medians of two or more groups are equal with a given
    confidence level, using the Kruskal\-Wallis test\.

      * float *confidence*

        \- Confidence level to be used \(0\-1\)

      * list *args*

        \- Two or more lists of data

  - <a name='37'></a>__::math::statistics::analyse\-Kruskal\-Wallis__ *args*

    Compute the statistical parameters for the Kruskal\-Wallis test\. Returns the
    Kruskal\-Wallis statistic and the probability that that value would occur
    assuming the medians of the populations are equal\.

      * list *args*

        \- Two or more lists of data

  - <a name='38'></a>__::math::statistics::test\-Levene__ *groups*

    Compute the Levene statistic to determine if groups of data have the same
    variance \(are homoscadastic\) or not\. The data are organised in groups\. This
    version uses the mean of the data as the measure to determine the
    deviations\. The statistic is equivalent to an F statistic with degrees of
    freedom k\-1 and N\-k, k being the number of groups and N the total number of
    data\.

      * list *groups*

        \- List of groups of data

  - <a name='39'></a>__::math::statistics::test\-Brown\-Forsythe__ *groups*

    Compute the Brown\-Forsythe statistic to determine if groups of data have the
    same variance \(are homoscadastic\) or not\. Like the Levene test, but this
    version uses the median of the data\.

      * list *groups*

        \- List of groups of data

  - <a name='40'></a>__::math::statistics::group\-rank__ *args*

    Rank the groups of data with respect to the complete set\. Returns a list
    consisting of the group ID, the value and the rank \(possibly a rational
    number, in case of ties\) for each data item\.

      * list *args*

        \- Two or more lists of data

  - <a name='41'></a>__::math::statistics::test\-Wilcoxon__ *sample\_a* *sample\_b*

    Compute the Wilcoxon test statistic to determine if two samples have the
    same median or not\. \(The statistic can be regarded as standard normal, if
    the sample sizes are both larger than 10\.\) Returns the value of this
    statistic\.

      * list *sample\_a*

        \- List of data comprising the first sample

      * list *sample\_b*

        \- List of data comprising the second sample

  - <a name='42'></a>__::math::statistics::spearman\-rank__ *sample\_a* *sample\_b*

    Return the Spearman rank correlation as an alternative to the ordinary
    \(Pearson's\) correlation coefficient\. The two samples should have the same
    number of data\.

      * list *sample\_a*

        \- First list of data

      * list *sample\_b*

        \- Second list of data

  - <a name='43'></a>__::math::statistics::spearman\-rank\-extended__ *sample\_a* *sample\_b*

    Return the Spearman rank correlation as an alternative to the ordinary
    \(Pearson's\) correlation coefficient as well as additional data\. The two
    samples should have the same number of data\. The procedure returns the
    correlation coefficient, the number of data pairs used and the z\-score, an
    approximately standard normal statistic, indicating the significance of the
    correlation\.

      * list *sample\_a*

        \- First list of data

      * list *sample\_b*

        \- Second list of data

  - <a name='44'></a>__::math::statistics::kernel\-density__ *data* opt *\-option value* \.\.\.

    Return the density function based on kernel density estimation\. The
    procedure is controlled by a small set of options, each of which is given a
    reasonable default\.

    The return value consists of three lists: the centres of the bins, the
    associated probability density and a list of computational parameters \(begin
    and end of the interval, mean and standard deviation and the used
    bandwidth\)\. The computational parameters can be used for further analysis\.

      * list *data*

        \- The data to be examined

      * list *args*

        \- Option\-value pairs:

          + __\-weights__ *weights*

            Per data point the weight \(default: 1 for all data\)

          + __\-bandwidth__ *value*

            Bandwidth to be used for the estimation \(default: determined from
            standard deviation\)

          + __\-number__ *value*

            Number of bins to be returned \(default: 100\)

          + __\-interval__ *\{begin end\}*

            Begin and end of the interval for which the density is returned
            \(default: mean \+/\- 3\*standard deviation\)

          + __\-kernel__ *function*

            Kernel to be used \(One of: gaussian, cosine, epanechnikov, uniform,
            triangular, biweight, logistic; default: gaussian\)

  - <a name='45'></a>__::math::statistics::bootstrap__ *data* *sampleSize* ?numberSamples?

    Create a subsample or subsamples from a given list of data\. The data in the
    samples are chosen from this list \- multiples may occur\. If there is only
    one subsample, the sample itself is returned \(as a list of "sampleSize"
    values\), otherwise a list of samples is returned\.

      * list *data*

        List of values to chose from

      * int *sampleSize*

        Number of values per sample

      * int *numberSamples*

        Number of samples \(default: 1\)

  - <a name='46'></a>__::math::statistics::wasserstein\-distance__ *prob1* *prob2*

    Compute the Wasserstein distance or earth mover's distance for two
    equidstantly spaced histograms or probability densities\. The histograms need
    not to be normalised to sum to one, but they must have the same number of
    entries\.

    Note: the histograms are assumed to be based on the same equidistant
    intervals\. As the bounds are not passed, the value is expressed in the
    length of the intervals\.

      * list *prob1*

        List of values for the first histogram/probability density

      * list *prob2*

        List of values for the second histogram/probability density

  - <a name='47'></a>__::math::statistics::kl\-divergence__ *prob1* *prob2*

    Compute the Kullback\-Leibler \(KL\) divergence for two equidstantly spaced
    histograms or probability densities\. The histograms need not to be
    normalised to sum to one, but they must have the same number of entries\.

    Note: the histograms are assumed to be based on the same equidistant
    intervals\. As the bounds are not passed, the value is expressed in the
    length of the intervals\.

    Note also that the KL divergence is not symmetric and that the second
    histogram should not contain zeroes in places where the first histogram has
    non\-zero values\.

      * list *prob1*

        List of values for the first histogram/probability density

      * list *prob2*

        List of values for the second histogram/probability density

  - <a name='48'></a>__::math::statistics::logistic\-model__ *xdata* *ydata*

    Estimate the coefficients of the logistic model that fits the data best\. The
    data consist of independent x\-values and the outcome 0 or 1 for each of the
    x\-values\. The result can be used to estimate the probability that a certain
    x\-value gives 1\.

      * list *xdata*

        List of values for which the success \(1\) or failure \(0\) is known

      * list *ydata*

        List of successes or failures corresponding to each value in *xdata*\.

  - <a name='49'></a>__::math::statistics::logistic\-probability__ *coeffs* *x*

    Calculate the probability of success for the value *x* given the
    coefficients of the logistic model\.

      * list *coeffs*

        List of coefficients as determine by the __logistic\-model__ command

      * float *x*

        X\-value for which the probability needs to be determined

# <a name='section3'></a>MULTIVARIATE LINEAR REGRESSION

Besides the linear regression with a single independent variable, the statistics
package provides two procedures for doing ordinary least squares \(OLS\) and
weighted least squares \(WLS\) linear regression with several variables\. They were
written by Eric Kemp\-Benedict\.

In addition to these two, it provides a procedure \(tstat\) for calculating the
value of the t\-statistic for the specified number of degrees of freedom that is
required to demonstrate a given level of significance\.

Note: These procedures depend on the math::linearalgebra package\.

*Description of the procedures*

  - <a name='50'></a>__::math::statistics::tstat__ *dof* ?alpha?

    Returns the value of the t\-distribution t\* satisfying

        P(t*)  =  1 - alpha/2
        P(-t*) =  alpha/2

    for the number of degrees of freedom dof\.

    Given a sample of normally\-distributed data x, with an estimate xbar for the
    mean and sbar for the standard deviation, the alpha confidence interval for
    the estimate of the mean can be calculated as

        ( xbar - t* sbar , xbar + t* sbar)

    The return values from this procedure can be compared to an estimated
    t\-statistic to determine whether the estimated value of a parameter is
    significantly different from zero at the given confidence level\.

      * int *dof*

        Number of degrees of freedom

      * float *alpha*

        Confidence level of the t\-distribution\. Defaults to 0\.05\.

  - <a name='51'></a>__::math::statistics::mv\-wls__ *wt1* *weights\_and\_values*

    Carries out a weighted least squares linear regression for the data points
    provided, with weights assigned to each point\.

    The linear model is of the form

        y = b0 + b1 * x1 + b2 * x2 ... + bN * xN + error

    and each point satisfies

        yi = b0 + b1 * xi1 + b2 * xi2 + ... + bN * xiN + Residual_i

    The procedure returns a list with the following elements:

      * The r\-squared statistic

      * The adjusted r\-squared statistic

      * A list containing the estimated coefficients b1, \.\.\. bN, b0 \(The
        constant b0 comes last in the list\.\)

      * A list containing the standard errors of the coefficients

      * A list containing the 95% confidence bounds of the coefficients, with
        each set of bounds returned as a list with two values

    Arguments:

      * list *weights\_and\_values*

        A list consisting of: the weight for the first observation, the data for
        the first observation \(as a sublist\), the weight for the second
        observation \(as a sublist\) and so on\. The sublists of data are organised
        as lists of the value of the dependent variable y and the independent
        variables x1, x2 to xN\.

  - <a name='52'></a>__::math::statistics::mv\-ols__ *values*

    Carries out an ordinary least squares linear regression for the data points
    provided\.

    This procedure simply calls ::mvlinreg::wls with the weights set to 1\.0, and
    returns the same information\.

*Example of the use:*

    # Store the value of the unicode value for the "+/-" character
    set pm "\u00B1"

    # Provide some data
    set data {{  -.67  14.18  60.03 -7.5  }
              { 36.97  15.52  34.24 14.61 }
              {-29.57  21.85  83.36 -7.   }
              {-16.9   11.79  51.67 -6.56 }
              { 14.09  16.24  36.97 -12.84}
              { 31.52  20.93  45.99 -25.4 }
              { 24.05  20.69  50.27  17.27}
              { 22.23  16.91  45.07  -4.3 }
              { 40.79  20.49  38.92  -.73 }
              {-10.35  17.24  58.77  18.78}}

    # Call the ols routine
    set results [::math::statistics::mv-ols $data]

    # Pretty-print the results
    puts "R-squared: [lindex $results 0]"
    puts "Adj R-squared: [lindex $results 1]"
    puts "Coefficients $pm s.e. -- \[95% confidence interval\]:"
    foreach val [lindex $results 2] se [lindex $results 3] bounds [lindex $results 4] {
        set lb [lindex $bounds 0]
        set ub [lindex $bounds 1]
        puts "   $val $pm $se -- \[$lb to $ub\]"
    }

# <a name='section4'></a>STATISTICAL DISTRIBUTIONS

In the literature a large number of probability distributions can be found\. The
statistics package supports:

  - The normal or Gaussian distribution as well as the log\-normal distribution

  - The uniform distribution \- equal probability for all data within a given
    interval

  - The exponential distribution \- useful as a model for certain extreme\-value
    distributions\.

  - The gamma distribution \- based on the incomplete Gamma integral

  - The beta distribution

  - The chi\-square distribution

  - The student's T distribution

  - The Poisson distribution

  - The Pareto distribution

  - The Gumbel distribution

  - The Weibull distribution

  - The Cauchy distribution

  - The F distribution \(only the cumulative density function\)

  - PM \- binomial\.

In principle for each distribution one has procedures for:

  - The probability density \(pdf\-\*\)

  - The cumulative density \(cdf\-\*\)

  - Quantiles for the given distribution \(quantiles\-\*\)

  - Histograms for the given distribution \(histogram\-\*\)

  - List of random values with the given distribution \(random\-\*\)

The following procedures have been implemented:

  - <a name='53'></a>__::math::statistics::pdf\-normal__ *mean* *stdev* *value*

    Return the probability of a given value for a normal distribution with given
    mean and standard deviation\.

      * float *mean*

        \- Mean value of the distribution

      * float *stdev*

        \- Standard deviation of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='54'></a>__::math::statistics::pdf\-lognormal__ *mean* *stdev* *value*

    Return the probability of a given value for a log\-normal distribution with
    given mean and standard deviation\.

      * float *mean*

        \- Mean value of the distribution

      * float *stdev*

        \- Standard deviation of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='55'></a>__::math::statistics::pdf\-exponential__ *mean* *value*

    Return the probability of a given value for an exponential distribution with
    given mean\.

      * float *mean*

        \- Mean value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='56'></a>__::math::statistics::pdf\-uniform__ *xmin* *xmax* *value*

    Return the probability of a given value for a uniform distribution with
    given extremes\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmin*

        \- Maximum value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='57'></a>__::math::statistics::pdf\-triangular__ *xmin* *xmax* *value*

    Return the probability of a given value for a triangular distribution with
    given extremes\. If the argument min is lower than the argument max, then
    smaller values have higher probability and vice versa\. In the first case the
    probability density function is of the form *f\(x\) = 2\(1\-x\)* and the other
    case it is of the form *f\(x\) = 2x*\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmin*

        \- Maximum value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='58'></a>__::math::statistics::pdf\-symmetric\-triangular__ *xmin* *xmax* *value*

    Return the probability of a given value for a symmetric triangular
    distribution with given extremes\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmin*

        \- Maximum value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='59'></a>__::math::statistics::pdf\-gamma__ *alpha* *beta* *value*

    Return the probability of a given value for a Gamma distribution with given
    shape and rate parameters

      * float *alpha*

        \- Shape parameter

      * float *beta*

        \- Rate parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='60'></a>__::math::statistics::pdf\-poisson__ *mu* *k*

    Return the probability of a given number of occurrences in the same interval
    \(k\) for a Poisson distribution with given mean \(mu\)

      * float *mu*

        \- Mean number of occurrences

      * int *k*

        \- Number of occurences

  - <a name='61'></a>__::math::statistics::pdf\-chisquare__ *df* *value*

    Return the probability of a given value for a chi square distribution with
    given degrees of freedom

      * float *df*

        \- Degrees of freedom

      * float *value*

        \- Value for which the probability is required

  - <a name='62'></a>__::math::statistics::pdf\-student\-t__ *df* *value*

    Return the probability of a given value for a Student's t distribution with
    given degrees of freedom

      * float *df*

        \- Degrees of freedom

      * float *value*

        \- Value for which the probability is required

  - <a name='63'></a>__::math::statistics::pdf\-gamma__ *a* *b* *value*

    Return the probability of a given value for a Gamma distribution with given
    shape and rate parameters

      * float *a*

        \- Shape parameter

      * float *b*

        \- Rate parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='64'></a>__::math::statistics::pdf\-beta__ *a* *b* *value*

    Return the probability of a given value for a Beta distribution with given
    shape parameters

      * float *a*

        \- First shape parameter

      * float *b*

        \- Second shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='65'></a>__::math::statistics::pdf\-weibull__ *scale* *shape* *value*

    Return the probability of a given value for a Weibull distribution with
    given scale and shape parameters

      * float *location*

        \- Scale parameter

      * float *scale*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='66'></a>__::math::statistics::pdf\-gumbel__ *location* *scale* *value*

    Return the probability of a given value for a Gumbel distribution with given
    location and shape parameters

      * float *location*

        \- Location parameter

      * float *scale*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='67'></a>__::math::statistics::pdf\-pareto__ *scale* *shape* *value*

    Return the probability of a given value for a Pareto distribution with given
    scale and shape parameters

      * float *scale*

        \- Scale parameter

      * float *shape*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='68'></a>__::math::statistics::pdf\-cauchy__ *location* *scale* *value*

    Return the probability of a given value for a Cauchy distribution with given
    location and shape parameters\. Note that the Cauchy distribution has no
    finite higher\-order moments\.

      * float *location*

        \- Location parameter

      * float *scale*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='69'></a>__::math::statistics::pdf\-laplace__ *location* *scale* *value*

    Return the probability of a given value for a Laplace distribution with
    given location and shape parameters\. The Laplace distribution consists of
    two exponential functions, is peaked and has heavier tails than the normal
    distribution\.

      * float *location*

        \- Location parameter \(mean\)

      * float *scale*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='70'></a>__::math::statistics::pdf\-kumaraswamy__ *a* *b* *value*

    Return the probability of a given value for a Kumaraswamy distribution with
    given parameters a and b\. The Kumaraswamy distribution is related to the
    Beta distribution, but has a tractable cumulative distribution function\.

      * float *a*

        \- Parameter a

      * float *b*

        \- Parameter b

      * float *value*

        \- Value for which the probability is required

  - <a name='71'></a>__::math::statistics::pdf\-negative\-binomial__ *r* *p* *value*

    Return the probability of a given value for a negative binomial distribution
    with an allowed number of failures and the probability of success\.

      * int *r*

        \- Allowed number of failures \(at least 1\)

      * float *p*

        \- Probability of success

      * int *value*

        \- Number of successes for which the probability is to be returned

  - <a name='72'></a>__::math::statistics::cdf\-normal__ *mean* *stdev* *value*

    Return the cumulative probability of a given value for a normal distribution
    with given mean and standard deviation, that is the probability for values
    up to the given one\.

      * float *mean*

        \- Mean value of the distribution

      * float *stdev*

        \- Standard deviation of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='73'></a>__::math::statistics::cdf\-lognormal__ *mean* *stdev* *value*

    Return the cumulative probability of a given value for a log\-normal
    distribution with given mean and standard deviation, that is the probability
    for values up to the given one\.

      * float *mean*

        \- Mean value of the distribution

      * float *stdev*

        \- Standard deviation of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='74'></a>__::math::statistics::cdf\-exponential__ *mean* *value*

    Return the cumulative probability of a given value for an exponential
    distribution with given mean\.

      * float *mean*

        \- Mean value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='75'></a>__::math::statistics::cdf\-uniform__ *xmin* *xmax* *value*

    Return the cumulative probability of a given value for a uniform
    distribution with given extremes\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmin*

        \- Maximum value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='76'></a>__::math::statistics::cdf\-triangular__ *xmin* *xmax* *value*

    Return the cumulative probability of a given value for a triangular
    distribution with given extremes\. If xmin < xmax, then lower values have a
    higher probability and vice versa, see also *pdf\-triangular*

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmin*

        \- Maximum value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='77'></a>__::math::statistics::cdf\-symmetric\-triangular__ *xmin* *xmax* *value*

    Return the cumulative probability of a given value for a symmetric
    triangular distribution with given extremes\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmin*

        \- Maximum value of the distribution

      * float *value*

        \- Value for which the probability is required

  - <a name='78'></a>__::math::statistics::cdf\-students\-t__ *degrees* *value*

    Return the cumulative probability of a given value for a Student's t
    distribution with given number of degrees\.

      * int *degrees*

        \- Number of degrees of freedom

      * float *value*

        \- Value for which the probability is required

  - <a name='79'></a>__::math::statistics::cdf\-gamma__ *alpha* *beta* *value*

    Return the cumulative probability of a given value for a Gamma distribution
    with given shape and rate parameters\.

      * float *alpha*

        \- Shape parameter

      * float *beta*

        \- Rate parameter

      * float *value*

        \- Value for which the cumulative probability is required

  - <a name='80'></a>__::math::statistics::cdf\-poisson__ *mu* *k*

    Return the cumulative probability of a given number of occurrences in the
    same interval \(k\) for a Poisson distribution with given mean \(mu\)\.

      * float *mu*

        \- Mean number of occurrences

      * int *k*

        \- Number of occurences

  - <a name='81'></a>__::math::statistics::cdf\-beta__ *a* *b* *value*

    Return the cumulative probability of a given value for a Beta distribution
    with given shape parameters

      * float *a*

        \- First shape parameter

      * float *b*

        \- Second shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='82'></a>__::math::statistics::cdf\-weibull__ *scale* *shape* *value*

    Return the cumulative probability of a given value for a Weibull
    distribution with given scale and shape parameters\.

      * float *scale*

        \- Scale parameter

      * float *shape*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='83'></a>__::math::statistics::cdf\-gumbel__ *location* *scale* *value*

    Return the cumulative probability of a given value for a Gumbel distribution
    with given location and scale parameters\.

      * float *location*

        \- Location parameter

      * float *scale*

        \- Scale parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='84'></a>__::math::statistics::cdf\-pareto__ *scale* *shape* *value*

    Return the cumulative probability of a given value for a Pareto distribution
    with given scale and shape parameters

      * float *scale*

        \- Scale parameter

      * float *shape*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='85'></a>__::math::statistics::cdf\-cauchy__ *location* *scale* *value*

    Return the cumulative probability of a given value for a Cauchy distribution
    with given location and scale parameters\.

      * float *location*

        \- Location parameter

      * float *scale*

        \- Scale parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='86'></a>__::math::statistics::cdf\-F__ *nf1* *nf2* *value*

    Return the cumulative probability of a given value for an F distribution
    with nf1 and nf2 degrees of freedom\.

      * float *nf1*

        \- Degrees of freedom for the numerator

      * float *nf2*

        \- Degrees of freedom for the denominator

      * float *value*

        \- Value for which the probability is required

  - <a name='87'></a>__::math::statistics::cdf\-laplace__ *location* *scale* *value*

    Return the cumulative probability of a given value for a Laplace
    distribution with given location and shape parameters\. The Laplace
    distribution consists of two exponential functions, is peaked and has
    heavier tails than the normal distribution\.

      * float *location*

        \- Location parameter \(mean\)

      * float *scale*

        \- Shape parameter

      * float *value*

        \- Value for which the probability is required

  - <a name='88'></a>__::math::statistics::cdf\-kumaraswamy__ *a* *b* *value*

    Return the cumulative probability of a given value for a Kumaraswamy
    distribution with given parameters a and b\. The Kumaraswamy distribution is
    related to the Beta distribution, but has a tractable cumulative
    distribution function\.

      * float *a*

        \- Parameter a

      * float *b*

        \- Parameter b

      * float *value*

        \- Value for which the probability is required

  - <a name='89'></a>__::math::statistics::cdf\-negative\-binomial__ *r* *p* *value*

    Return the cumulative probability of a given value for a negative binomial
    distribution with an allowed number of failures and the probability of
    success\.

      * int *r*

        \- Allowed number of failures \(at least 1\)

      * float *p*

        \- Probability of success

      * int *value*

        \- Greatest number of successes

  - <a name='90'></a>__::math::statistics::empirical\-distribution__ *values*

    Return a list of values and their empirical probability\. The values are
    sorted in increasing order\. \(The implementation follows the description at
    the corresponding Wikipedia page\)

      * list *values*

        \- List of data to be examined

  - <a name='91'></a>__::math::statistics::random\-normal__ *mean* *stdev* *number*

    Return a list of "number" random values satisfying a normal distribution
    with given mean and standard deviation\.

      * float *mean*

        \- Mean value of the distribution

      * float *stdev*

        \- Standard deviation of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='92'></a>__::math::statistics::random\-lognormal__ *mean* *stdev* *number*

    Return a list of "number" random values satisfying a log\-normal distribution
    with given mean and standard deviation\.

      * float *mean*

        \- Mean value of the distribution

      * float *stdev*

        \- Standard deviation of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='93'></a>__::math::statistics::random\-exponential__ *mean* *number*

    Return a list of "number" random values satisfying an exponential
    distribution with given mean\.

      * float *mean*

        \- Mean value of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='94'></a>__::math::statistics::random\-uniform__ *xmin* *xmax* *number*

    Return a list of "number" random values satisfying a uniform distribution
    with given extremes\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmax*

        \- Maximum value of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='95'></a>__::math::statistics::random\-triangular__ *xmin* *xmax* *number*

    Return a list of "number" random values satisfying a triangular distribution
    with given extremes\. If xmin < xmax, then lower values have a higher
    probability and vice versa \(see also *pdf\-triangular*\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmax*

        \- Maximum value of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='96'></a>__::math::statistics::random\-symmetric\-triangular__ *xmin* *xmax* *number*

    Return a list of "number" random values satisfying a symmetric triangular
    distribution with given extremes\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmax*

        \- Maximum value of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='97'></a>__::math::statistics::random\-gamma__ *alpha* *beta* *number*

    Return a list of "number" random values satisfying a Gamma distribution with
    given shape and rate parameters\.

      * float *alpha*

        \- Shape parameter

      * float *beta*

        \- Rate parameter

      * int *number*

        \- Number of values to be returned

  - <a name='98'></a>__::math::statistics::random\-poisson__ *mu* *number*

    Return a list of "number" random values satisfying a Poisson distribution
    with given mean\.

      * float *mu*

        \- Mean of the distribution

      * int *number*

        \- Number of values to be returned

  - <a name='99'></a>__::math::statistics::random\-chisquare__ *df* *number*

    Return a list of "number" random values satisfying a chi square distribution
    with given degrees of freedom\.

      * float *df*

        \- Degrees of freedom

      * int *number*

        \- Number of values to be returned

  - <a name='100'></a>__::math::statistics::random\-student\-t__ *df* *number*

    Return a list of "number" random values satisfying a Student's t
    distribution with given degrees of freedom\.

      * float *df*

        \- Degrees of freedom

      * int *number*

        \- Number of values to be returned

  - <a name='101'></a>__::math::statistics::random\-beta__ *a* *b* *number*

    Return a list of "number" random values satisfying a Beta distribution with
    given shape parameters\.

      * float *a*

        \- First shape parameter

      * float *b*

        \- Second shape parameter

      * int *number*

        \- Number of values to be returned

  - <a name='102'></a>__::math::statistics::random\-weibull__ *scale* *shape* *number*

    Return a list of "number" random values satisfying a Weibull distribution
    with given scale and shape parameters\.

      * float *scale*

        \- Scale parameter

      * float *shape*

        \- Shape parameter

      * int *number*

        \- Number of values to be returned

  - <a name='103'></a>__::math::statistics::random\-gumbel__ *location* *scale* *number*

    Return a list of "number" random values satisfying a Gumbel distribution
    with given location and scale parameters\.

      * float *location*

        \- Location parameter

      * float *scale*

        \- Scale parameter

      * int *number*

        \- Number of values to be returned

  - <a name='104'></a>__::math::statistics::random\-pareto__ *scale* *shape* *number*

    Return a list of "number" random values satisfying a Pareto distribution
    with given scale and shape parameters\.

      * float *scale*

        \- Scale parameter

      * float *shape*

        \- Shape parameter

      * int *number*

        \- Number of values to be returned

  - <a name='105'></a>__::math::statistics::random\-cauchy__ *location* *scale* *number*

    Return a list of "number" random values satisfying a Cauchy distribution
    with given location and scale parameters\.

      * float *location*

        \- Location parameter

      * float *scale*

        \- Scale parameter

      * int *number*

        \- Number of values to be returned

  - <a name='106'></a>__::math::statistics::random\-laplace__ *location* *scale* *number*

    Return a list of "number" random values satisfying a Laplace distribution
    with given location and shape parameters\. The Laplace distribution consists
    of two exponential functions, is peaked and has heavier tails than the
    normal distribution\.

      * float *location*

        \- Location parameter \(mean\)

      * float *scale*

        \- Shape parameter

      * int *number*

        \- Number of values to be returned

  - <a name='107'></a>__::math::statistics::random\-kumaraswamy__ *a* *b* *number*

    Return a list of "number" random values satisying a Kumaraswamy distribution
    with given parameters a and b\. The Kumaraswamy distribution is related to
    the Beta distribution, but has a tractable cumulative distribution function\.

      * float *a*

        \- Parameter a

      * float *b*

        \- Parameter b

      * int *number*

        \- Number of values to be returned

  - <a name='108'></a>__::math::statistics::random\-negative\-binomial__ *r* *p* *number*

    Return a list of "number" random values satisying a negative binomial
    distribution\.

      * int *r*

        \- Allowed number of failures \(at least 1\)

      * float *p*

        \- Probability of success

      * int *number*

        \- Number of values to be returned

  - <a name='109'></a>__::math::statistics::histogram\-uniform__ *xmin* *xmax* *limits* *number*

    Return the expected histogram for a uniform distribution\.

      * float *xmin*

        \- Minimum value of the distribution

      * float *xmax*

        \- Maximum value of the distribution

      * list *limits*

        \- Upper limits for the buckets in the histogram

      * int *number*

        \- Total number of "observations" in the histogram

  - <a name='110'></a>__::math::statistics::incompleteGamma__ *x* *p* ?tol?

    Evaluate the incomplete Gamma integral

                  1       / x               p-1
    P(p,x) =  --------   |   dt exp(-t) * t
              Gamma(p)  / 0

      * float *x*

        \- Value of x \(limit of the integral\)

      * float *p*

        \- Value of p in the integrand

      * float *tol*

        \- Required tolerance \(default: 1\.0e\-9\)

  - <a name='111'></a>__::math::statistics::incompleteBeta__ *a* *b* *x* ?tol?

    Evaluate the incomplete Beta integral

      * float *a*

        \- First shape parameter

      * float *b*

        \- Second shape parameter

      * float *x*

        \- Value of x \(limit of the integral\)

      * float *tol*

        \- Required tolerance \(default: 1\.0e\-9\)

  - <a name='112'></a>__::math::statistics::estimate\-pareto__ *values*

    Estimate the parameters for the Pareto distribution that comes closest to
    the given values\. Returns the estimated scale and shape parameters, as well
    as the standard error for the shape parameter\.

      * list *values*

        \- List of values, assumed to be distributed according to a Pareto
        distribution

  - <a name='113'></a>__::math::statistics::estimate\-exponential__ *values*

    Estimate the parameter for the exponential distribution that comes closest
    to the given values\. Returns an estimate of the one parameter and of the
    standard error\.

      * list *values*

        \- List of values, assumed to be distributed according to an exponential
        distribution

  - <a name='114'></a>__::math::statistics::estimate\-laplace__ *values*

    Estimate the parameters for the Laplace distribution that comes closest to
    the given values\. Returns an estimate of respectively the location and scale
    parameters, based on maximum likelihood\.

      * list *values*

        \- List of values, assumed to be distributed according to an exponential
        distribution

  - <a name='115'></a>__::math::statistics::estimante\-negative\-binomial__ *r* *values*

    Estimate the probability of success for the negative binomial distribution
    that comes closest to the given values\. The allowed number of failures must
    be given\.

      * int *r*

        \- Allowed number of failures \(at least 1\)

      * int *number*

        \- List of values, assumed to be distributed according to a negative
        binomial distribution\.

TO DO: more function descriptions to be added

# <a name='section5'></a>DATA MANIPULATION

The data manipulation procedures act on lists or lists of lists:

  - <a name='116'></a>__::math::statistics::filter__ *varname* *data* *expression*

    Return a list consisting of the data for which the logical expression is
    true \(this command works analogously to the command
    __[foreach](\.\./\.\./\.\./\.\./index\.md\#foreach)__\)\.

      * string *varname*

        \- Name of the variable used in the expression

      * list *data*

        \- List of data

      * string *expression*

        \- Logical expression using the variable name

  - <a name='117'></a>__::math::statistics::map__ *varname* *data* *expression*

    Return a list consisting of the data that are transformed via the
    expression\.

      * string *varname*

        \- Name of the variable used in the expression

      * list *data*

        \- List of data

      * string *expression*

        \- Expression to be used to transform \(map\) the data

  - <a name='118'></a>__::math::statistics::samplescount__ *varname* *list* *expression*

    Return a list consisting of the *counts* of all data in the sublists of
    the "list" argument for which the expression is true\.

      * string *varname*

        \- Name of the variable used in the expression

      * list *data*

        \- List of sublists, each containing the data

      * string *expression*

        \- Logical expression to test the data \(defaults to "true"\)\.

  - <a name='119'></a>__::math::statistics::subdivide__

    Routine *PM* \- not implemented yet

# <a name='section6'></a>PLOT PROCEDURES

The following simple plotting procedures are available:

  - <a name='120'></a>__::math::statistics::plot\-scale__ *canvas* *xmin* *xmax* *ymin* *ymax*

    Set the scale for a plot in the given canvas\. All plot routines expect this
    function to be called first\. There is no automatic scaling provided\.

      * widget *canvas*

        \- Canvas widget to use

      * float *xmin*

        \- Minimum x value

      * float *xmax*

        \- Maximum x value

      * float *ymin*

        \- Minimum y value

      * float *ymax*

        \- Maximum y value

  - <a name='121'></a>__::math::statistics::plot\-xydata__ *canvas* *xdata* *ydata* *tag*

    Create a simple XY plot in the given canvas \- the data are shown as a
    collection of dots\. The tag can be used to manipulate the appearance\.

      * widget *canvas*

        \- Canvas widget to use

      * float *xdata*

        \- Series of independent data

      * float *ydata*

        \- Series of dependent data

      * string *tag*

        \- Tag to give to the plotted data \(defaults to xyplot\)

  - <a name='122'></a>__::math::statistics::plot\-xyline__ *canvas* *xdata* *ydata* *tag*

    Create a simple XY plot in the given canvas \- the data are shown as a line
    through the data points\. The tag can be used to manipulate the appearance\.

      * widget *canvas*

        \- Canvas widget to use

      * list *xdata*

        \- Series of independent data

      * list *ydata*

        \- Series of dependent data

      * string *tag*

        \- Tag to give to the plotted data \(defaults to xyplot\)

  - <a name='123'></a>__::math::statistics::plot\-tdata__ *canvas* *tdata* *tag*

    Create a simple XY plot in the given canvas \- the data are shown as a
    collection of dots\. The horizontal coordinate is equal to the index\. The tag
    can be used to manipulate the appearance\. This type of presentation is
    suitable for autocorrelation functions for instance or for inspecting the
    time\-dependent behaviour\.

      * widget *canvas*

        \- Canvas widget to use

      * list *tdata*

        \- Series of dependent data

      * string *tag*

        \- Tag to give to the plotted data \(defaults to xyplot\)

  - <a name='124'></a>__::math::statistics::plot\-tline__ *canvas* *tdata* *tag*

    Create a simple XY plot in the given canvas \- the data are shown as a line\.
    See plot\-tdata for an explanation\.

      * widget *canvas*

        \- Canvas widget to use

      * list *tdata*

        \- Series of dependent data

      * string *tag*

        \- Tag to give to the plotted data \(defaults to xyplot\)

  - <a name='125'></a>__::math::statistics::plot\-histogram__ *canvas* *counts* *limits* *tag*

    Create a simple histogram in the given canvas

      * widget *canvas*

        \- Canvas widget to use

      * list *counts*

        \- Series of bucket counts

      * list *limits*

        \- Series of upper limits for the buckets

      * string *tag*

        \- Tag to give to the plotted data \(defaults to xyplot\)

# <a name='section7'></a>THINGS TO DO

The following procedures are yet to be implemented:

  - F\-test\-stdev

  - interval\-mean\-stdev

  - histogram\-normal

  - histogram\-exponential

  - test\-histogram

  - test\-corr

  - quantiles\-\*

  - fourier\-coeffs

  - fourier\-residuals

  - onepar\-function\-fit

  - onepar\-function\-residuals

  - plot\-linear\-model

  - subdivide

# <a name='section8'></a>EXAMPLES

The code below is a small example of how you can examine a set of data:

    # Simple example:
    # - Generate data (as a cheap way of getting some)
    # - Perform statistical analysis to describe the data
    #
    package require math::statistics

    #
    # Two auxiliary procs
    #
    proc pause {time} {
       set wait 0
       after [expr {$time*1000}] {set ::wait 1}
       vwait wait
    }

    proc print-histogram {counts limits} {
       foreach count $counts limit $limits {
          if { $limit != {} } {
             puts [format "<%12.4g\t%d" $limit $count]
             set prev_limit $limit
          } else {
             puts [format ">%12.4g\t%d" $prev_limit $count]
          }
       }
    }

    #
    # Our source of arbitrary data
    #
    proc generateData { data1 data2 } {
       upvar 1 $data1 _data1
       upvar 1 $data2 _data2

       set d1 0.0
       set d2 0.0
       for { set i 0 } { $i < 100 } { incr i } {
          set d1 [expr {10.0-2.0*cos(2.0*3.1415926*$i/24.0)+3.5*rand()}]
          set d2 [expr {0.7*$d2+0.3*$d1+0.7*rand()}]
          lappend _data1 $d1
          lappend _data2 $d2
       }
       return {}
    }

    #
    # The analysis session
    #
    package require Tk
    console show
    canvas .plot1
    canvas .plot2
    pack   .plot1 .plot2 -fill both -side top

    generateData data1 data2

    puts "Basic statistics:"
    set b1 [::math::statistics::basic-stats $data1]
    set b2 [::math::statistics::basic-stats $data2]
    foreach label {mean min max number stdev var} v1 $b1 v2 $b2 {
       puts "$label\t$v1\t$v2"
    }
    puts "Plot the data as function of \"time\" and against each other"
    ::math::statistics::plot-scale .plot1  0 100  0 20
    ::math::statistics::plot-scale .plot2  0 20   0 20
    ::math::statistics::plot-tline .plot1 $data1
    ::math::statistics::plot-tline .plot1 $data2
    ::math::statistics::plot-xydata .plot2 $data1 $data2

    puts "Correlation coefficient:"
    puts [::math::statistics::corr $data1 $data2]

    pause 2
    puts "Plot histograms"
    .plot2 delete all
    ::math::statistics::plot-scale .plot2  0 20 0 100
    set limits         [::math::statistics::minmax-histogram-limits 7 16]
    set histogram_data [::math::statistics::histogram $limits $data1]
    ::math::statistics::plot-histogram .plot2 $histogram_data $limits

    puts "First series:"
    print-histogram $histogram_data $limits

    pause 2
    set limits         [::math::statistics::minmax-histogram-limits 0 15 10]
    set histogram_data [::math::statistics::histogram $limits $data2]
    ::math::statistics::plot-histogram .plot2 $histogram_data $limits d2
    .plot2 itemconfigure d2 -fill red

    puts "Second series:"
    print-histogram $histogram_data $limits

    puts "Autocorrelation function:"
    set  autoc [::math::statistics::autocorr $data1]
    puts [::math::statistics::map $autoc {[format "%.2f" $x]}]
    puts "Cross-correlation function:"
    set  crossc [::math::statistics::crosscorr $data1 $data2]
    puts [::math::statistics::map $crossc {[format "%.2f" $x]}]

    ::math::statistics::plot-scale .plot1  0 100 -1  4
    ::math::statistics::plot-tline .plot1  $autoc "autoc"
    ::math::statistics::plot-tline .plot1  $crossc "crossc"
    .plot1 itemconfigure autoc  -fill green
    .plot1 itemconfigure crossc -fill yellow

    puts "Quantiles: 0.1, 0.2, 0.5, 0.8, 0.9"
    puts "First:  [::math::statistics::quantiles $data1 {0.1 0.2 0.5 0.8 0.9}]"
    puts "Second: [::math::statistics::quantiles $data2 {0.1 0.2 0.5 0.8 0.9}]"

If you run this example, then the following should be clear:

  - There is a strong correlation between two time series, as displayed by the
    raw data and especially by the correlation functions\.

  - Both time series show a significant periodic component

  - The histograms are not very useful in identifying the nature of the time
    series \- they do not show the periodic nature\.

# <a name='section9'></a>Bugs, Ideas, Feedback

This document, and the package it describes, will undoubtedly contain bugs and
other problems\. Please report such in the category *math :: statistics* of the
[Tcllib Trackers](http://core\.tcl\.tk/tcllib/reportlist)\. Please also report
any ideas for enhancements you may have for either package and/or documentation\.

When proposing code changes, please provide *unified diffs*, i\.e the output of
__diff \-u__\.

Note further that *attachments* are strongly preferred over inlined patches\.
Attachments can be made by going to the __Edit__ form of the ticket
immediately after its creation, and then using the left\-most button in the
secondary navigation bar\.

# <a name='keywords'></a>KEYWORDS

[data analysis](\.\./\.\./\.\./\.\./index\.md\#data\_analysis),
[mathematics](\.\./\.\./\.\./\.\./index\.md\#mathematics),
[statistics](\.\./\.\./\.\./\.\./index\.md\#statistics)

# <a name='category'></a>CATEGORY

Mathematics
