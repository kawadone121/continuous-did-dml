# Kernel-based Continuous Difference-in-Differences with DML: Simulation Study

This repository contains the simulation code used in my master’s thesis, which investigates how the choice of kernel bandwidth in kernel-based continuous treatment estimation methods affects estimation performance. This study focuses on a kernel-based continuous difference-in-differences (DiD) method with double/debiased machine learning (DML) proposed by [Haddad et al. (2024)](http://arxiv.org/abs/2410.21105), which can identify the average treatment effect on the treated (ATT) for non-zero time-varying continuous treatment and control levels under a high-dimensional covariate setting.  

Simulations are implemented in R, executed on Google Cloud using Docker, summarized using SQL, and visualized in Python.

## Simulation Pipeline

### Estimation (R)

- The simulation is implemented in the R script [`simulation.R`](./scripts/simulation.R).
- It simulates repeated cross-section data under different conditions: sample sizes (`N`), treatment levels (`d`), and bandwidth scaling factors (`c`). Control level (`d'`) is fixed at 2.
- For each parameter combination, 5,000 replications are performed with parallel execution using `foreach` and `doParallel`.
- The `didcontDML` function from the [`causalweight`](https://CRAN.R-project.org/package=causalweight) package is used to estimate the ATT at each treatment level.
- Lasso regression is used as the first-stage estimator, with 3-fold cross-fitting for estimating nuisance parameters. Observations with excessively large weights are excluded for stability.

### Execution (Docker, Google Cloud)

- The simulation runs inside a Docker container defined in the [`docker/`](./docker/) directory. The image is based on `rocker/r-ver:4.5.0` and includes required R packages and the Google Cloud SDK.
- A GCE VM is created using [`create_vm.sh`](./create_vm.sh), which sets [`startup.sh`](./startup.sh) as a startup script. This script pulls the Docker image from Artifact Registry and starts the container.
- Inside the container, [`entrypoint.sh`](./docker/entrypoint.sh) is executed as the Docker entrypoint. It launches the R simulation script, saves the results and logs to Cloud Storage (GCS), and uploads them to BigQuery (BQ) for further analysis.
- Simulations were split into subsets of 1,000 or 2,000 runs each, and executed on five preemptible GCE instances (`c2d-highcpu-16` or `c2d-highcpu-32`) in parallel to reduce cost and runtime. The total computation time across all machines was approximately 545 hours.

### Aggregation (SQL)

- The [`sql/`](./sql/) directory contains BQ-compatible SQL scripts:
  - [`summary.sql`](./sql/summary.sql): Computes bias, standard deviation, RMSE, and coverage rate
  - [`non_null_simulation_results.sql`](./sql/non_null_simulation_results.sql): Selects the first 4,000 valid (non-missing) simulation results for each combination
- The query results are stored in [`./visualization/csv/`](./visualization/csv/) for visualization.

### Visualization (Python)

- The [`visualization/`](./visualization/) directory includes:
  - [`visualization.py`](./visualization/visualization.py): Main script using Plotly to plot figures
  - [`csv/`](./visualization/csv/): Stores query results from BQ
  - [`png/`](./visualization/png/): Stores final plots
- Python environment is managed using Poetry with [`pyproject.toml`](./pyproject.toml) and [`poetry.lock`](./poetry.lock) to specify dependencies.

### Logs and Archives

- [`logs/`](./logs/) stores plain-text logs recording simulation start and end times, as well as total runtime.
- [`scripts_archive/`](./scripts_archive/) contains timestamped backups of previous versions of the simulation script for reproducibility and traceability.

## License

This project is licensed under the Apache License 2.0. See the [`LICENSE`](./LICENSE) file for details.

## References

- Haddad, M. F. C., Huber, M., and Zhang, L. Z. (2024).  
  Difference-in-Differences with Time-varying Continuous Treatments using Double/Debiased Machine Learning. [arXiv:2410.21105](https://arxiv.org/abs/2410.21105)

- Bodory, H., Huber, M., and Kueck, J. (2025).  
  causalweight: Estimation Methods for Causal Inference Based on Inverse Probability Weighting and Doubly Robust Estimation. [CRAN](https://CRAN.R-project.org/package=causalweight)
