# PCA Exam Prep: Setting Up Prometheus Locally

This lab runs Prometheus locally with Docker or Podman. The stack includes:
- Prometheus (scraping itself)
- Node Exporter (host metrics)
- Grafana (dashboards)
- Three demo services that emit metrics

## Prerequisites
- Docker or Podman
- `docker compose` or `podman-compose`

## Get the required files

Download only the required files into your working folder:

```bash
mkdir -p provisioning/datasources

curl -o docker-compose.yaml https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/pca/setting-up-prometheus-locally/docker-compose.yaml
curl -o prometheus.yml https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/pca/setting-up-prometheus-locally/prometheus.yml
curl -o provisioning/datasources/datasource.yml https://raw.githubusercontent.com/parisnakitakejser/PnkCore/refs/heads/main/cncf-certifications/pca/setting-up-prometheus-locally/provisioning/datasources/datasource.yml
```

Replace `<REPO_RAW_URL>` with the raw URL of this repository (GitHub raw or similar).

## Build the demo service image
The compose file expects a local image named `prometheus-demo-service`. Build it from the LFS241 repo:

```bash
git clone --depth=1 https://github.com/lftraining/LFS241.git
cd LFS241/demo-service-source
podman build -t prometheus-demo-service .
```

The demo service emits simulated metrics for:
- HTTP API requests (counts, durations, errors)
- CPU usage
- Disk usage and total size
- A periodic batch job that can fail

## Start the stack

**Podman**

```bash
podman-compose up -d
```

**Docker**

```bash
docker compose up -d
```

Prometheus should be available at `http://localhost:9090`.
Grafana should be available at `http://localhost:3030` (admin / supersecret).
Node Exporter should be available at `http://localhost:9100/metrics`.

## Validate Prometheus locally
In the Prometheus UI, run these queries:

Total number of samples ingested since Prometheus started:

```promql
prometheus_tsdb_head_samples_appended_total
```

Samples ingested per second averaged over 1 minute:

```promql
rate(prometheus_tsdb_head_samples_appended_total[1m])
```

## Validate demo service scraping
Check that demo service metrics are present:

```promql
demo_api_request_duration_seconds_count
```

## Validate Node Exporter scraping
Check that node metrics are present:

```promql
node_cpu_seconds_total
```
