# Collecting SMART Disk Metrics from Ceph with OpenTelemetry

Download and install the smartctl_exporter

```sh
sudo dnf install -y smartmontools wget tar systemd
sudo wget https://github.com/prometheus-community/smartctl_exporter/releases/download/v0.14.0/smartctl_exporter-0.14.0.linux-amd64.tar.gz
tar -xvf smartctl_exporter-0.14.0.linux-amd64.tar.gz
sudo mv smartctl_exporter-0.14.0.linux-amd64/smartctl_exporter /usr/local/bin/
```


copy the `smartctl-exporter.service` file context into your system folder `/etc/systemd/system/smartctl-exporter.service`

Relabel smartctl_export for SELinux and enable your smartctl-exporter service with the system, and confirm it's running.

```sh
sudo restorecon -v /usr/local/bin/smartctl_exporter
sudo systemctl enable --now smartctl-exporter.service
sudo systemctl restart smartctl-exporter
sudo journalctl -u smartctl-exporter -f
```

go to `/etc/otel/otel.yaml` and add the snippet into the a reciveres

```yaml
- job_name: "smartmon"
  metrics_path: /metrics
  static_configs:
    - targets:
        - "localhost:9633"
```

now restart your otel-collector service

```sh
sudo systemctl restart otelcol-contrib
sudo journalctl -u otelcol-contrib -f
```