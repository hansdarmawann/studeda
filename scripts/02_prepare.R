# Prepare stage: verify data.csv against the official UCI archive, import it
# unchanged, and write source metadata.
#   Rscript scripts/02_prepare.R              reuse tracked provenance when data.csv is unchanged
#   Rscript scripts/02_prepare.R --reverify   download and compare again
local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))[1L]
  root <- dirname(dirname(normalizePath(f)))
  source(file.path(root, "R", "project.R"))
  source(file.path(root, "R", "prepare.R"))
})

args <- commandArgs(trailingOnly = TRUE)
unknown <- setdiff(args, "--reverify")
if (length(unknown) > 0L) {
  cat("Usage: Rscript scripts/02_prepare.R [--reverify]\n")
  quit(status = 2L)
}
require_packages()
set_project_seed()

root <- project_root()
setwd(root)
ensure_output_dirs(root)

src_path <- "data.csv"
prov_path <- "metadata/provenance.json"
vars_path <- "metadata/variables.csv"
codes_path <- "metadata/category_codes.csv"
table_dir <- "outputs/tables/prepare"
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

local_sha <- sha256_file(src_path)
raw_facts <- inspect_raw_file(src_path)
imp <- import_source(src_path)
df <- imp$data
if (nrow(imp$problems) > 0L) {
  print(imp$problems)
  stop("Parsing problems while importing ", src_path, call. = FALSE)
}

# Reuse tracked provenance only if it describes exactly this file and all metadata exist.
reuse <- FALSE
if (!"--reverify" %in% args && all(file.exists(c(prov_path, vars_path, codes_path)))) {
  prev <- read_json_file(prov_path)
  reuse <- identical(prev$local_source$sha256, local_sha) &&
    identical(prev$comparison$outcome, "identical")
}

if (reuse) {
  cat("Reusing verified provenance (data.csv fingerprint unchanged).\n")
  prov <- prev
  variables <- utils::read.csv(vars_path, stringsAsFactors = FALSE, check.names = FALSE,
                               na.strings = character(), encoding = "UTF-8")
  codes <- utils::read.csv(codes_path, colClasses = "character", na.strings = character(),
                           encoding = "UTF-8")
} else {
  cat("Downloading the official UCI archive for comparison...\n")
  dl_dir <- file.path("data", "raw-downloads")
  off <- fetch_official(dl_dir)
  cmp <- compare_sources(src_path, off$csv)
  official_sha <- sha256_file(off$csv)
  if (!identical(cmp$outcome, "identical")) {
    write_csv_stable(as.data.frame(lapply(cmp, as.character)), file.path(table_dir, "source_comparison.csv"))
    stop("data.csv differs from the official archive (", cmp$outcome,
         "). Not replacing the source; see ", table_dir, "/source_comparison.csv", call. = FALSE)
  }
  api_vars <- off$meta$data$variables
  variables <- build_variables(df, api_vars)
  codes <- build_category_codes(api_vars, names(df))
  write_csv_stable(variables, vars_path)
  write_csv_stable(codes, codes_path)

  data_meta <- off$meta$data
  prov <- list(
    dataset = list(
      name = data_meta$name, uci_id = UCI_ID, doi = data_meta$dataset_doi,
      license = "CC BY 4.0", license_url = "https://creativecommons.org/licenses/by/4.0/legalcode",
      uci_last_updated = data_meta$last_updated,
      citation = data_meta$additional_info$citation,
      expected = list(rows = EXPECTED$rows, features = EXPECTED$features, target = EXPECTED$target,
                      stated_missing_values = data_meta$has_missing_values)
    ),
    official_source = list(
      page_url = off$urls$page, api_url = off$urls$api, archive_url = off$urls$archive,
      archive_member = "data.csv", archive_members = unlist(off$members),
      archive_url_note = "Built from the repository_url slug returned by the UCI API; the download returned the CSV member compared below.",
      verification_retrieved_at_utc = off$retrieved_at,
      official_csv_sha256 = official_sha
    ),
    local_source = list(
      path = src_path, sha256 = local_sha, bytes = raw_facts$bytes,
      has_utf8_bom = raw_facts$has_bom, line_ending = if (raw_facts$crlf_lines == raw_facts$lf_lines) "CRLF" else "mixed or LF",
      header_has_tab = raw_facts$header_has_tab,
      note = "Pre-existing tracked file. No claim is made about when it was originally retrieved."
    ),
    comparison = cmp,
    observed = list(rows = nrow(df), columns = ncol(df), features = ncol(df) - 1L,
                    missing_cells = sum(is.na(df)), delimiter = ";",
                    target_levels = sort(unique(df[["Target"]]))),
    r_version = R.version.string
  )
  jsonlite::write_json(prov, prov_path, auto_unbox = TRUE, pretty = TRUE, null = "null")
}

# Evidence tables (ignored, regenerated every run).
write_csv_stable(column_inventory(df), file.path(table_dir, "column_inventory.csv"))
write_csv_stable(code_coverage(df, codes), file.path(table_dir, "code_coverage.csv"))
write_csv_stable(range_checks(df), file.path(table_dir, "range_checks.csv"))
write_csv_stable(data.frame(
  metric = c("rows", "columns", "missing_cells", "parse_problems", "has_utf8_bom"),
  value = c(nrow(df), ncol(df), sum(is.na(df)), nrow(imp$problems), raw_facts$has_bom)
), file.path(table_dir, "import_summary.csv"))

# Imported table, unchanged, original column names.
saveRDS(df, file.path("data", "interim", "source.rds"))

cat(sprintf("Imported %d rows x %d columns from %s (SHA-256 %s).\n",
            nrow(df), ncol(df), src_path, local_sha))
cat("Prepare complete.\n")
