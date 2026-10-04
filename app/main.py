"""The workload for multicloud-platform.

The same image runs on Cloud Run, ECS Fargate and Azure Container Apps.
It is kept small on purpose, because the repo is about the platform around
it. It serves a few routes, exposes Prometheus metrics on /metrics for the
collector to scrape, and writes JSON logs to stdout. When an OTLP endpoint
is configured, the same log records also go to the collector, which is how
logs leave AWS and Azure without anything reading container stdout.

The app never labels its own metrics with a cloud. The collector next to it
adds that label, so the code and the image are identical in every estate.
CLOUD only appears in the response body, for a person checking by hand.
"""

import json
import logging
import os
import random
import sys
import time

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.requests import Request

SERVICE = "platform-api"


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return json.dumps(
            {
                "severity": record.levelname,
                "message": record.getMessage(),
                "logger": record.name,
                "time": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            }
        )


def configure_logging() -> None:
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    stdout = logging.StreamHandler(sys.stdout)
    stdout.setFormatter(JsonFormatter())
    root.addHandler(stdout)

    # Only set where a collector runs next to the app. Locally the app
    # logs to stdout alone and needs nothing else running.
    if os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT"):
        from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
        from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
        from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
        from opentelemetry.sdk.resources import Resource

        provider = LoggerProvider(resource=Resource.create({"service.name": SERVICE}))
        provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
        # Only the app's own logger ships over OTLP. On the root logger the
        # exporter's own warnings about a missing collector would be fed
        # back into the same exporter.
        logging.getLogger(SERVICE).addHandler(LoggingHandler(logger_provider=provider))


configure_logging()
log = logging.getLogger(SERVICE)

app = FastAPI(title=SERVICE, docs_url=None, redoc_url=None)

# Labels use the route template, not the raw path, so a scan of random URLs
# cannot create a new series per URL.
REQUESTS = Counter(
    "app_requests_total",
    "HTTP requests handled, by route, method and status code.",
    ["route", "method", "status"],
)
LATENCY = Histogram(
    "app_request_duration_seconds",
    "Request duration in seconds, by route and method.",
    ["route", "method"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)

# Health checks and scrapes would swamp the real traffic in the request rate.
UNMEASURED = {"/health", "/metrics"}


@app.middleware("http")
async def measure(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    route = request.scope.get("route")
    template = route.path if route else "unmatched"
    if template not in UNMEASURED:
        REQUESTS.labels(template, request.method, response.status_code).inc()
        LATENCY.labels(template, request.method).observe(time.perf_counter() - start)
    return response


@app.get("/")
def root() -> dict:
    return {"service": SERVICE, "cloud": os.environ.get("CLOUD", "local")}


@app.get("/flaky")
def flaky():
    """Fails about 30% of the time, so the error panels and the error-ratio
    alert have real failures to show when tested."""
    if random.random() < 0.3:
        log.error("flaky request failed")
        return Response(
            content='{"status": "error"}', status_code=500, media_type="application/json"
        )
    log.info("flaky request succeeded")
    return {"status": "ok"}


# /health rather than /healthz, because Google's frontend in front of Cloud
# Run intercepts /healthz. One path that works on all three is simpler than
# a different health path per estate.
@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/metrics")
def metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)
