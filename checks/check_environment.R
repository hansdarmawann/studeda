# Noninstalling environment verification. Source and call run_environment_check()
# (returns 0 on success, 1 on failure), or run directly with Rscript.
if (!exists("project_root", mode = "function")) {
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))[1L]
  source(file.path(dirname(normalizePath(f)), "..", "R", "project.R"))
}

run_environment_check <- function() {
  root <- project_root()
  failures <- character()
  report <- function(ok, label, detail = "", required = TRUE) {
    status <- if (ok) "OK     " else if (required) "FAIL   " else "MISSING"
    cat(sprintf("[%s] %s%s\n", status, label, if (nzchar(detail)) paste0(": ", detail) else ""))
    if (!ok && required) failures <<- c(failures, label)
  }

  report(TRUE, "R", R.version.string)
  report(file.exists(file.path(root, "data.csv")), "data.csv present")
  report(file.exists(file.path(root, "renv.lock")), "renv.lock present")
  report(file.exists(file.path(root, "renv", "activate.R")), "renv activation present")

  miss <- missing_packages()
  report(length(miss) == 0L, "required packages installed",
         if (length(miss)) paste("missing:", paste(miss, collapse = ", "))
         else paste(PROJECT_PACKAGES, collapse = ", "))

  if (requireNamespace("renv", quietly = TRUE) && file.exists(file.path(root, "renv.lock"))) {
    st <- tryCatch(renv::status(project = root), error = function(e) NULL)
    report(!is.null(st) && isTRUE(st$synchronized), "renv synchronized with renv.lock")
  }

  quarto <- find_quarto()
  report(!is.na(quarto), "Quarto",
         if (is.na(quarto)) "not found; needed from the share stage" else quarto,
         required = FALSE)
  gh <- find_gh()
  report(!is.na(gh), "GitHub CLI",
         if (is.na(gh)) "not found; needed only for PR creation" else gh,
         required = FALSE)

  if (length(failures)) {
    cat("Environment check FAILED: ", paste(failures, collapse = "; "), "\n", sep = "")
    1L
  } else {
    cat("Environment check passed.\n")
    0L
  }
}

if (sys.nframe() == 0L && !interactive()) quit(status = run_environment_check())
