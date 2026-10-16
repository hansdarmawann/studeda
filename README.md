# studeda

Reproducible R/Quarto exploratory analysis of the UCI dataset "Predict Students' Dropout and Academic Success".

Sources:
https://archive.ics.uci.edu/dataset/697/predict+students+dropout+and+academic+success
https://viniciusarz.medium.com/6-phases-of-data-analytics-projects-googles-methodology-f8caa09c9929
https://www.ibm.com/think/topics/data-wrangling

## Setup and reproduction

```text
Rscript scripts/bootstrap.R
Rscript scripts/run_pipeline.R --check-environment
Rscript scripts/run_pipeline.R --through share
```

Analytical stages are added in later phases; requesting one that does not exist yet fails explicitly. See [docs/project-contract.md](docs/project-contract.md) for the workflow and interfaces.
