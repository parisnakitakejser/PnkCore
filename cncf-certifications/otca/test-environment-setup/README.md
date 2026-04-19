# OTCA Exam Preparation: OTCA Test Environment Setup

This folder contains a small local observability stack for OpenTelemetry study and testing.

The compose project name is fixed to `otca-traning-enviorment`, so Podman resources do not depend on the folder name.

It gives you:
- Tempo for Grafana-native trace exploration
- Pyroscope for continuous profiling
- Prometheus for metrics
- Loki for logs storage
- Promtail for shipping local log files to Loki
- Grafana for dashboards and exploration
- OpenTelemetry Collector as the main OTLP ingest point

## Important Notes

- This setup uses `Tempo` for traces, not Jaeger.
- In Grafana, use `Explore` with the `Tempo` datasource for the simplest trace check.
- In `Drilldown > Traces`, the `Traces` tab is the best place to verify a tiny demo trace. The `Breakdown` tab can look empty or confusing for very small sample traffic.
- Loki on port `3100` is an API endpoint, not a normal browser UI.
- The sample app sends traces, metrics, and logs through the OpenTelemetry Collector.
- The sample app also sends CPU profiles directly to Pyroscope.
- The sample app logs are forwarded to Loki, so you should search for them in Grafana with the `Loki` datasource.
- Trace-to-profile correlation uses Tempo + Pyroscope through the `pyroscope-otel` bridge.

## Start The Stack

From this folder:

```bash
cd docker-compose
podman-compose up -d
```

Check status:

```bash
cd docker-compose
podman-compose ps
```

Stop everything:

```bash
cd docker-compose
podman-compose down
```

## Tool Links

After the stack is running, use these URLs:

- Grafana: http://localhost:3000
- Tempo API: http://localhost:3200
- Pyroscope API/UI: http://localhost:4040
- Prometheus UI: http://localhost:9090
- Loki API: http://localhost:3100
- OpenTelemetry Collector metrics endpoint: http://localhost:8889/metrics

## How Data Flows

The current setup has four signal flows:

- Traces:
  applications send OTLP traces to the OpenTelemetry Collector, and the collector forwards them to Tempo.
- Metrics:
  applications send OTLP metrics to the OpenTelemetry Collector, the collector exposes metrics in Prometheus format on port `8889`, and Prometheus scrapes that endpoint.
- Logs:
  applications can send OTLP logs to the OpenTelemetry Collector, and the collector forwards those logs to Loki.
  In addition, Promtail reads local log files from `/var/log` and also pushes those logs to Loki.
- Profiles:
  applications can send CPU profiles directly to Pyroscope with a language SDK.
  In the sample app, the Python Pyroscope SDK sends profiles to Pyroscope, and the `pyroscope-otel` bridge links those profiles to trace spans.

Grafana connects to:
- Tempo for traces
- Pyroscope for profiles
- Prometheus for metrics
- Loki for logs

## OpenTelemetry Collector Endpoints

Use these endpoints to send telemetry into the collector:

- From your host machine with OTLP gRPC: `localhost:4317`
- From another container on the same compose network with OTLP gRPC: `opentelemetry-collector:4317`

Important:
- In this setup, `4317` is the main host-accessible OTLP endpoint.
- The collector config enables OTLP HTTP internally, but `4318` is not currently published in `docker-compose/docker-compose.yml`.

## Send Data To The Collector

### Environment Variables

For many SDKs, this is enough:

```bash
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_SERVICE_NAME=my-study-app
```

If your app runs inside the same compose network, use:

```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://opentelemetry-collector:4317
```

### Example With Python

A runnable sample app is included in [sample-app/app.py](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/otca/test-environment-setup/sample-app/app.py:1).
The test values for the sample app live in [sample-app/.env](/Users/parisnakitakejser/Developer/PnkCore/cncf-certifications/otca/test-environment-setup/sample-app/.env:1).

```bash
cd sample-app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

After running this, open Grafana and search for service `my-study-app` with the Tempo datasource.
The sample app now emits:
- one trace span
- one counter metric named `sample_app_requests`
- one OpenTelemetry log record
- CPU profiles to Pyroscope
- trace-to-profile correlation metadata for Tempo

Fast verification path:
- Traces: Grafana `Explore` -> datasource `Tempo` -> service `my-study-app`
- Profiles: Grafana `Profiles Drilldown` or `Explore` -> datasource `Pyroscope` -> app `my-study-app`
- Metrics: Prometheus or Grafana -> search for `sample_app_requests`
- Logs: Grafana `Explore` -> datasource `Loki` -> query `{service_name="my-study-app"}`

### Run The Sample App In A Container

Build the image:

```bash
cd sample-app
podman build -t otca-sample-app -f Dockerfile .
```

Run it against the local observability stack:

```bash
podman run --rm \
  --network otca-traning-enviorment_otca-observability \
  --env-file .env \
  otca-sample-app
```

The `--rm` flag removes the container automatically when the process exits.

If you see `StatusCode.UNAVAILABLE`, the collector is usually not reachable yet. Restart the collector after config changes:

```bash
cd ../docker-compose
podman-compose up -d --force-recreate opentelemetry-collector
```

If `Drilldown > Traces` in Grafana shows `Datasource was not found`, restart Grafana and Tempo after provisioning changes:

```bash
cd ../docker-compose
podman-compose up -d --force-recreate tempo grafana
```

If you add or change Pyroscope provisioning, restart Grafana and Pyroscope:

```bash
cd ../docker-compose
podman-compose up -d --force-recreate pyroscope grafana
```

After the collector restart, OTLP logs from the sample app are forwarded to Loki.
In Grafana Explore, start with a query like:

```logql
{service_name="my-study-app"}
```

If you run the debug command, use:

```logql
{service_name="my-study-app-debug"}
```

### Debug The Container And Remove It On Exit

Run the app in Python debugger mode:

```bash
podman run --rm -it \
  --network otca-traning-enviorment_otca-observability \
  --env-file .env \
  -e OTEL_SERVICE_NAME=my-study-app-debug \
  -e SAMPLE_APP_DEBUG=1 \
  --entrypoint python \
  otca-sample-app -m pdb app.py
```

Useful debugger commands:
- `n` for next line
- `s` for step into
- `c` for continue
- `q` for quit

When you quit, Podman removes the container because the command uses `--rm`.

## Where To Look For Data

Use each tool for the right signal:

- Traces: Grafana with the Tempo datasource
- Profiles: Grafana with the Pyroscope datasource
- Metrics: Prometheus or Grafana
- Logs: Grafana with the Loki datasource

## Good Study Checks

When testing your app, verify:

1. The app exports to `localhost:4317`
2. The service name appears in Grafana with the Tempo datasource
3. CPU profiles appear in Grafana with the Pyroscope datasource
4. Metrics appear in Prometheus
5. Logs appear in Grafana through Loki

Note:
- If you run the sample app in a container, the `.env` file already points it at `opentelemetry-collector:4317`, which is correct for the compose network.
- If you run the sample app directly on your host, use `localhost:4317` instead.

## Troubleshooting

Useful commands:

```bash
cd docker-compose
podman-compose ps
podman logs opentelemetry-collector
podman logs prometheus
podman logs promtail
podman logs grafana
```

If you cannot see traces:
- Make sure your app is using OTLP gRPC on port `4317`
- Make sure the service name is set
- In Grafana, prefer `Explore` with datasource `Tempo`
- In `Drilldown > Traces`, check the `Traces` tab, not only `Breakdown`
- Check `podman logs opentelemetry-collector`

If you cannot see metrics:
- Check the collector metrics endpoint at `http://localhost:8889/metrics`
- Check Prometheus targets in `http://localhost:9090`

If you cannot see profiles:
- Make sure the sample app is using `PYROSCOPE_SERVER_ADDRESS=http://pyroscope:4040` when running in a container
- Rebuild the sample app image after dependency changes
- Remember that profiles are CPU-based, so the profiled span must do real CPU work
- Check `http://localhost:4040`
- In Grafana, use the `Pyroscope` datasource or `Profiles Drilldown`

If you cannot see logs:
- Restart the collector after config changes
- Check `podman logs opentelemetry-collector`
- Make sure you are querying Loki, not Tempo
- Query Loki in Grafana Explore with `{service_name="my-study-app"}`
