library(deSolve)

# Define the parameters
num_species <- 10
r <- rep(1, num_species) # Growth rates
alpha <- matrix(0.1, nrow = num_species, ncol = num_species) # Interaction coefficients
diag(alpha) <- 1 # Intraspecific interactions

# Define the Lotka-Volterra model
lv_model <- function(time, state, parameters) {
    with(as.list(c(state, parameters)), {
        dN <- numeric(num_species)
        for (i in 1:num_species) {
            dN[i] <- state[i] * (r[i] - sum(alpha[i, ] * state))
        }
        list(dN)
    })
}

# Initial populations
initial_populations <- runif(num_species, 0.5, 1.5) # Random initial populations

# Time sequence
times <- seq(0, 100000, by = 0.1)

# Solve the differential equations
start_time <- Sys.time()
out <- ode(y = initial_populations, times = times, func = lv_model, parms = list(r = r, alpha = alpha))
end_time <- Sys.time()

end_time - start_time
