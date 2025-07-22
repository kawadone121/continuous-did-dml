# Use the official R base image (version 4.5.0)
FROM rocker/r-ver:4.5.0

# Install Google Cloud SDK and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
   apt-transport-https ca-certificates gnupg curl tzdata \
   # Download and add the Google Cloud public signing key
 && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
   | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
   # Add the Google Cloud SDK repository
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
   | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
   # Install the Google Cloud CLI
 && apt-get update && apt-get install -y google-cloud-cli \
   # Clean up to reduce image size
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install required R packages from CRAN
RUN Rscript -e "install.packages(c('causalweight', 'doParallel', 'foreach'), repos='https://cloud.r-project.org')"

# Copy entrypoint script into the container
COPY entrypoint.sh /entrypoint.sh
# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
