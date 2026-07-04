# Build & Bootstrap of Console

## Building the Image

### Build for Local Architecture Only
The Docker CLI (socket access) and the non-root user are provisioned by
devcontainer Features declared in `.devcontainer/devcontainer.json`, not by
the Dockerfile itself. Build with the devcontainer CLI to get a complete
image:
```bash
npx @devcontainers/cli build --workspace-folder . --image-name ludorl82/console:local
```

Plain `docker compose build` still works and is faster, but skips Features
-- useful only for quickly checking that the base Dockerfile itself (locale,
neovim, tmux/tmuxinator, Node, sshd) still builds. The resulting image has
no docker CLI and stays root-only:
```bash
docker compose build
```

### Multi-Architecture Builds for Registry

Publishing `ludorl82/console` to Docker Hub is automated, not manual:
- Every merge to `main` bumps a minor version tag and cuts a GitHub Release
  (`.github/workflows/tag-on-merge.yaml`), which triggers
  `publish-image.yaml` to build and push `linux/amd64,linux/arm64` under
  `latest` and the new version tag.
- Every Sunday, `scheduled-rebuild.yaml` bumps a patch tag and rebuilds
  with `--pull --no-cache` so security fixes in the base image and apt
  packages actually get picked up, even with no code changes.

Don't `docker buildx build --push` this image by hand: it would push an
untagged-by-CI image that competes with `latest`/version tags the
pipeline manages, with no corresponding git tag or release to trace it
back to. If you need a one-off multi-arch build to test locally without
pushing, drop `--push` and add `--load` (single-platform only) or inspect
with `docker buildx build --platform linux/amd64,linux/arm64 .` (no
`--push`, no `--load` -- output stays in the build cache for inspection).

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
