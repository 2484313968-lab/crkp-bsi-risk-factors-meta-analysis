# Stata code for meta-analysis of odds ratios

## Purpose

This repository contains an English-language Stata do-file derived from the original analysis commands for a systematic review and meta-analysis of risk factors for carbapenem-resistant *Klebsiella pneumoniae* bloodstream infection (CRKP-BSI). The code converts study-level odds ratios and their 95% confidence intervals to the natural-log scale, estimates random-effects pooled effects using restricted maximum likelihood (REML), and applies the Hartung–Knapp standard-error adjustment to meta-analysis summaries.

The do-file also contains **optional** commands for subgroup meta-analyses, leave-one-out sensitivity analysis, meta-regression, funnel plots, small-study-effect tests, trim-and-fill analyses, and Galbraith plots. An optional module should only be enabled if that analysis is relevant to the specified dataset and was actually performed for the article.

## Software

- Stata 19 (`meta` commands).
- No community-contributed Stata packages are required.
- The code has been edited and reviewed against Stata documentation but **has not been executed against the manuscript's original extraction dataset**.

## Contents

- `meta_analysis_OR.do` — analysis script with English comments.
- `effect_sizes_TEMPLATE.csv` — column names only; **no study results or fabricated observations**.
- `README.md` — data requirements and usage instructions.

## Required data format

Create a CSV named `effect_sizes.csv` in the same working directory as `meta_analysis_OR.do`.

**Mandatory fields**

| Column | Meaning |
|---|---|
| `studyid` | A unique study identifier, such as `Smith-2024` |
| `or` | Published odds ratio, whether unadjusted or adjusted for this specific run |
| `ll` | Lower confidence limit of the reported 95% CI |
| `ul` | Upper confidence limit of the reported 95% CI |

**Optional fields** (only necessary when the corresponding section is enabled)

| Column | Meaning |
|---|---|
| `studytype1` | Study-design category, such as cohort versus case–control |
| `exposurewindow1` | Exposure-window category, harmonized across studies |
| `year` | Numeric study-level year for exploratory meta-regression |

Data must contain at least two independent study estimates; all ratios and confidence bounds must be positive, with `ll < ul`. The code assumes the reported 95% CI is approximately symmetric on the natural-log scale when reconstructing its standard error. Confirm that the original CI method supports this approximation.

## Important data separation

Run **one exposure / endpoint / comparator / effect type at a time**. In particular:

1. Pool unadjusted odds ratios (`uOR`) and adjusted odds ratios (`aOR`) **separately**.
2. Do **not** combine odds ratios (`OR`) with risk ratios (`RR`) or hazard ratios (`HR`) in the same run.
3. Maintain the same CRKP-BSI vs CSKP-BSI comparison and eligibility criteria across contributing studies.
4. Retain the study-level input CSV alongside the published source code if a fully reproducible public package is desired, subject to the provenance and redistribution conditions of the original studies.
5. Do not infer missing effect sizes from group comparisons or convert reported baseline P values into OR estimates.

## How to run

1. Place `effect_sizes.csv` and `meta_analysis_OR.do` in one directory.
2. Open Stata 19, set the working directory to that directory, and run:

   ```stata
   do "meta_analysis_OR.do"
   ```

3. Outputs will be saved under the `results/` folder.
4. Change the module switches (`0` = disabled, `1` = enabled) under **User configuration** to reproduce only the analyses described in the final publication.
5. Repeat for each exposure and each effect type using the appropriate study-level input CSV, retaining distinct output directories or renaming outputs between runs so prior files are not overwritten.

## Methods represented in the code

- Effect size: `ln(OR)`.
- Reconstructed standard error: `[ln(upper 95% CI) - ln(lower 95% CI)] / [2 x Phi^(-1)(0.975)]`.
- Primary pooling: random-effects inverse-variance meta-analysis, REML tau-squared estimation.
- Primary inference: Hartung–Knapp standard-error adjustment.
- Reporting: exponentiated effects (odds ratios) and 95% confidence intervals.
- Subgrouping: by `studytype1` and/or `exposurewindow1`, only if applicable.
- Meta-regression: publication year and categorical study design, only if enabled.
- Small-study-effect tests: automatically skipped for datasets with fewer than 10 studies when enabled; this threshold is a practical caution, not proof that larger analyses are unbiased.
- Trim-and-fill: REML model only; the Hartung–Knapp option is **not** supplied because it is not supported by this command.

## Reproducibility and reporting limitations

This release is **source code, not the original results or a claim that every optional analysis was included in the published study**. Exact reproduction also requires the matching extraction data, inclusion decisions, subgroup definitions, Stata version, and enabled analysis switches. Study-level covariate definitions and adjusted-model compositions should be documented separately.

## Reference documentation

- Stata meta-analysis overview: https://www.stata.com/features/overview/meta-analysis/
- Stata FAQ on precomputed ORs/RRs and their confidence intervals: https://www.stata.com/support/faqs/statistics/meta-set-confidence-intervals-effect-sizes/
- Stata meta-analysis manual: https://www.stata.com/manuals/meta.pdf

## Suggested citation in the manuscript

> The study-level extracted data and Stata 19 analysis code are available at [REPOSITORY NAME AND PERSISTENT DOI/URL].

Replace the bracketed text only after the repository has been deposited and the persistent identifier has been assigned. If only code is deposited, change "The study-level extracted data and Stata 19 analysis code" to "The Stata 19 analysis code".
