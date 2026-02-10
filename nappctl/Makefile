.PHONY: build install clean test run help

# Build variables
BINARY_NAME=nappctl
VERSION?=dev
COMMIT?=$(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE?=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Go build flags
LDFLAGS=-ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.date=$(BUILD_DATE)"

## help: Display this help message
help:
	@echo "Available targets:"
	@echo "  build       - Build the nappctl binary"
	@echo "  install     - Install nappctl to GOPATH/bin"
	@echo "  clean       - Remove build artifacts"
	@echo "  test        - Run tests"
	@echo "  run         - Build and run nappctl"
	@echo "  deps        - Download dependencies"

## build: Build the binary
build:
	@echo "Building $(BINARY_NAME)..."
	@go build $(LDFLAGS) -o bin/$(BINARY_NAME) ./cmd/nappctl
	@echo "Built: bin/$(BINARY_NAME)"

## install: Install to GOPATH/bin
install:
	@echo "Installing $(BINARY_NAME)..."
	@go install $(LDFLAGS) ./cmd/nappctl

## clean: Remove build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf bin/ dist/
	@go clean

## test: Run tests
test:
	@echo "Running tests..."
	@go test -v ./...

## run: Build and run
run: build
	@./bin/$(BINARY_NAME)

## deps: Download dependencies
deps:
	@echo "Downloading dependencies..."
	@go mod download
	@go mod tidy

## build-all: Cross-compile for multiple platforms
build-all:
	@echo "Cross-compiling..."
	@mkdir -p dist
	@GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-darwin-amd64 ./cmd/nappctl
	@GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-darwin-arm64 ./cmd/nappctl
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-linux-amd64 ./cmd/nappctl
	@GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o dist/$(BINARY_NAME)-linux-arm64 ./cmd/nappctl
	@echo "Cross-compilation complete. Binaries in dist/"
