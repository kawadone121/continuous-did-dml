#!/bin/bash
set -e

# Set timezone to Europe/Amsterdam
echo "[INFO] Setting timezone to Europe/Amsterdam..."
apt-get update
apt-get install -y tzdata

ln -fs /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

# Get current timestamp in Amsterdam time
timestamp=$(date +%Y%m%d_%H%M%S)
echo "[INFO] [$timestamp] Started startup script"

# Install Docker and required dependencies
echo "[INFO] Installing Docker and dependencies..."
apt-get update
apt-get install -y docker.io apt-transport-https ca-certificates curl gnupg lsb-release

# Start and enable Docker service
echo "[INFO] Starting Docker service..."
systemctl start docker
systemctl enable docker

# Fetch environment variables from Google Cloud instance metadata
echo "[INFO] Fetching environment variables from instance metadata..."
mkdir -p /etc/docker
curl -f -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/env" \
  -o /etc/docker/.env

# Check if the .env file was created
if [ ! -f /etc/docker/.env ]; then
  echo "[ERROR] /etc/docker/.env not created."
  exit 1
fi

# Check if the .env file is not empty
if [ ! -s /etc/docker/.env ]; then
  echo "[ERROR] /etc/docker/.env is empty."
  cat /etc/docker/.env
  exit 1
fi

# Output the contents of the .env file for verification
echo "[INFO] Contents of /etc/docker/.env:"
cat /etc/docker/.env

# Export environment variables from the .env file
echo "[INFO] Exporting environment variables..."
export $(grep -v '^#' /etc/docker/.env | xargs)

# Configure Docker authentication for Google Artifact Registry
echo "[INFO] Configuring authentication for Artifact Registry..."
gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

# Pull the Docker image specified in the environment variables
echo "[INFO] Pulling Docker image: $DOCKER_IMAGE"
docker pull "$DOCKER_IMAGE"

# Run the simulation container with the environment variables
echo "[INFO] Running simulation container..."
docker run --rm --env-file /etc/docker/.env "$DOCKER_IMAGE"

# Delete the VM instance after simulation completes
echo "[INFO] Simulation completed. Shutting down VM..."
gcloud compute instances delete "$(hostname)" --zone=us-central1-a --quiet
