<a href ="https://www.mrcctu.ucl.ac.uk/"><img src="logo_ukri-mrc-ctu_transparent-background.png" width="50%" /></a>

# ipdmetan
Current release: v4.03  12oct2022

A set of routines for conducting two-stage individual participant meta-analysis, and forest plots for trial subgroup analysis. The two-stage routine, `ipdmetan`, loops over a series of categories, fits the desired model to the data within each, and generates pooled effects, heterogeneity statistics etc, as appropriate; aggregate data may also be included from an external dataset. `ipdover` extends the use-case beyond the meta-analytic context, for example for creating a forest plot of a series of (potentially overlapping) subgroups within a single randomized trial.  This package is dependent upon the `metan` package; please ensure that the latest version of the `metan` package is installed.

# Installation

We currently recommend installation via the Stata Statistical Software Components (SSC) archive.
To see a package description, including contents, type within Stata:

    . ssc describe ipdmetan

...and to perform the installation, type:

    . ssc install ipdmetan

Package updates via SSC are handled using the `ado update` command; see the built-in Stata documentation.

Alternatively, the package may be installed directly from GitHub, by typing:

    . net describe ipdmetan, from("https://raw.githubusercontent.com/UCL/ipdmetan/master/src/")

# Usage and documentation

Currently, documentation on usage and options may be found in the documentation files within Stata.  After installation, type in Stata:

    . help ipdmetan
