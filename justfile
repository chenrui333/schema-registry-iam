image := "schema-registry-iam"
tag := "test"

# Build the Docker image
build:
    docker build -t {{ image }}:{{ tag }} .

# Build and run image validation and runtime smoke tests
test: build
    ./scripts/test-image.sh --skip-build {{ image }}:{{ tag }}
    ./scripts/test-runtime.sh {{ image }}:{{ tag }}

# Validate a pre-built image without rebuilding
validate image_ref:
    ./scripts/test-image.sh --skip-build {{ image_ref }}
    ./scripts/test-runtime.sh {{ image_ref }}

# Lint scripts, Dockerfile, and workflows (tools pinned in mise.toml)
lint:
    shellcheck scripts/*.sh
    hadolint Dockerfile
    actionlint
    zizmor --offline .github/workflows

# Remove the test image
clean:
    docker rmi {{ image }}:{{ tag }} 2>/dev/null || true
