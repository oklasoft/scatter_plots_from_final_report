# Scatter Plots from Final Report

## Description

A quick and old script to wrap together some basic command line tools to make basic plots of data.
These tools are namely gnuplot & grep. The input comes from an illumina final report exported from
from genome studio or some such. The output then are three plots for each SNP, a raw, corrected &
r_theta. The output are named as SNP-TYPE.png and have an index.html linking them all. These are 
saved in the current directory

## Prereq

This is a ruby1.9 of some sort script

### Ruby gems

* tempfile
* getoptlong

### Extenral Apps

* egrep
* grep
* gnuplot

# Contact

Stuart Glenn - <Stuart-Glenn@omrf.org>

# License

Copyright (c) 2009 Stuart Glenn, Oklahoma Medical Research Foundation (OMRF), essential BSD like

