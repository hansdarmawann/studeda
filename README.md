# studeda

Reproducible R/Quarto exploratory analysis of the UCI dataset "Predict Students' Dropout and Academic Success".

https://archive.ics.uci.edu/dataset/697/predict+students+dropout+and+academic+success

## Setup and reproduction

```text
Rscript scripts/bootstrap.R
Rscript scripts/run_pipeline.R --check-environment
Rscript scripts/run_pipeline.R --through share
```

Analytical stages are added in later phases; requesting one that does not exist yet fails explicitly. See [docs/project-contract.md](docs/project-contract.md) for the workflow and interfaces.
