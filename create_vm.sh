# Create a new Google Compute Engine VM instance with specified configuration
gcloud compute instances create continuous-did-dml-vm-3 \
  --zone=us-central1-a \
  --machine-type=c2d-highcpu-16 \
  --preemptible \
  --no-restart-on-failure \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --metadata-from-file startup-script=startup.sh,env=.env \
  --service-account=dummy-service-account@your-project-id.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/cloud-platform
