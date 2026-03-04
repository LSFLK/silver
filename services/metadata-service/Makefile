.PHONY: build run clean docker-build

BINARY_NAME=metadata-service
DOCKER_IMAGE=silver-metadata-service

build:
	go build -o $(BINARY_NAME) main.go

run:
	go run main.go

clean:
	rm -f $(BINARY_NAME)

docker-build:
	docker build -t $(DOCKER_IMAGE) .
