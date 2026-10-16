# Phase 2: Prepare

Prepare verifies the source, imports it unchanged and records what the source says about itself. It does not clean, impute, transform or analyze outcome associations. Those belong to Process and Analyze.

Alignment: this phase follows the Ask brief (`docs/phases/01-ask.md`, reviewed at commit `829d595`) and keeps its question IDs Q01 to Q03 and its four timing groups (`enrollment`, `semester_1`, `semester_2`, `uncertain`).

## How to run

```text
Rscript scripts/run_pipeline.R --through prepare
Rscript scripts/02_prepare.R --reverify    # download and compare with UCI again
Rscript checks/check_source.R              # offline checks
```

Code: `R/prepare.R`, `scripts/02_prepare.R`, `checks/check_source.R`. By default the stage reuses the tracked provenance when the SHA-256 of `data.csv` still matches and the earlier comparison was `identical`. It downloads again when the file changes or with `--reverify`. A file that differs from the official archive stops the stage with an error and is never replaced.

## Outputs

| File | Tracked | Content |
| --- | --- | --- |
| `metadata/provenance.json` | yes | Official URLs, archive member, DOI, license, citation, verification time, SHA-256 values, comparison result, observed shape, R version |
| `metadata/variables.csv` | yes | One row per original column: source role and definition, source and observed types, proposed analytical type, units, timing group, reference, notes |
| `metadata/category_codes.csv` | yes | Variable, code, label, `source_unknown` flag, reference |
| `data/interim/source.rds` | no | The imported table, unchanged, with original column names |
| `outputs/tables/prepare/` | no | `import_summary.csv`, `column_inventory.csv`, `code_coverage.csv`, `range_checks.csv` |

## Source verification

- **Official source.** UCI dataset 697, DOI 10.24432/C5MC89, license CC BY 4.0. The archive URL is built from the repository slug returned by the UCI API, and the download contains a single `data.csv` member.
- **Comparison.** The raw SHA-256 of the tracked `data.csv` equals the SHA-256 of the archive member (`3EF126DE5CEFFF26EB11FBB4237F1A1401CB64B488E2F1D598C23CEDEB4C45AE`), so the files are byte-identical and no normalized comparison was needed. The code does handle the other cases: if bytes differ it compares headers and parsed values separately and treats any value difference as a blocker.
- **Retrieval time.** `verification_retrieved_at_utc` is when the official archive was downloaded for this comparison. The tracked file was already in the repository, and no claim is made about when it was first obtained.
- **Local fingerprint versus official comparison.** The SHA-256 recorded in earlier setup notes was only a local fingerprint. The comparison above is the check against an official download.

## Import contract

Semicolon delimiter, UTF-8 (a byte order mark is present and tolerated), decimal point `.`, only the empty string counts as NA, no whitespace trimming, original names kept (`name_repair = "minimal"`). The import produced no parsing problems.

Observed in R, against UCI's stated expectations:

| Check | UCI expectation | Observed |
| --- | --- | --- |
| Rows | 4,424 students | 4,424 |
| Columns | 36 features + Target | 36 features + Target (37 columns) |
| Missing cells | none | 0 |
| Target levels | Dropout, Enrolled, Graduate | exactly these three |

The observed counts agree with the expectations. Zero missing cells is a count of empty cells and does not show that the values are correct.

## Source quirks, recorded and not fixed

- The file starts with a UTF-8 byte order mark, and lines end with CRLF.
- The header of the attendance column is `Daytime/evening attendance` followed by a tab character (inside quotes). It is kept as is; Process maps it to a clean name.
- Some CSV headers differ from the UCI variable names: `Marital status` versus `Marital Status`, and the attendance tab. `Nacionality` is spelled that way in both.
- UCI types some columns as Integer although the file holds fractional values: the two semester grade columns. Other grade columns are typed Continuous by UCI and fractional in the file.
- The UCI description of `Curricular units 2nd sem (without evaluations)` mentions the 1st semester. It is treated as a typo in the source, to be confirmed, and the column stays in the semester_2 group.
- `Application order` is documented only by its endpoints (0 first choice, 9 last choice). It is treated as ordinal, and its values are range checked instead of being checked against a code list.
- `GDP` has no unit or period in the UCI metadata. The macroeconomic columns are contextual indicators with no known collection period.

## Category codes

`category_codes.csv` has 238 rows for 18 variables. Labels come from the UCI variable descriptions, split at each `code - label` pair, and are never inferred from numeric order. Every code observed in the data is documented, which `checks/check_source.R` verifies. Codes the source defines as unknown, blank or other are kept as real categories and flagged `source_unknown`: code 34 `Unknown` for mother's and father's qualification, and codes 90 `Other Situation` and 99 `(blank)` for mother's and father's occupation. They are not NA, and Process must not convert them silently.

## Timing groups

Timing groups in `variables.csv` follow the Ask brief. UCI describes the data as known at enrollment, yet semester 1 and 2 columns are present, so the description cannot hold for the whole table.

| Group | Columns |
| --- | --- |
| enrollment | Marital status through Admission grade, Displaced, Educational special needs, Gender, Age at enrollment, International |
| semester_1 | six `Curricular units 1st sem` columns |
| semester_2 | six `Curricular units 2nd sem` columns |
| uncertain | Debtor, Tuition fees up to date, Scholarship holder, Unemployment rate, Inflation rate, GDP, and Target (the outcome, recorded here because it has no feature timing) |

## Limitations and open items

- The metadata is taken from UCI's own variable descriptions. No independent codebook was available, so label meanings are as reliable as UCI's documentation.
- The macroeconomic columns have no stated period, and the cohort or enrollment years are not available.
- The timing groups are provisional where UCI is silent. They are assumptions recorded for Process and are not facts about measurement time.
- The check for a modified copy covers one kind of change (a changed value). It confirms the comparison logic fires and does not exhaust all possible differences.
- Nothing here describes outcome composition or associations. That evidence is for the Analyze tracks (Q01 to Q03).

## Handoff to Process

Process reads `data/interim/source.rds`, maps the original headers to clean names in `metadata/column_map.csv`, keeps `Target` a nominal factor, treats source-defined unknown categories as categories, and logs every transformation. No automatic deduplication, imputation, outlier removal, normalization or rebalancing is applied.
