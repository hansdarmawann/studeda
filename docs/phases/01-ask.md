# Phase 1: Ask

This brief defines the decision context, scope, questions, required evidence and success criteria for the descriptive/diagnostic EDA. It contains no analytical results. Statements about the data come from the UCI dataset page and its variable metadata; anything not yet checked in R is marked as a constraint to verify in Prepare or Process.

## Decision context and audience

The analysis is written for higher-education retention and student-support stakeholders (for example student-success teams, programme coordinators and academic administrators). These roles are **proposed audiences**. No interviews, requests or feedback from real stakeholders were collected, and none are claimed.

The business question is: *how are final student outcomes (Dropout, Enrolled, Graduate) distributed in this dataset, and which enrollment-time, demographic/socioeconomic and semester academic features are associated with them?* The aim is to describe patterns that could guide where to look further, not to decide who receives support.

## Scope

In scope:

- Outcome composition and data coverage of `Target`.
- Associations between `Target` and enrollment, demographic/socioeconomic and semester academic features.
- Univariate and bivariate descriptive statistics, effect sizes, uncertainty and limitations.

Out of scope: predictive modeling, risk scoring of individuals, causal effect claims, policy deployment, and any claim that an intervention has been implemented or works.

`Target` is the nominal outcome with three distinct levels: Dropout, Enrolled and Graduate. They are never merged. The other original columns are explanatory variables. Row numbers and other bookkeeping fields are not features.

## Questions

Question IDs are stable. Refinements are allowed if they stay within the same domain and are recorded.

| ID | Question | Unit and population | Evidence type |
| --- | --- | --- | --- |
| Q01 | What is the composition of `Target`, and how complete and well-covered is the data? | Student records in `data.csv` (all rows) | Class counts and proportions, missingness and value coverage per variable, univariate distributions |
| Q02 | How do outcomes differ across demographic and socioeconomic features? | Students grouped by each categorical feature level, or by bins/summaries of numeric features such as age at enrollment | Within-group outcome proportions with numerators and denominators, association measures, effect sizes |
| Q03 | How do outcomes differ across academic and semester features? | Students, with semester features kept separate from enrollment-time features | Distributions of numeric measures by outcome, within-group outcome proportions, effect sizes |

### Required evidence per question

All questions report the overall class counts and proportions as a reference. For every comparison, report group sizes, numerators, denominators, units and the timing group of the feature. Small groups are flagged and their percentages are reported with context, not alone.

**Q01.** Class counts and proportions for Dropout, Enrolled and Graduate; class imbalance; actual missingness and out-of-range checks (checked in R even though UCI reports none); distribution of each variable; coverage of source-defined category codes.
*Limitation:* describes this single dataset only. Coverage checks cannot show that values are correct.

**Q02.** Within-group outcome proportions (each group sums to its own denominator); association between each categorical feature and `Target` using a suitable nominal measure such as Cramér's V with its caveats; for numeric features such as age at enrollment, distributions by outcome. Exploratory tests are optional and need a stated rationale, declared test family and Benjamini-Hochberg adjustment within the question.
*Limitation:* associations are observational. Nominal codes (for example course, occupation, nationality) have no numeric meaning and must not be correlated as numbers. Sparse categories give unstable proportions.

**Q03.** Numeric distributions by outcome (for example median and interquartile range, or other suited summaries); within-group outcome proportions for binned or categorical academic features; effect sizes suited to the data type, with uncertainty where informative. Enrollment-time features (for example admission grade and previous qualification grade) are reported separately from semester 1 and semester 2 observations.
*Limitation:* semester observations are not available at enrollment, so they cannot support claims about what is knowable at enrollment. A semester value may also partly reflect the outcome itself (for example a student who left has fewer units to evaluate).

## Timing of information

| Timing group | Meaning | Features (provisional, to be recorded in Prepare) |
| --- | --- | --- |
| enrollment | Described by UCI as known at enrollment | Marital status, application mode and order, course, attendance, previous qualification and grade, nationality, parents' qualifications and occupations, admission grade, displaced, educational special needs, gender, age at enrollment, international |
| semester_1 | Observed during or after the first semester | Curricular units 1st sem (six columns) |
| semester_2 | Observed during or after the second semester | Curricular units 2nd sem (six columns) |
| uncertain | UCI does not state when it was measured | Debtor, tuition fees up to date, scholarship holder (status at enrollment is not documented), and the macroeconomic indicators (unemployment rate, inflation rate, GDP) |

UCI says the dataset contains information known at enrollment, yet it also includes semester 1 and semester 2 columns, so that description cannot hold for the whole table. This must be treated as a source inconsistency to document, and timing assignments in the table above are provisional until Prepare records them with source references.

Later information cannot substantiate an enrollment-time conclusion. A finding about semester features is described as an association observed within the semesters, never as something the institution could have known at enrollment. Economic indicators are contextual; no cohort timeline is invented, and no claim is made about when they were recorded.

## Success criteria

The analysis succeeds if:

1. Reproducible, validated evidence exists for Q01 to Q03, regenerated from `data.csv` by R code, with checks that pass.
2. Every number in the report traces to executed R output with its numerator, denominator and timing group.
3. Charts are interpretable and accompanied by explicit limitations.
4. Later proposals are traceable to findings or to a stated evidence gap.

No finding has to be statistically significant. A null or ambiguous result is a valid result.

## Constraints and limitations to verify

These are recorded as constraints. They are not established results, and Prepare and Process must check them against the data.

- **Single institution.** The data come from one Portuguese higher-education institution (as described by UCI). Generalization to other institutions is not supported.
- **Enrolled is not terminal.** `Enrolled` describes students still enrolled at the end of the normal course duration. It is not a final success or failure, and it is kept as its own class.
- **Class imbalance.** Class sizes are unequal (to be quantified in Q01). Raw counts and proportions need care, and no rebalancing is applied.
- **Observational design.** Associations do not show causes. Unmeasured covariates (for example motivation or health) may explain differences.
- **Cohort and timing unknown.** UCI does not give the enrollment years, so cohort effects and the timing of the macroeconomic indicators cannot be established.
- **Source-processed data.** UCI states that the authors preprocessed the data for anomalies, outliers and missing values, so raw administrative values are not available.
- **Metadata quirks.** The CSV header contains a tab suffix in the attendance column, and variable names differ slightly from the UCI metadata (for example `Marital status` and `Marital Status`, `Nacionality`). These are handled in Prepare and Process, not guessed.
- **Duplicates.** Whether identical rows exist is checked, but they are not removed automatically.

## Handoff

Prepare uses these question IDs and the timing groups above for its source inventory. Process keeps the timing groups in the data dictionary. The three analysis tracks answer Q01 (profile), Q02 (demographics) and Q03 (academic), and the integration step links every finding to a question ID.

## References

- UCI dataset: https://archive.ics.uci.edu/dataset/697/predict+students+dropout+and+academic+success
- Google data analytics phases: https://grow.google/grow-your-career/articles/what-is-data-analytics/
