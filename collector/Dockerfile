# The collector every estate runs, built once and pushed to all three
# registries like the app. The config and both credential files are baked in,
# so the image is identical everywhere. Each estate picks its cloud with
# CLOUD and, on AWS and Azure, its credential file with
# GOOGLE_APPLICATION_CREDENTIALS. On Cloud Run neither file is used, because
# the collector gets its identity from the metadata server.
FROM otel/opentelemetry-collector-contrib:0.161.0

COPY --chmod=644 config.yaml /etc/platform/config.yaml
COPY --chmod=644 aws-credential-config.json azure-credential-config.json /etc/platform/

CMD ["--config=/etc/platform/config.yaml"]
