image := "schema-registry-iam"
tag := "test"

# Build the Docker image
build:
    docker build -t {{ image }}:{{ tag }} .

# Build and run image validation tests
test: build
    ./scripts/test-image.sh --skip-build {{ image }}:{{ tag }}

# Validate a pre-built image without rebuilding
validate image_ref:
    ./scripts/test-image.sh --skip-build {{ image_ref }}

# Remove the test image
clean:
    docker rmi {{ image }}:{{ tag }} 2>/dev/null || true
