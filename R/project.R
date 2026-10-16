# Shared project helpers. Sourced by scripts and checks; keep free of analysis.

PROJECT_PACKAGES <- c(
  "renv", "readr", "dplyr", "tidyr", "ggplot2", "janitor",
  "here", "knitr", "rmarkdown", "jsonlite", "yaml", "digest"
)

# Static declaration so renv's implicit snapshot detects the managed set.
# Never called; later phases load packages where they use them.
.declare_dependencies <- function() {
  library(renv); library(readr); library(dplyr); library(tidyr)
  library(ggplot2); library(janitor); library(here); library(knitr)
  library(rmarkdown); library(jsonlite); library(yaml); library(digest)
}

PROJECT_SEED <- 20261016L

# Directories for generated, git-ignored artifacts (relative to project root).
OUTPUT_DIRS <- c(
  "data/interim", "data/processed",
  "outputs/tables", "outputs/figures", "outputs/logs"
)

# Directory of the running Rscript file, or the working directory otherwise.
script_dir <- function() {
  file_arg <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  if (length(file_arg) >= 1L) dirname(normalizePath(file_arg[1L])) else getwd()
}

project_root <- function(start = script_dir()) {
  dir <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(dir, "studeda.Rproj"))) return(dir)
    parent <- dirname(dir)
    if (identical(parent, dir)) stop("Cannot find project root (studeda.Rproj).", call. = FALSE)
    dir <- parent
  }
}

project_path <- function(...) file.path(project_root(), ...)

missing_packages <- function(pkgs = PROJECT_PACKAGES) {
  pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
}

require_packages <- function(pkgs = PROJECT_PACKAGES) {
  miss <- missing_packages(pkgs)
  if (length(miss) > 0L) {
    stop("Missing packages: ", paste(miss, collapse = ", "),
         ". Run: Rscript scripts/bootstrap.R", call. = FALSE)
  }
  invisible(TRUE)
}

set_project_seed <- function() {
  set.seed(PROJECT_SEED)
  invisible(PROJECT_SEED)
}

ensure_output_dirs <- function(root = project_root()) {
  dirs <- file.path(root, OUTPUT_DIRS)
  for (d in dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  invisible(dirs)
}

# Locate an executable from an environment override, PATH, or known install
# locations. Never modifies PATH. Returns NA_character_ when not found.
find_tool <- function(name, env_var = NULL, candidates = character()) {
  if (!is.null(env_var) && nzchar(Sys.getenv(env_var)) && file.exists(Sys.getenv(env_var))) {
    return(normalizePath(Sys.getenv(env_var), winslash = "/"))
  }
  on_path <- Sys.which(name)[[1L]]
  if (nzchar(on_path)) return(normalizePath(on_path, winslash = "/"))
  found <- candidates[file.exists(candidates)]
  if (length(found) > 0L) return(normalizePath(found[1L], winslash = "/"))
  NA_character_
}

find_quarto <- function() {
  local <- Sys.getenv("LOCALAPPDATA")
  find_tool("quarto", "QUARTO_PATH", c(
    file.path(local, "Programs/Quarto/bin/quarto.exe"),
    "C:/Program Files/Quarto/bin/quarto.exe",
    file.path(local, "Programs/RStudio/resources/app/bin/quarto/bin/quarto.exe"),
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"
  ))
}

find_gh <- function() {
  find_tool("gh", "GH_PATH", c(
    "C:/Program Files/GitHub CLI/gh.exe",
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs/GitHub CLI/gh.exe")
  ))
}

find_rscript <- function() {
  file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
}
