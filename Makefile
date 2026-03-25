IMAGE := schema-registry-iam
TAG   := test

.PHONY: build test clean

build:
	docker build -t $(IMAGE):$(TAG) .

test:
	./scripts/test-image.sh $(IMAGE):$(TAG)

clean:
	docker rmi $(IMAGE):$(TAG) 2>/dev/null || true
