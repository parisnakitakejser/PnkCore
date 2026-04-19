import logging
import os
import time
from pathlib import Path

import pyroscope
from opentelemetry import metrics, trace
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from dotenv import load_dotenv
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from pyroscope.otel import PyroscopeSpanProcessor


def cpu_work(seconds: int) -> None:
    deadline = time.perf_counter() + seconds
    value = 0
    while time.perf_counter() < deadline:
        for i in range(10000):
            value += (i * i) % 97
    if value == -1:
        print("unreachable")


def main() -> None:
    load_dotenv(Path(__file__).with_name(".env"))

    service_name = os.getenv("OTEL_SERVICE_NAME", "my-study-app")
    endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"
    )
    pyroscope_address = os.getenv(
        "PYROSCOPE_SERVER_ADDRESS", "http://localhost:4040"
    )
    debug = os.getenv("SAMPLE_APP_DEBUG", "0") == "1"
    profile_seconds = int(os.getenv("SAMPLE_APP_PROFILE_SECONDS", "12"))

    pyroscope.configure(
        application_name=service_name,
        server_address=pyroscope_address,
    )

    resource = Resource.create({"service.name": service_name})
    trace_provider = TracerProvider(resource=resource)
    trace_provider.add_span_processor(PyroscopeSpanProcessor())
    trace_provider.add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(endpoint=endpoint, insecure=True)
        )
    )
    trace.set_tracer_provider(trace_provider)

    metric_reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=endpoint, insecure=True),
        export_interval_millis=1000,
    )
    meter_provider = MeterProvider(
        resource=resource,
        metric_readers=[metric_reader],
    )
    metrics.set_meter_provider(meter_provider)

    log_provider = LoggerProvider(resource=resource)
    log_provider.add_log_record_processor(
        BatchLogRecordProcessor(
            OTLPLogExporter(endpoint=endpoint, insecure=True)
        )
    )
    set_logger_provider(log_provider)

    tracer = trace.get_tracer(__name__)
    meter = metrics.get_meter(__name__)
    counter = meter.create_counter("sample_app_requests")
    logger = logging.getLogger("sample-app")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    logger.addHandler(LoggingHandler(logger_provider=log_provider))
    logger.propagate = False

    if debug:
        print(f"service_name={service_name}")
        print(f"otlp_endpoint={endpoint}")
        print(f"pyroscope_server_address={pyroscope_address}")
        print(f"profile_seconds={profile_seconds}")

    with tracer.start_as_current_span("hello-otca") as span:
        counter.add(1, {"operation": "hello-otca"})
        logger.info("sample app emitted a log record")
        span.set_attribute("sample.profile.seconds", profile_seconds)
        with tracer.start_as_current_span("cpu-work"):
            cpu_work(profile_seconds)
        print("sent a test span")

    log_provider.force_flush()
    metric_reader.force_flush()

    trace_provider.shutdown()
    meter_provider.shutdown()
    log_provider.shutdown()


if __name__ == "__main__":
    main()
