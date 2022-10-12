<a href ="https://www.ctu.mrc.ac.uk/"><img src="MRCCTU_at_UCL_Logo.png" width="50%" /></a>

# ipdmetan
Current release: v4.03  12oct2022

A set of routines for conducting two-stage individual participant meta-analysis, and forest plots for trial subgroup analysis. The two-stage routine, **ipdmetan**, loops over a series of categories, fits the desired model to the data within each, and generates pooled effects, heterogeneity statistics etc, as appropriate; aggregate data may also be included from an external dataset. **ipdover** extends the use-case beyond the meta-analytic context, for example for creating a forest plot of a series of (potentially overlapping) subgroups within a single randomized trial.  This package is dependent upon the **metan** package; please ensure that the latest version of the **metan** package is installed.
