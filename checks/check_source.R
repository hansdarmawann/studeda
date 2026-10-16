# Prepare-stage checks. Offline: verifies the tracked provenance and metadata
# against data.csv and data/interim/source.rds. Exit status 1 on any failure.
local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))[1L]
  root <- dirname(dirname(normalizePath(f)))
  source(file.path(root, "R", "project.R"))
  source(file.path(root, "R", "prepare.R"))
})
require_packages()
setwd(project_root())

failures <- character()
check <- function(ok, label, detail = "") {
  ok <- isTRUE(ok)
  cat(sprintf("[%s] %s%s\n", if (ok) "OK  " else "FAIL", label, if (nzchar(detail)) paste0(": ", detail) else ""))
  if (!ok) failures <<- c(failures, label)
}

# Provenance ------------------------------------------------------------------
check(file.exists("metadata/provenance.json"), "provenance.json exists")
prov <- read_json_file("metadata/provenance.json")
local_sha <- sha256_file("data.csv")
check(identical(prov$local_source$sha256, local_sha), "data.csv SHA-256 matches provenance", local_sha)
check(identical(prov$comparison$outcome, "identical") &&
        identical(prov$official_source$official_csv_sha256, local_sha),
      "data.csv is byte-identical to the official UCI archive member")
check(identical(prov$dataset$license, "CC BY 4.0") && nzchar(prov$dataset$doi) &&
        nzchar(prov$dataset$citation), "license, DOI and citation recorded")
check(grepl("^https://archive\\.ics\\.uci\\.edu/", prov$official_source$archive_url) &&
        nzchar(prov$official_source$verification_retrieved_at_utc),
      "official URL and verification time recorded")

# Import ----------------------------------------------------------------------
imp <- import_source("data.csv")
df <- imp$data
check(nrow(imp$problems) == 0L, "no parsing problems", paste(nrow(imp$problems), "problem(s)"))
check(file.exists("data/interim/source.rds"), "data/interim/source.rds exists")
src <- readRDS("data/interim/source.rds")
check(is.data.frame(src) && identical(src, df), "source.rds equals a fresh import of data.csv")
check(nrow(df) == EXPECTED$rows && ncol(df) - 1L == EXPECTED$features,
      "shape matches UCI expectation",
      sprintf("%d rows, %d features + target", nrow(df), ncol(df) - 1L))
check(identical(prov$observed$rows, nrow(df)) && identical(prov$observed$columns, ncol(df)),
      "provenance shape matches the import")
check(names(df)[ncol(df)] == EXPECTED$target &&
        identical(sort(unique(df[[EXPECTED$target]])), EXPECTED$target_levels),
      "Target has exactly Dropout, Enrolled and Graduate")
check(sum(is.na(df)) == 0L, "actual missing cells counted", paste(sum(is.na(df)), "missing"))

# Variables -------------------------------------------------------------------
vars <- utils::read.csv("metadata/variables.csv", stringsAsFactors = FALSE, check.names = FALSE,
                        na.strings = character(), encoding = "UTF-8")
need <- c("position", "original_name", "source_role", "source_definition", "source_type",
          "observed_storage_type", "proposed_analytical_type", "units", "timing_group",
          "source_reference", "notes")
check(identical(names(vars), need), "variables.csv has the required columns")
check(identical(vars$original_name, names(df)), "variables.csv covers every original column in order")
check(all(vars$timing_group %in% TIMING_GROUPS), "timing groups are valid")
check(all(nzchar(vars$source_definition)) && all(nzchar(vars$proposed_analytical_type)),
      "every column has a source definition and analytical type")
check(sum(vars$source_role == "Target") == 1L && vars$source_role[nrow(vars)] == "Target",
      "exactly one Target column, last")

# Category codes --------------------------------------------------------------
codes <- utils::read.csv("metadata/category_codes.csv", colClasses = "character",
                         na.strings = character(), encoding = "UTF-8")
check(identical(names(codes), c("variable", "code", "label", "source_unknown", "reference")),
      "category_codes.csv has the required columns")
check(!anyDuplicated(codes[c("variable", "code")]), "no duplicate variable/code pairs")
check(all(codes$variable %in% names(df)) && all(nzchar(codes$label)), "codes map to real columns and have labels")
check(all(codes$source_unknown %in% c("TRUE", "FALSE")) && any(codes$source_unknown == "TRUE"),
      "source-defined unknown categories are flagged separately from NA")
cov <- code_coverage(df, codes)
check(all(cov$observed_undocumented == ""), "every observed code is documented",
      paste(cov$variable[cov$observed_undocumented != ""], collapse = ", "))
coded_vars <- unique(c(codes$variable))
expected_coded <- vars$original_name[vars$proposed_analytical_type %in% c("nominal", "binary", "ordinal")
                                     & vars$source_role != "Target"]
check(setequal(coded_vars, expected_coded), "all nominal, binary and ordinal features have code metadata")
rc <- range_checks(df)
check(all(rc$n_outside == 0L), "values lie within source-stated ranges")

# Comparison behavior: a changed file must be detected -------------------------
tmp <- tempfile(fileext = ".csv")
lines <- readLines("data.csv", warn = FALSE)
lines[2L] <- sub(";Dropout$", ";Graduate", lines[2L])
writeLines(lines, tmp)
check(!identical(compare_sources("data.csv", tmp)$outcome, "identical"),
      "comparison detects a modified copy")
unlink(tmp)

if (length(failures)) {
  cat("Source check FAILED: ", paste(failures, collapse = "; "), "\n", sep = "")
  quit(status = 1L)
}
cat("Source check passed.\n")
