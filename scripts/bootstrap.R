# Dependency setup. Without flags: initialize or restore the project-local renv
# environment (installs packages). With --check: verify only, never install.
local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))[1L]
  source(file.path(dirname(normalizePath(f)), "..", "R", "project.R"), local = FALSE)
})

args <- commandArgs(trailingOnly = TRUE)
unknown <- setdiff(args, "--check")
if (length(unknown) > 0L) {
  cat("Usage: Rscript scripts/bootstrap.R [--check]\nUnknown argument(s): ",
      paste(unknown, collapse = " "), "\n", sep = "")
  quit(status = 2L)
}

root <- project_root()
setwd(root)

if ("--check" %in% args) {
  source(file.path(root, "checks", "check_environment.R"))
  quit(status = run_environment_check())
}

if (!requireNamespace("renv", quietly = TRUE)) {
  message("Installing renv into the user library...")
  user_lib <- Sys.getenv("R_LIBS_USER")
  dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(user_lib, .libPaths()))
  install.packages("renv", lib = user_lib, repos = "https://cloud.r-project.org")
}
if (!requireNamespace("renv", quietly = TRUE)) stop("renv could not be installed.", call. = FALSE)

if (file.exists("renv.lock")) {
  message("renv.lock found: restoring.")
  if (!file.exists("renv/activate.R")) renv::activate()
  renv::restore(prompt = FALSE)
} else {
  message("No renv.lock: initializing a bare project environment and installing packages.")
  renv::init(bare = TRUE, restart = FALSE)
  renv::install(setdiff(PROJECT_PACKAGES, "renv"), prompt = FALSE)
  renv::snapshot(packages = PROJECT_PACKAGES, prompt = FALSE)
}
ensure_output_dirs(root)
message("Bootstrap finished. Verify with: Rscript scripts/bootstrap.R --check")
