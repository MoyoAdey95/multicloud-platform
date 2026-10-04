"""Run inside the Fargate task with ECS Exec. Tries to turn the task's AWS
identity into a Google token, first with the credential config exactly as
gcloud generates it, then through a small local shim. Prints what happened
and never prints a credential or token.

Needs: pip install --user google-auth requests
"""

import datetime
import http.server
import json
import os
import threading
import urllib.request

import google.auth
import google.auth.transport.requests
import requests

PROJECT = "multicloud-platform-lab"
SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]

CONFIG = {
    "universe_domain": "googleapis.com",
    "type": "external_account",
    "audience": "//iam.googleapis.com/projects/355394312675/locations/global/workloadIdentityPools/estates/providers/aws-estate",
    "subject_token_type": "urn:ietf:params:aws:token-type:aws4_request",
    "token_url": "https://sts.googleapis.com/v1/token",
    "credential_source": {
        "environment_id": "aws1",
        "region_url": "http://169.254.169.254/latest/meta-data/placement/availability-zone",
        "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials",
        "regional_cred_verification_url": "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15",
    },
    "token_info_url": "https://sts.googleapis.com/v1/introspect",
}


def section(title):
    print(f"\n=== {title}")


def try_token(config):
    creds, _ = google.auth.load_credentials_from_dict(config, scopes=SCOPES)
    creds.refresh(google.auth.transport.requests.Request())
    return creds


section("what the task has")
for name in ("AWS_REGION", "AWS_DEFAULT_REGION", "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI", "AWS_ACCESS_KEY_ID"):
    print(f"{name}: {'set' if os.environ.get(name) else 'not set'}")

section("attempt 1: config as gcloud generated it")
try:
    try_token(CONFIG)
    print("token issued")
except Exception as e:
    print(f"failed: {type(e).__name__}: {str(e)[:300]}")


# Answers the two requests the library makes against EC2 metadata, using the
# credentials ECS hands this task. The field names ECS returns (AccessKeyId,
# SecretAccessKey, Token) are the same ones EC2 metadata uses.
class Shim(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/creds":
            body = b"task-role"
        elif self.path == "/creds/task-role":
            uri = os.environ["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]
            body = urllib.request.urlopen(f"http://169.254.170.2{uri}", timeout=5).read()
        else:
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 8099), Shim)
threading.Thread(target=server.serve_forever, daemon=True).start()

shim_config = json.loads(json.dumps(CONFIG))
shim_config["credential_source"]["url"] = "http://127.0.0.1:8099/creds"
# The region comes from AWS_REGION, which Fargate sets, so no region URL.
del shim_config["credential_source"]["region_url"]

section("attempt 2: same config, credentials from the local shim")
try:
    creds = try_token(shim_config)
    print(f"token issued, expires {creds.expiry} UTC")
except Exception as e:
    print(f"failed: {type(e).__name__}: {str(e)[:300]}")
    raise SystemExit(1)

headers = {"Authorization": f"Bearer {creds.token}"}

section("read: list metric descriptors as the federated identity")
r = requests.get(
    f"https://monitoring.googleapis.com/v3/projects/{PROJECT}/metricDescriptors",
    params={"pageSize": 1},
    headers=headers,
    timeout=10,
)
print(r.status_code, r.text[:200] if r.status_code != 200 else "ok")

section("write: one point to a custom metric")
point = {
    "timeSeries": [{
        "metric": {"type": "custom.googleapis.com/platform/federation_check", "labels": {"cloud": "aws"}},
        "resource": {"type": "global", "labels": {"project_id": PROJECT}},
        "points": [{
            "interval": {"endTime": datetime.datetime.now(datetime.timezone.utc).isoformat()},
            "value": {"int64Value": "1"},
        }],
    }]
}
r = requests.post(
    f"https://monitoring.googleapis.com/v3/projects/{PROJECT}/timeSeries",
    json=point, headers=headers, timeout=10,
)
print(r.status_code, r.text[:200] if r.status_code != 200 else "ok")

section("write: one log entry")
entry = {
    "logName": f"projects/{PROJECT}/logs/federation-check",
    "resource": {"type": "global", "labels": {"project_id": PROJECT}},
    "entries": [{"jsonPayload": {"message": "written from the Fargate task with no key", "cloud": "aws"}}],
}
r = requests.post("https://logging.googleapis.com/v2/entries:write", json=entry, headers=headers, timeout=10)
print(r.status_code, r.text[:200] if r.status_code != 200 else "ok")
