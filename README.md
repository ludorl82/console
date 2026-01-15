# Build & Bootstrap of Console

## Building the Image

### Build for Local Architecture Only
To build the image for your current architecture (ARM64 on Raspberry Pi 5, AMD64 on x86_64):
```bash
docker compose build
```

### Build Multi-Architecture Image for Registry

#### One-time Setup
Create a multi-architecture builder (only need to do this once):
```bash
# Create and configure the builder
docker buildx create --name multiarch --driver docker-container --use

# Verify builder supports multiple platforms
docker buildx inspect --bootstrap
```

#### Build and Push to Registry
Build for both AMD64 and ARM64 architectures and push to Docker Hub:
```bash
# Login to Docker Hub (if not already logged in)
docker login

# Build and push multi-arch image
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg USER=$(whoami) \
  -t ludorl82/console:latest \
  --push \
  .
```

#### Build with Version Tag
To also tag with a specific version:
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg USER=$(whoami) \
  -t ludorl82/console:latest \
  -t ludorl82/console:v1.0.0 \
  --push \
  .
```

## Using the Image

### Run from Local Build
To build and run the container locally:
```bash
docker compose up -d
```

### Run from Registry
To pull and run the pre-built image from Docker Hub:
```bash
# Pull the latest image
docker compose pull

# Start the container
docker compose up -d
```

The image will automatically use the correct architecture for your system (ARM64 for Raspberry Pi 5, AMD64 for x86_64).

## Connecting to the Console

### Attach to Container Locally
```bash
ssh -p 2222 $(whoami)@localhost
```

### Attach to Container Remotely
Replace `<hostname>` with your server's hostname or IP address:
```bash
ssh -p 2222 $(whoami)@<hostname>
```

## Managing the Container

### View Container Logs
```bash
docker compose logs -f console
```

### Restart Container
```bash
docker compose restart console
```

### Stop Container
```bash
docker compose down
```

### Rebuild and Restart
If you've made changes to the Dockerfile:
```bash
docker compose up -d --build
```
