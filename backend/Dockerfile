# modified version from dockerdocs, Reference: https://docs.docker.com/guides/golang/build-images/

# ---------- Build Stage ----------
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Cache dependencies (not updating when modifying server code)
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# build main.go -> server
RUN CGO_ENABLED=0 GOOS=linux \
    go build -o server main.go


# ---------- Runtime Stage ----------
FROM alpine:3.20

WORKDIR /app

# Certificates (HTTPS, APNs, etc.)
RUN apk --no-cache add ca-certificates

# Binary kopieren
COPY --from=builder /app/server ./server

# Optional: Default-Port dokumentieren
EXPOSE 8080

# Start
CMD ["./server"]