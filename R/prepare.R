# Prepare phase: source verification, import, and source metadata.
# Reads data.csv unchanged; never rewrites it. Sourced after R/project.R.

UCI_ID <- 697L
UCI_PAGE <- "https://archive.ics.uci.edu/dataset/697/predict+students+dropout+and+academic+success"
UCI_API <- "https://archive.ics.uci.edu/api/dataset?id=697"
EXPECTED <- list(rows = 4424L, features = 36L, target = "Target",
                 target_levels = c("Dropout", "Enrolled", "Graduate"))

# Timing group, analytical type and units per variable, keyed by normalized name.
# Timing groups follow docs/phases/01-ask.md and are provisional where UCI is silent.
VARIABLE_ANNOTATIONS <- local({
  a <- function(name, timing, type, units = "", note = "") {
    data.frame(key = name, timing_group = timing, analytical_type = type,
               units = units, annotation_note = note, stringsAsFactors = FALSE)
  }
  enr <- "enrollment"
  rbind(
    a("marital status", enr, "nominal"),
    a("application mode", enr, "nominal"),
    a("application order", enr, "ordinal", "rank 0-9", "Source defines only the endpoints 0 (first choice) and 9 (last choice)."),
    a("course", enr, "nominal"),
    a("daytime/evening attendance", enr, "binary"),
    a("previous qualification", enr, "nominal"),
    a("previous qualification (grade)", enr, "numeric_continuous", "points (0-200)"),
    a("nacionality", enr, "nominal"),
    a("mother's qualification", enr, "nominal"),
    a("father's qualification", enr, "nominal"),
    a("mother's occupation", enr, "nominal"),
    a("father's occupation", enr, "nominal"),
    a("admission grade", enr, "numeric_continuous", "points (0-200)"),
    a("displaced", enr, "binary"),
    a("educational special needs", enr, "binary"),
    a("debtor", "uncertain", "binary", "", "UCI does not state when debtor status was recorded."),
    a("tuition fees up to date", "uncertain", "binary", "", "UCI does not state when fee status was recorded."),
    a("gender", enr, "binary"),
    a("scholarship holder", "uncertain", "binary", "", "UCI does not state whether status is as of enrollment."),
    a("age at enrollment", enr, "numeric_discrete", "years"),
    a("international", enr, "binary"),
    a("curricular units 1st sem (credited)", "semester_1", "numeric_discrete", "count"),
    a("curricular units 1st sem (enrolled)", "semester_1", "numeric_discrete", "count"),
    a("curricular units 1st sem (evaluations)", "semester_1", "numeric_discrete", "count"),
    a("curricular units 1st sem (approved)", "semester_1", "numeric_discrete", "count"),
    a("curricular units 1st sem (grade)", "semester_1", "numeric_continuous", "points (0-20)"),
    a("curricular units 1st sem (without evaluations)", "semester_1", "numeric_discrete", "count"),
    a("curricular units 2nd sem (credited)", "semester_2", "numeric_discrete", "count"),
    a("curricular units 2nd sem (enrolled)", "semester_2", "numeric_discrete", "count"),
    a("curricular units 2nd sem (evaluations)", "semester_2", "numeric_discrete", "count"),
    a("curricular units 2nd sem (approved)", "semester_2", "numeric_discrete", "count"),
    a("curricular units 2nd sem (grade)", "semester_2", "numeric_continuous", "points (0-20)"),
    a("curricular units 2nd sem (without evaluations)", "semester_2", "numeric_discrete", "count",
      "UCI description says '1st semester' for this 2nd-semester column; treated as a source typo, to be confirmed."),
    a("unemployment rate", "uncertain", "numeric_continuous", "percent", "Contextual economic indicator; collection period not stated."),
    a("inflation rate", "uncertain", "numeric_continuous", "percent", "Contextual economic indicator; collection period not stated."),
    a("gdp", "uncertain", "numeric_continuous", "unspecified", "Contextual economic indicator; unit and period not stated by UCI."),
    a("target", "uncertain", "nominal", "", "Outcome at the end of the normal course duration per UCI; Dropout, Enrolled and Graduate stay distinct.")
  )
})

TIMING_GROUPS <- c("enrollment", "semester_1", "semester_2", "uncertain")

normalize_name <- function(x) tolower(trimws(gsub("\\s+", " ", x)))

sha256_file <- function(path) toupper(digest::digest(file = path, algo = "sha256", serialize = FALSE))

# --- Import ------------------------------------------------------------------

# Semicolon-delimited, UTF-8 (BOM tolerated), no NA tokens other than the empty
# string, no whitespace trimming, original header spelling preserved.
import_source <- function(path) {
  x <- readr::read_delim(
    path, delim = ";", na = "", trim_ws = FALSE, progress = FALSE,
    locale = readr::locale(decimal_mark = ".", encoding = "UTF-8"),
    name_repair = "minimal", show_col_types = FALSE, guess_max = Inf
  )
  prob <- readr::problems(x)
  list(data = as.data.frame(x, stringsAsFactors = FALSE), problems = prob)
}

# Raw header facts that a parsed table can hide.
inspect_raw_file <- function(path) {
  bytes <- readBin(path, "raw", n = file.size(path))
  head_line <- rawToChar(bytes[seq_len(which(bytes == as.raw(0x0A))[1L])])
  list(
    bytes = length(bytes),
    has_bom = length(bytes) >= 3L && identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF))),
    crlf_lines = sum(bytes == as.raw(0x0D)),
    lf_lines = sum(bytes == as.raw(0x0A)),
    header_has_tab = grepl("\t", head_line, fixed = TRUE)
  )
}

# Storage type that distinguishes whole-number columns from fractional ones;
# readr parses both as double.
observed_type <- function(v) {
  if (is.character(v)) return("character")
  if (is.numeric(v) && all(v == round(v), na.rm = TRUE)) return("integer-valued")
  if (is.numeric(v)) return("fractional")
  class(v)[1L]
}

column_inventory <- function(df) {
  data.frame(
    position = seq_along(df),
    name = names(df),
    name_escaped = encodeString(names(df)),
    r_class = vapply(df, function(v) class(v)[1L], character(1)),
    observed_type = vapply(df, observed_type, character(1)),
    n_missing = vapply(df, function(v) sum(is.na(v)), integer(1)),
    n_distinct = vapply(df, function(v) length(unique(v)), integer(1)),
    row.names = NULL, stringsAsFactors = FALSE
  )
}

# --- Official source ----------------------------------------------------------

official_urls <- function(meta) {
  slug <- basename(meta$data$repository_url)
  list(
    page = meta$data$repository_url,
    api = UCI_API,
    archive = sprintf("https://archive.ics.uci.edu/static/public/%d/%s.zip", UCI_ID, slug)
  )
}

fetch_official <- function(dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  api_path <- file.path(dir, "uci_api.json")
  utils::download.file(UCI_API, api_path, mode = "wb", quiet = TRUE)
  meta <- jsonlite::fromJSON(api_path, simplifyVector = FALSE)
  if (!identical(meta$status, 200L)) stop("UCI API did not report status 200.", call. = FALSE)
  urls <- official_urls(meta)
  zip_path <- file.path(dir, "uci_archive.zip")
  utils::download.file(urls$archive, zip_path, mode = "wb", quiet = TRUE)
  members <- utils::unzip(zip_path, list = TRUE)$Name
  if (!"data.csv" %in% members) stop("Archive has no data.csv member: ", paste(members, collapse = ", "), call. = FALSE)
  extract_dir <- file.path(dir, "extracted")
  dir.create(extract_dir, showWarnings = FALSE)
  utils::unzip(zip_path, files = "data.csv", exdir = extract_dir, overwrite = TRUE)
  list(meta = meta, urls = urls, api_path = api_path, zip_path = zip_path,
       members = members, csv = file.path(extract_dir, "data.csv"),
       retrieved_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
}

# Raw byte comparison first. If bytes differ, separate encoding/line-ending/header
# differences from value differences using parsed tables.
compare_sources <- function(local_csv, official_csv) {
  raw_equal <- identical(sha256_file(local_csv), sha256_file(official_csv))
  out <- list(raw_sha256_equal = raw_equal, method = "SHA-256 of raw bytes")
  if (raw_equal) {
    out$outcome <- "identical"
    return(out)
  }
  a <- import_source(local_csv)$data
  b <- import_source(official_csv)$data
  names_equal <- identical(names(a), names(b))
  names_norm_equal <- identical(normalize_name(names(a)), normalize_name(names(b)))
  dims_equal <- identical(dim(a), dim(b))
  values_equal <- dims_equal && names_norm_equal && isTRUE(all.equal(unname(as.list(a)), unname(as.list(b))))
  out$method <- "SHA-256 of raw bytes, then parsed-table comparison"
  out$header_equal <- names_equal
  out$header_equal_after_trim <- names_norm_equal
  out$dims_equal <- dims_equal
  out$values_equal <- values_equal
  out$outcome <- if (values_equal) "same values, different bytes" else "values differ"
  out
}

# --- Metadata -----------------------------------------------------------------

# Split a UCI code description such as "1 - single 2 - married" into codes and
# labels. A code is digits followed by a spaced dash; labels run to the next code.
parse_code_description <- function(text) {
  text <- gsub("\\s+", " ", trimws(text))
  m <- gregexpr("(^|[ ;])[0-9]+ [-–] ", text, perl = TRUE)[[1L]]
  if (m[1L] == -1L) return(data.frame(code = character(), label = character()))
  starts <- as.integer(m)
  lens <- attr(m, "match.length")
  tokens <- substring(text, starts, starts + lens - 1L)
  codes <- sub("^[ ;]?([0-9]+) .*$", "\\1", tokens)
  label_start <- starts + lens
  label_end <- c(starts[-1L] - 1L, nchar(text))
  labels <- trimws(sub(";$", "", trimws(substring(text, label_start, label_end))))
  data.frame(code = codes, label = labels, stringsAsFactors = FALSE)
}

# Variables whose UCI description is not a code list.
UNCODED <- c("previous qualification (grade)", "admission grade", "age at enrollment",
             "curricular units 1st sem (credited)", "curricular units 1st sem (enrolled)",
             "curricular units 1st sem (evaluations)", "curricular units 1st sem (approved)",
             "curricular units 1st sem (grade)", "curricular units 1st sem (without evaluations)",
             "curricular units 2nd sem (credited)", "curricular units 2nd sem (enrolled)",
             "curricular units 2nd sem (evaluations)", "curricular units 2nd sem (approved)",
             "curricular units 2nd sem (grade)", "curricular units 2nd sem (without evaluations)",
             "unemployment rate", "inflation rate", "gdp", "target", "application order")

# Source-defined "unknown / blank / other" categories. These are real categories,
# not NA.
is_source_unknown <- function(label) {
  grepl("^(unknown|\\(blank\\)|other situation)$", tolower(trimws(label)))
}

build_category_codes <- function(api_vars, csv_names) {
  rows <- list()
  for (v in api_vars) {
    key <- normalize_name(v$name)
    if (key %in% UNCODED) next
    parsed <- parse_code_description(v$description)
    idx <- match(key, normalize_name(csv_names))
    rows[[length(rows) + 1L]] <- data.frame(
      variable = csv_names[idx], code = parsed$code, label = parsed$label,
      source_unknown = is_source_unknown(parsed$label),
      reference = paste0(UCI_PAGE, " (variable metadata: ", v$name, ")"),
      stringsAsFactors = FALSE
    )
  }
  # Application order: UCI defines only the endpoints.
  idx <- match("application order", normalize_name(csv_names))
  rows[[length(rows) + 1L]] <- data.frame(
    variable = csv_names[idx], code = c("0", "9"),
    label = c("first choice", "last choice"), source_unknown = FALSE,
    reference = paste0(UCI_PAGE, " (variable metadata: Application order; endpoints only)"),
    stringsAsFactors = FALSE
  )
  out <- do.call(rbind, rows)
  out$code_num <- as.integer(out$code)
  out <- out[order(match(out$variable, csv_names), out$code_num), ]
  out$code_num <- NULL
  rownames(out) <- NULL
  out
}

build_variables <- function(df, api_vars) {
  inv <- column_inventory(df)
  key <- normalize_name(inv$name)
  api_key <- normalize_name(vapply(api_vars, function(v) v$name, character(1)))
  ann <- VARIABLE_ANNOTATIONS[match(key, VARIABLE_ANNOTATIONS$key), ]
  api_i <- match(key, api_key)
  pick <- function(field) vapply(api_i, function(i) {
    val <- if (is.na(i)) NA_character_ else api_vars[[i]][[field]]
    if (is.null(val)) NA_character_ else as.character(val)
  }, character(1))
  notes <- vapply(seq_len(nrow(inv)), function(i) {
    n <- character()
    if (!is.na(api_i[i]) && !identical(inv$name[i], api_vars[[api_i[i]]]$name)) {
      n <- c(n, sprintf("CSV header %s differs from UCI name %s.", dQuote(inv$name_escaped[i], FALSE), dQuote(api_vars[[api_i[i]]]$name, FALSE)))
    }
    api_type <- pick("type")[i]
    if (!is.na(api_type) && api_type == "Integer" && inv$observed_type[i] == "fractional") {
      n <- c(n, "UCI type is Integer but the file contains fractional values.")
    }
    if (nzchar(ann$annotation_note[i])) n <- c(n, ann$annotation_note[i])
    paste(n, collapse = " ")
  }, character(1))
  data.frame(
    position = inv$position,
    original_name = inv$name,
    source_role = pick("role"),
    source_definition = pick("description"),
    source_type = pick("type"),
    observed_storage_type = inv$observed_type,
    proposed_analytical_type = ann$analytical_type,
    units = ann$units,
    timing_group = ann$timing_group,
    source_reference = paste0(UCI_PAGE, " (variable metadata)"),
    notes = notes,
    stringsAsFactors = FALSE
  )
}

# Variables for which UCI defines only range endpoints, not a full code list.
df_endpoint_only <- function(csv_names) csv_names[normalize_name(csv_names) == "application order"]

# Ranges stated in the UCI definitions, compared with observed values.
SOURCE_RANGES <- data.frame(
  key = c("application order", "previous qualification (grade)", "admission grade",
          "curricular units 1st sem (grade)", "curricular units 2nd sem (grade)"),
  lower = c(0, 0, 0, 0, 0), upper = c(9, 200, 200, 20, 20), stringsAsFactors = FALSE
)

range_checks <- function(df) {
  idx <- match(SOURCE_RANGES$key, normalize_name(names(df)))
  out <- data.frame(
    variable = names(df)[idx], source_lower = SOURCE_RANGES$lower, source_upper = SOURCE_RANGES$upper,
    observed_min = vapply(idx, function(i) min(df[[i]], na.rm = TRUE), numeric(1)),
    observed_max = vapply(idx, function(i) max(df[[i]], na.rm = TRUE), numeric(1)),
    stringsAsFactors = FALSE
  )
  out$n_outside <- vapply(seq_along(idx), function(k) {
    v <- df[[idx[k]]]
    sum(v < out$source_lower[k] | v > out$source_upper[k], na.rm = TRUE)
  }, numeric(1))
  out
}

# Observed codes versus documented codes for every coded variable.
code_coverage <- function(df, codes) {
  out <- list()
  for (v in setdiff(unique(codes$variable), df_endpoint_only(names(df)))) {
    obs <- table(df[[v]], useNA = "no")
    documented <- codes$code[codes$variable == v]
    observed <- names(obs)
    out[[length(out) + 1L]] <- data.frame(
      variable = v,
      n_documented = length(documented),
      n_observed = length(observed),
      observed_undocumented = paste(sort(setdiff(observed, documented)), collapse = " "),
      documented_unobserved = paste(sort(setdiff(documented, observed)), collapse = " "),
      n_rows_undocumented = sum(obs[setdiff(observed, documented)]),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, out)
}

write_csv_stable <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "", fileEncoding = "UTF-8", eol = "\n")
}

read_json_file <- function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)
