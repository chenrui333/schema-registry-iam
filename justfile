image := "schema-registry-iam"
tag := "test"

# Build the Docker image
build:
    docker build -t {{ image }}:{{ tag }} .

# Run image validation tests
test: build
    ./scripts/test-image.sh {{ image }}:{{ tag }}

# Remove the test image
clean:
    docker rmi {{ image }}:{{ tag }} 2>/dev/null || true
