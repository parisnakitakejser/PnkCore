# CKS Exam Prep: Supply Chain Security - Image Footprint

This lab demonstrates how to reduce image size with multi-stage builds and
apply simple hardening practices.

## 1) Baseline image (large)

This example pulls a full base image and installs a compiler, which increases
size because build tools are kept in the final image.

```dockerfile
FROM ubuntu

RUN apt-get update && apt-get install -y golang-go

CMD ["sh"]
```

## 2) Build and measure

From the `app` directory:


```sh
mkdir app
cd app
curl -O https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/domains/supply-chain-security/image-footprint/app/Dockerfile
curl -O https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/cks/domains/supply-chain-security/image-footprint/app/app.go

docker build -t app .
docker run --rm app:latest
docker image list | grep app
```

## 3) Reduce size with a multi-stage build

Build the binary in a “builder” stage, then copy only the binary into a small
runtime image.

```dockerfile
# Stage 0 (builder)
FROM ubuntu
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y golang-go

COPY app.go .
RUN CGO_ENABLED=0 go build app.go

# Stage 1 (runtime)
FROM alpine
COPY --from=0 /app .
CMD ["./app"]
```

Rebuild and compare the size:

```sh
docker build -t app .
docker image list | grep app
```

## 4) Hardening ideas (quick study notes)

### Pin image versions

Avoid `latest` to prevent unexpected changes.

```dockerfile
FROM alpine:3.12.1
```

### Run as non-root

If the app is compromised, a non-root user limits impact.

```dockerfile
FROM alpine:3.12.1
RUN addgroup -S appgroup
RUN adduser -S appuser -G appgroup -h /home/appuser

COPY --from=0 /app /home/appuser
USER appuser
CMD ["/home/appuser/app"]
```

### Make filesystem read-only (partial)

You can enforce read-only at runtime in Kubernetes, but you can also remove
write permissions in the image for critical paths.

```dockerfile
FROM alpine:3.12.1
RUN chmod a-w /etc

RUN addgroup -S appgroup
RUN adduser -S appuser -G appgroup -h /home/appuser

COPY --from=0 /app /home/appuser
USER appuser
CMD ["/home/appuser/app"]
```

Test the permissions:

```sh
docker run -d --name app-test app
docker exec -it app-test sh
ls -la /etc
docker rm -f app-test
```

### Remove shell access (advanced)

Only do this if your app doesn’t require shell utilities.

```dockerfile
FROM alpine:3.12.1

RUN addgroup -S appgroup
RUN adduser -S appuser -G appgroup -h /home/appuser
RUN rm -rf /bin/*

COPY --from=0 /app /home/appuser
USER appuser
CMD ["/home/appuser/app"]
```

## Exam notes

- Multi-stage builds are the fastest way to cut image size.
- Avoid bloated base images and unnecessary packages.
- Always pin versions and run as non-root when possible.
