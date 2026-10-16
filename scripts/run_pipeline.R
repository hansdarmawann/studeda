# Stable stage/track CLI.
#   Rscript scripts/run_pipeline.R --check-environment
#   Rscript scripts/run_pipeline.R --through prepare|process|analyze|share|act
#                                  [--track profile|demographics|academic|all]
# Stages that are not implemented yet fail explicitly; nothing is simulated.
local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))[1L]
  source(file.path(dirname(normalizePath(f)), "..", "R", "project.R"), local = FALSE)
})

STAGES <- c("prepare", "process", "analyze", "share", "act")
TRACKS <- c("profile", "demographics", "academic")

usage <- function(msg = NULL) {
  if (!is.null(msg)) cat("Error: ", msg, "\n\n", sep = "")
  cat(paste(
    "Usage: Rscript scripts/run_pipeline.R --check-environment",
    "       Rscript scripts/run_pipeline.R --through prepare|process|analyze|share|act",
    "                                      [--track profile|demographics|academic|all]",
    "", sep = "\n"))
  quit(status = 2L)
}

parse_args <- function(args) {
  opts <- list(check_env = FALSE, through = NULL, track = "all")
  i <- 1L
  while (i <= length(args)) {
    a <- args[i]
    if (a == "--check-environment") {
      opts$check_env <- TRUE
    } else if (a %in% c("--through", "--track")) {
      if (i == length(args) || startsWith(args[i + 1L], "--")) usage(paste(a, "needs a value"))
      v <- args[i + 1L]
      if (a == "--through") {
        if (!v %in% STAGES) usage(paste0("invalid stage '", v, "'"))
        opts$through <- v
      } else {
        if (!v %in% c(TRACKS, "all")) usage(paste0("invalid track '", v, "'"))
        opts$track <- v
      }
      i <- i + 1L
    } else {
      usage(paste0("unknown argument '", a, "'"))
    }
    i <- i + 1L
  }
  if (!opts$check_env && is.null(opts$through)) usage("nothing to do")
  opts
}

# Each step is list(label, script) for Rscript, or list(label, quarto) for Quarto.
build_plan <- function(through, track) {
  upto <- match(through, STAGES)
  plan <- list()
  add <- function(label, script) plan[[length(plan) + 1L]] <<- list(label = label, script = script)
  add("prepare", "scripts/02_prepare.R")
  add("check source", "checks/check_source.R")
  if (upto >= 2L) {
    add("process", "scripts/03_process.R")
    add("check data", "checks/check_data.R")
  }
  if (upto >= 3L) {
    entry <- c(profile = "04a_profile", demographics = "04b_demographics", academic = "04c_academic")
    for (t in if (track == "all") TRACKS else track) {
      add(paste("analyze:", t), file.path("scripts", paste0(entry[[t]], ".R")))
      add(paste("check", t), file.path("checks", paste0("check_", t, ".R")))
    }
    if (track == "all") {
      add("analyze: integrate", "scripts/04_integrate.R")
      add("check analysis", "checks/check_analysis.R")
    }
  }
  if (upto >= 4L) plan[[length(plan) + 1L]] <- list(label = "share: render report", quarto = "reports/eda.qmd")
  if (upto >= 5L) add("act: check actions", "checks/check_actions.R")
  plan
}

required_file <- function(step) if (!is.null(step$quarto)) step$quarto else step$script

run_step <- function(step, root) {
  cat("==> ", step$label, "\n", sep = "")
  if (!is.null(step$quarto)) {
    quarto <- find_quarto()
    if (is.na(quarto)) {
      cat("Quarto not found.\n")
      return(1L)
    }
    return(system2(quarto, c("render", step$quarto)))
  }
  system2(find_rscript(), shQuote(file.path(root, step$script)))
}

opts <- parse_args(commandArgs(trailingOnly = TRUE))
root <- project_root()
setwd(root)

if (opts$check_env) {
  source(file.path(root, "checks", "check_environment.R"))
  status <- run_environment_check()
  if (status != 0L || is.null(opts$through)) quit(status = status)
}

plan <- build_plan(opts$through, opts$track)
needed <- vapply(plan, required_file, character(1))
absent <- needed[!file.exists(file.path(root, needed))]
if (length(absent) > 0L) {
  cat("Cannot run --through ", opts$through,
      ": these stage files are not implemented yet:\n", sep = "")
  cat(paste0("  - ", absent, "\n"), sep = "")
  quit(status = 1L)
}

ensure_output_dirs(root)
for (step in plan) {
  status <- run_step(step, root)
  if (!identical(as.integer(status), 0L)) {
    cat("Step failed: ", step$label, " (status ", status, ")\n", sep = "")
    quit(status = 1L)
  }
}
cat("Pipeline completed through ", opts$through, ".\n", sep = "")
