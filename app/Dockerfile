# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Builder
# Description: Compiles the Go application into a statically linked binary.
# ==============================================================================
FROM golang:1.21.4-alpine3.18 AS builder

# Set the working directory inside the build container.
WORKDIR /build

# Copy dependency definition files first to leverage Docker layer caching.
# This ensures 'go mod download' is only re-run if dependencies change.
COPY go.mod ./

# Download dependencies.
# Optimization: Use '--mount=type=cache' to persist the module cache between builds,
# significantly speeding up CI/CD pipelines.
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy the entire source code into the container.
COPY . .

# Build the application binary.
# Compilation Flags:
#   - CGO_ENABLED=0   : Ensures a statically linked binary (no dependency on C libraries).
#   - GOOS=linux      : Explicitly targets Linux environment.
#   - -ldflags="-w -s": Strips debug information (DWARF) and symbol tables to reduce image size.
# Optimization: Re-uses the Go build cache.
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o app .

# ==============================================================================
# Stage 2: Runner
# Description: Creates a minimal, secure production image using Distroless.
# Security: Contains no shell, package manager, or unnecessary tools.
# ==============================================================================
FROM gcr.io/distroless/static-debian12:nonroot as release

# Set the working directory to root.
WORKDIR /

# Retrieve the compiled binary from the builder stage.
COPY --from=builder /build/app /app

# Document the port that the application listens on.
EXPOSE 8080

# Security Best Practice: Run as a non-root user.
# Using the numeric ID 65532 (which corresponds to 'nonroot' in Distroless) 
# is preferred for strict Kubernetes Pod Security Standards (PSS).
USER 65532:65532

# Define the immutable entrypoint for the container.
ENTRYPOINT ["/app"]
