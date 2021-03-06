{smcl}
{* *! version 2.1  David Fisher  14sep2017}{...}
{vieweralsosee "ipdmetan" "help ipdmetan"}{...}
{vieweralsosee "forestplot" "help forestplot"}{...}
{vieweralsosee "metan" "help metan"}{...}
{vieweralsosee "admetan" "help admetan"}{...}
{vieweralsosee "admetani" "help admetani"}{...}
{viewerjumpto "Syntax" "ipdover##syntax"}{...}
{viewerjumpto "Description" "ipdover##description"}{...}
{viewerjumpto "Options" "ipdover##options"}{...}
{viewerjumpto "Saved results" "ipdover##saved_results"}{...}
{title:Title}

{phang}
{cmd:ipdover} {hline 2} Generate data for forest plots outside of the context of meta-analysis


{marker syntax}{...}
{title:Syntax}

{phang}
Syntax 1: {it:command}-based syntax; "generic" effect measure

{p 8 18 2}
{cmd:ipdover}
	[{it:{help exp_list}}]
	{cmd:, over(}{it:over_varlist} [{cmd:, {ul:m}issing}]{cmd:)} [{cmd: over(}{it:varname} [{cmd:, {ul:m}issing}]{cmd:)} {it:options}] {cmd::} {it:command} {ifin} {it:...}

{phang}
Syntax 2: {bf:{help collapse}}-based syntax; "specific" effect measure

{p 8 18 2}
{cmd:ipdover}
	{it:input_varlist} {ifin}
	{cmd:, over(}{it:over_varlist} [{cmd:, {ul:m}issing}]{cmd:)} [{cmd: over(}{it:varname} [{cmd:, {ul:m}issing}]{cmd:)} {it:options}]

{pstd}
where {it:input_varlist} is one of the following:

{p 8 34 2}{it:var_outcome} {it:var_treat}{space 11}where {it:var_outcome} and {it:var_treat} are both binary 0, 1{p_end}
{p 8 34 2}{it:var_outcome} {it:var_treat}{space 11}where {it:var_outcome} is continuous and {it:var_treat} is binary 0, 1{p_end}
{p 8 34 2}{it:var_treat}{space 23}where {it:var_treat} is binary 0, 1 and the data have previously been {bf:{help stset}}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ipdover} extends the functionality of {bf:{help ipdmetan}} outside the context of meta-analysis.
It does not perform any pooling or heterogeneity calculations;
rather, its intended use is creating forest plots of subgroup analyses within a single trial dataset.
Basic syntaxes are the same as for {bf:{help ipdmetan}}, but with {opt over(varlist)} replacing {opt study(varname)}.
Where {cmd:ipdmetan} summarises data by study, {cmd:ipdover} summarises data within each level of each variable in {it:varlist}.
The optional second {opt over(varname)} allows stratification of results by a further single variable,
in a similar way to {opt by(varname)} with {cmd:ipdmetan}.

{pstd}
Forest plots produced by {cmd:ipdover} are weighted by sample size rather than by the inverse of the variance,
and by default sample size will appear to the left of the plot
(instead of study weights appearing to the right of the plot as in {cmd:ipdmetan}).

{pstd}
Saved datasets (see {bf:{help ipdmetan}}) include the following identifier variables:{p_end}
{p2colset 8 24 24 8}
{p2col:{cmd:_BY}}subset of data (c.f. {help by}) as supplied to second {opt over()} option, if applicable{p_end}
{p2col:{cmd:_OVER}}identifier of variable within {it:over_varlist}{p_end}
{p2col:{cmd:_LEVEL}}level (category) of variable identified by {cmd:_OVER}.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Options specific to ipdover}

{phang}
{cmd:over(}{it:varlist} [{cmd:, missing}]{cmd:)} [{cmd: over(}{it:varname} [{cmd:, missing}]{cmd:)}] specifies the variable(s) whose levels {it:command} is to be fitted within.
The option may be repeated at most once, in which case the second option must contain a single {it:varname} defining
subsets of the data (c.f. {help by}).

{pmore} All variables must be either integer-valued or string.
Variable and value labels will appear in output where appropriate.

{pmore}
{opt missing} requests that missing values be treated as potential subgroups or subsets (the default is to exclude them).

{phang}
{cmd:plotid(_BY | _OVER | _LEVEL | _n} [{cmd:, list nograph}]{cmd:)} functions in basically the same way as in {bf:{help ipdmetan}},
but instead of a {it:varname}, it accepts one of the following values, corresponding to variables created in saved
datasets created by {cmd:ipdover}:{p_end}
{p2colset 8 24 24 8}
{p2col:{cmd:_BY}}group observations by levels of {cmd:_BY}{p_end}
{p2col:{cmd:_OVER}}group observations by levels of {cmd:_OVER}{p_end}
{p2col:{cmd:_LEVEL}}group observations by levels of {cmd:_LEVEL}{p_end}
{p2col:{cmd:_n}}allow each observation to be its own group.{p_end}

{pstd}Most other options as described for {bf:{help ipdmetan##options:ipdmetan}}, {bf:{help admetan##options:admetan}}
or {bf:{help forestplot##options:forestplot}} may also be supplied to {cmd:ipdover},
with the exception of options concerning heterogeneity statistics or pooled results
such as {opt cumulative}, {opt influence}, {opt interaction}, {opt qe()} and {opt re()}.
(However, note that {opt poolvar()} {ul:is} allowed (with Syntax 1), since it refers to the coefficient to be extracted
from each model fit rather than to the pooled result {it:per se}.)


{marker saved_results}{...}
{title:Saved results}

{pstd}{cmd:ipdover} saves the following in {cmd:r()}:{p_end}
{pstd}(in addition to any scalars saved by {bf:{help forestplot}}){p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(k)}}Number of subgroups{p_end}
{synopt:{cmd:r(n)}}Total number of included patients{p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(citype)}}Method of constructing confidence intervals{p_end}
{synopt:{cmd:r(command)}}Full estimation command-line{p_end}
{synopt:{cmd:r(cmdname)}}Estimation command name{p_end}
{synopt:{cmd:r(estvar)}}Name of effect size variable{p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:r(coeffs)}}Matrix of study and subgroup identifiers, effect coefficients, and numbers of participants{p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Variables}{p_end}
{synopt:{cmd:_rsample}}Observations included in the analysis (c.f. {cmd:e(sample)}){p_end}


{title:Examples}

{pstd} Example 1: Using the Hosmer & Lemeshow low birthweight data from {bf:{help logistic}}, look at the effect of maternal age on odds of LBW
within various data subgroups:

{pmore}
{cmd:. webuse lbw, clear}{p_end}
{pmore}
{cmd:. ipdover, over(race smoke ht) or forestplot(favours("Odds of LBW decrease" "as age increases" # "Odds of LBW increase" "as age increases")) : logistic low age}{p_end}


{pstd} Example 2: Using the same dataset, look at the mean difference in maternal age between those whose babies were LBW vs those who were normal weight
(demonstrates use of {opt group1()}, {opt group2()}):

{pmore}
{cmd:. ipdover age low, over(race ht) wmd forestplot(favours("Mean maternal age higher" "among those with LBW infant" # }
{cmd:  "Mean maternal age lower" "among those with LBW infant"))}
{cmd:  counts group1("Age of mothers" "of low BW infants") group2("Age of mothers" "of normal BW infants")}


{pstd} Example 3: Applying {bf:ipdover} to a set of clinical trials, showing the treatment effect by covariate subgroup by trial (using the example IPD meta-analysis dataset from {bf:{help ipdmetan}}):

{pmore}
{stata "use http://fmwww.bc.edu/repec/bocode/i/ipdmetan_example.dta":. use http://fmwww.bc.edu/repec/bocode/i/ipdmetan_example.dta}
{p_end}
{pmore}
{cmd:. stset tcens, fail(fail)}{p_end}
{pmore}
{cmd:. ipdover, over(stage) over(trialid) hr nosubgroup nooverall forestplot(favours(Favours treatment # Favours control)) : stcox trt}


{title:Author}

{p}
David Fisher, MRC Clinical Trials Unit at UCL, London, UK.

Email {browse "mailto:d.fisher@ucl.ac.uk":d.fisher@ucl.ac.uk}


{title:Acknowledgments}

{pstd}
Thanks to Phil Jones at UWO, Canada for suggesting improvements in functionality.
