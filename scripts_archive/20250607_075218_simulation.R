# Redirect all output to a log file and also print to console
sink("simulation_log.txt", split = TRUE)

# Load required libraries
library(causalweight)
library(doParallel)
library(foreach)

# Function to generate data according to a specified DGP
generate_dgp <- function(N, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)  # Set seed for reproducibility
  
  # Assign pre-treatment and post-treatment periods randomly
  t <- rbinom(N, 1, 0.5)

  # Generate high-dimensional covariates
  k <- 50
  X <- matrix(rnorm(N * k, 0, 1), nrow = N, ncol = k)

  # Generate treatment group assignment probabilities using a logistic function
  gamma <- 0.5 / ((1:k)^2)
  p <- 1 / (1 + exp(- X %*% gamma))

  # Define two different treatment intensities based on probability threshold
  delta_h <- 5
  delta_l <- 2
  alpha <- 0.5 / ((1:k)^2)
  u <- rnorm(N, 0, 1)
  v <- rnorm(N, 0, 1)
  d_h <- abs(delta_h + X %*% alpha + u)  # High intensity
  d_l <- abs(delta_l + X %*% alpha + v)  # Low intensity
  d <- ifelse(p >= 0.5, d_h, d_l)        # Assign intensity

  # Generate the outcome variable as a function of covariates and treatment
  beta <- 0.5 / ((1:k)^2)
  e <- rnorm(N, 0, 1)
  y <- X %*% beta + (1 + d^2) * t + e

  return(list(y = y, d = d, t = t, X = X))
}

# Function to run the simulation study
run_simulation <- function(dgp_func, S, treatment, control, N_list, bwfactor_list, seed) {
  start_time <- Sys.time()
  cat(sprintf("[START] Simulation started at %s\n", start_time))

  # Set up parallel backend using all available cores
  cl <- makeCluster(parallel::detectCores())
  registerDoParallel(cl)

  # Create a grid of all combinations of N and bwfactor
  combo_grid <- expand.grid(
    N = N_list,
    bwfactor = bwfactor_list,
    stringsAsFactors = FALSE
  )
  K <- nrow(combo_grid)
  
  # Run simulations in parallel for each combination
  results_list <- foreach(j = 1:K, .packages = c("causalweight")) %dopar% {
    N <- combo_grid$N[j]
    bwfactor <- combo_grid$bwfactor[j]

    atet_vec <- numeric(S)
    se_vec <- numeric(S)

    # Repeat simulation S times for each combination
    for (i in 1:S) {
      current_seed <- seed + i

      result <- tryCatch({
        data <- dgp_func(N, seed = current_seed)

        # Estimate ATET using didcontDML
        res <- didcontDML(
          y = data$y, d = data$d, t = data$t, controls = data$X,
          dtreat = treatment, dcontrol = control,
          MLmethod = "lasso",
          bw = N^(-1/4),
          bwfactor = bwfactor
        )

        list(atet = res$ATET, se = res$se)

      }, error = function(e) {
        # The estimation can fail due to lack of the local neighborhood when the bandwidth is too small.
        # In such cases, we return NA for atet and se.
        list(atet = NA, se = NA)
      })

      atet_vec[i] <- result$atet
      se_vec[i] <- result$se
    }

    list(atet = atet_vec, se = se_vec)
  }

  stopCluster(cl)  # Stop parallel backend

  # Combine results into matrices
  atet_matrix <- do.call(cbind, lapply(results_list, function(x) x$atet))
  se_matrix <- do.call(cbind, lapply(results_list, function(x) x$se))

  # Label columns by parameter combinations
  labels <- paste0("N_", combo_grid$N, "_bwfactor_", combo_grid$bwfactor)
  colnames(atet_matrix) <- labels
  colnames(se_matrix) <- labels

  # Prepare long format results
  repeated_combo <- combo_grid[rep(1:K, each = S), ]
  seed_vec <- rep(seed + seq_len(S), times = K)

  long_results <- data.frame(
    treatment = treatment,
    control = control,
    true_effect = treatment^2 - control^2,
    N = repeated_combo$N,
    bwfactor = repeated_combo$bwfactor,
    atet = as.vector(atet_matrix),
    se = as.vector(se_matrix),
    seed = seed_vec
  )

  # Calculate confidence intervals
  long_results$ci_lower <- long_results$atet - qnorm(1 - 0.05 / 2) * long_results$se
  long_results$ci_upper <- long_results$atet + qnorm(1 - 0.05 / 2) * long_results$se

  # Add coverage indicator
  long_results$coverage <- as.integer(
    long_results$true_effect >= long_results$ci_lower & long_results$true_effect <= long_results$ci_upper
  )

  # Reorder columns for clarity
  long_results <- long_results[, c(
    "treatment", "control", "true_effect", "N", "bwfactor",
    "atet", "se", "ci_lower", "ci_upper", "coverage", "seed"
  )]

  # Write results to a single CSV file
  write.csv(long_results, file = "simulation_results.csv", row.names = FALSE, na = "")

  end_time <- Sys.time()
  elapsed <- difftime(end_time, start_time, units = "mins")
  cat(sprintf("[END] Simulation completed at %s (Elapsed: %.2f min)\n", end_time, as.numeric(elapsed)))
}

# Run the simulation with specified parameters
run_simulation(
  dgp_func = generate_dgp,
  S = 1000,
  treatment = 5,
  control = 2,
  N_list = c(2000, 8000),
  bwfactor_list = c(0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0),
  seed = 0
)

sink()  # Stop redirecting output
quit(save = "no")  # Exit R session without saving workspace
