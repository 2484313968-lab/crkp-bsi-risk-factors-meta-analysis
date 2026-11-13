/*
==============================================================================
Title: Reproducible meta-analysis of odds ratios
Purpose: Generic analysis script for study-level odds ratios and 95% CIs
Software: Stata 19 (official meta commands)
Model: Random-effects meta-analysis using REML with Hartung-Knapp inference
Input: effect_sizes.csv (one exposure, one effect model per analysis)
Output: results/*.log and selected figures

IMPORTANT
- This script analyses odds ratios (ORs), including adjusted ORs when the
  input values are adjusted estimates. Do not combine unadjusted and adjusted
  ORs in one run. Do not mix ORs with risk ratios or hazard ratios.
- The input data file is NOT included in this code-only release. To reproduce
  numerical results, deposit the corresponding study-level extraction data.
- Optional analyses are disabled by default. Enable only analyses actually
  performed and reported in the associated manuscript.
==============================================================================
*/

version 19.0
clear all
set more off
set linesize 120

* ---------------------------------------------------------------------------
* 1. User configuration
* ---------------------------------------------------------------------------
local input_file "effect_sizes.csv"
local output_dir "results"

* Set 1 to enable a module; set 0 to skip it.
local run_study_design_subgroup 0
local run_exposure_window_subgroup 0
local run_leave_one_out 1
local run_meta_regression 0
local run_funnel_plots 0
local run_small_study_tests 0
local run_trim_and_fill 0
local run_galbraith_plot 0

capture mkdir "`output_dir'"
capture log close _all
log using "`output_dir'/meta_analysis_OR.log", text replace

* ---------------------------------------------------------------------------
* 2. Import and validate the extracted study-level data
* ---------------------------------------------------------------------------
capture confirm file "`input_file'"
if _rc {
    display as error "Input file not found: `input_file'"
    display as error "See README.md for the required data structure."
    exit 601
}

import delimited using "`input_file'", varnames(1) clear

foreach v in studyid or ll ul {
    capture confirm variable `v'
    if _rc {
        display as error "Required variable is missing: `v'"
        exit 111
    }
}

foreach v in or ll ul {
    capture confirm numeric variable `v'
    if _rc {
        display as error "Variable `v' must contain numeric values."
        exit 109
    }
}

count if missing(or, ll, ul)
if r(N) > 0 {
    display as error "Missing OR or confidence-limit values were detected."
    exit 459
}

count if or <= 0 | ll <= 0 | ul <= 0 | ll >= ul
if r(N) > 0 {
    display as error "OR and CI limits must be positive, with ll < ul."
    exit 459
}

isid studyid
count
if r(N) < 2 {
    display as error "At least two independent study estimates are required."
    exit 2001
}

* ---------------------------------------------------------------------------
* 3. Transform the ORs and reconstruct standard errors from 95% CIs
* ---------------------------------------------------------------------------
generate double lnOR = ln(or)
generate double lnLL = ln(ll)
generate double lnUL = ln(ul)
generate double selnOR = (lnUL - lnLL) / (2 * invnormal(0.975))

* This approximation assumes that the reported 95% CIs can be treated as
* approximately symmetric on the natural-log scale (Wald-type intervals).

* ---------------------------------------------------------------------------
* 4. Declare the meta-analysis data and run the primary analysis
* ---------------------------------------------------------------------------
meta set lnOR selnOR, studylabel(studyid) eslabel("OR") random(reml)

display as text "PRIMARY ANALYSIS: REML random effects with Hartung-Knapp SEs"
meta summarize, eform random(reml) se(khartung)

meta forestplot, eform nullrefline esrefline random(reml) se(khartung)
graph export "`output_dir'/overall_forest_plot.png", width(2400) replace

* Optional graph styling (not used by default):
* meta forestplot, eform nullrefline esrefline(lcolor(green)) ///
*     random(reml) se(khartung)

* ---------------------------------------------------------------------------
* 5. Optional subgroup analyses
* ---------------------------------------------------------------------------
if `run_study_design_subgroup' {
    capture confirm variable studytype1
    if _rc {
        display as error "studytype1 is required for study-design subgroups."
        exit 111
    }
    capture confirm string variable studytype1
    if !_rc {
        encode studytype1, generate(studytype_id)
    }
    else {
        clonevar studytype_id = studytype1
    }

    display as text "SUBGROUP ANALYSIS: study design"
    meta summarize, subgroup(studytype_id) eform random(reml) se(khartung)
    meta forestplot, subgroup(studytype_id) eform nullrefline esrefline ///
        random(reml) se(khartung)
    graph export "`output_dir'/study_design_subgroup.png", width(2400) replace
}

if `run_exposure_window_subgroup' {
    capture confirm variable exposurewindow1
    if _rc {
        display as error "exposurewindow1 is required for exposure-window subgroups."
        exit 111
    }
    capture confirm string variable exposurewindow1
    if !_rc {
        encode exposurewindow1, generate(exposurewindow_id)
    }
    else {
        clonevar exposurewindow_id = exposurewindow1
    }

    display as text "SUBGROUP ANALYSIS: exposure window"
    meta summarize, subgroup(exposurewindow_id) eform random(reml) se(khartung)
    meta forestplot, subgroup(exposurewindow_id) eform nullrefline esrefline ///
        random(reml) se(khartung)
    graph export "`output_dir'/exposure_window_subgroup.png", width(2400) replace
}

* ---------------------------------------------------------------------------
* 6. Optional leave-one-out sensitivity analysis
* ---------------------------------------------------------------------------
if `run_leave_one_out' {
    display as text "SENSITIVITY ANALYSIS: leave one study out"
    meta summarize, leaveoneout eform random(reml) se(khartung)
    meta forestplot, leaveoneout eform nullrefline esrefline ///
        random(reml) se(khartung)
    graph export "`output_dir'/leave_one_out.png", width(2400) replace
}

* ---------------------------------------------------------------------------
* 7. Optional meta-regression of publication year and study design
* ---------------------------------------------------------------------------
if `run_meta_regression' {
    capture confirm numeric variable year
    if _rc {
        display as error "A numeric 'year' variable is required for meta-regression."
        exit 111
    }
    capture confirm variable studytype_id
    if _rc {
        capture confirm variable studytype1
        if _rc {
            display as error "studytype1 is required for meta-regression."
            exit 111
        }
        capture confirm string variable studytype1
        if !_rc {
            encode studytype1, generate(studytype_id)
        }
        else {
            clonevar studytype_id = studytype1
        }
    }

    display as text "META-REGRESSION: publication year and study design"
    meta regress year i.studytype_id, random(reml) se(khartung)

    * Bubble plots are generated from a separate univariable model of year.
    * Do not mistake this plot for the adjusted two-moderator regression above.
    meta regress year, random(reml) se(khartung)
    estat bubbleplot
    graph export "`output_dir'/publication_year_bubble_plot.png", ///
        width(2400) replace
}

* ---------------------------------------------------------------------------
* 8. Optional assessment of small-study effects
* ---------------------------------------------------------------------------
if `run_funnel_plots' {
    meta funnelplot
    graph export "`output_dir'/funnel_plot.png", width(2400) replace

    meta funnelplot, contours(1 5 10)
    graph export "`output_dir'/contour_enhanced_funnel_plot.png", ///
        width(2400) replace
}

if `run_small_study_tests' {
    count
    if r(N) < 10 {
        display as text "Egger/Begg tests skipped: fewer than 10 studies."
    }
    else {
        meta bias, egger
        * Included to reflect the source script; the Begg test is generally
        * less informative and should be interpreted cautiously.
        meta bias, begg
    }
}

* Trim-and-fill does not support se(khartung) as an option.
if `run_trim_and_fill' {
    meta trimfill, eform random(reml)
}

* ---------------------------------------------------------------------------
* 9. Optional Galbraith plot for exploring heterogeneity
* ---------------------------------------------------------------------------
if `run_galbraith_plot' {
    meta galbraithplot
    graph export "`output_dir'/galbraith_plot.png", width(2400) replace
}

* ---------------------------------------------------------------------------
* End of script
* ---------------------------------------------------------------------------
display as text "Analysis script completed. See `output_dir' for outputs."
log close
