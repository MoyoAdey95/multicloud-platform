"""Run inside the container app with az containerapp exec.

  python3 containerapp-google-token.py claims    what the managed identity token says
  python3 containerapp-google-token.py exchange  turn it into a Google token and write

The claims step prints the token's issuer, audience and subject, which the
Azure provider in the estates pool is built from. Nothing here prints a
token or the identity header.

Needs: pip install --target /tmp/py google-auth requests
"""

import base64
import datetime
import http.server
import json
import os
import sys
import threading
import urllib.parse
import urllib.request

PROJECT = "multicloud-platform-lab"
CLIENT_ID = "6d03fe23-a3d2-47d4-afd6-ae0aa625bbbc"
# The audience Entra uses for tokens meant to be exchanged elsewhere. A token
# for this audience is useless against Azure's own APIs.
RESOURCE = "api://AzureADTokenExchange"
PROVIDER = "//iam.googleapis.com/projects/355394312675/locations/global/workloadIdentityPools/estates/providers/azure-estate"


def section(title):
    print(f"\n=== {title}")


# Container Apps hands out managed identity tokens from its own endpoint,
# guarded by a per-container header, not from the VM metadata address.
def identity_token():
    query = urllib.parse.urlencode({"resource": RESOURCE, "api-version": "2019-08-01", "client_id": CLIENT_ID})
    req = urllib.request.Request(
        f"{os.environ['IDENTITY_ENDPOINT']}?{query}",
        headers={"X-IDENTITY-HEADER": os.environ["IDENTITY_HEADER"]},
    )
    return json.loads(urllib.request.urlopen(req, timeout=10).read())["access_token"]


def claims(token):
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


section("what the container has")
for name in ("IDENTITY_ENDPOINT", "IDENTITY_HEADER", "MSI_ENDPOINT"):
    print(f"{name}: {'set' if os.environ.get(name) else 'not set'}")

mode = sys.argv[1] if len(sys.argv) > 1 else "claims"

if mode == "claims":
    section("managed identity token claims")
    c = claims(identity_token())
    for key in ("iss", "aud", "sub", "oid", "tid", "azp", "ver"):
        print(f"{key}: {c.get(key)}")
    print(f"lifetime: {c['exp'] - c['iat']} seconds")
    raise SystemExit(0)

import google.auth  # noqa: E402
import google.auth.transport.requests  # noqa: E402
import requests  # noqa: E402


# Serves the managed identity token to Google's library over plain HTTP on
# localhost, adding the header the library has no way to read from the
# environment itself.
class Shim(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({"access_token": identity_token()}).encode()
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 8099), Shim)
threading.Thread(target=server.serve_forever, daemon=True).start()

config = {
    "universe_domain": "googleapis.com",
    "type": "external_account",
    "audience": PROVIDER,
    "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
    "token_url": "https://sts.googleapis.com/v1/token",
    "credential_source": {
        "url": "http://127.0.0.1:8099/token",
        "format": {"type": "json", "subject_token_field_name": "access_token"},
    },
}

section("exchange: managed identity token for a Google token")
try:
    creds, _ = google.auth.load_credentials_from_dict(config, scopes=["https://www.googleapis.com/auth/cloud-platform"])
    creds.refresh(google.auth.transport.requests.Request())
    print(f"token issued, expires {creds.expiry} UTC")
except Exception as e:
    print(f"failed: {type(e).__name__}: {str(e)[:400]}")
    raise SystemExit(1)

headers = {"Authorization": f"Bearer {creds.token}"}

section("write: one point to a custom metric")
point = {
    "timeSeries": [{
        "metric": {"type": "custom.googleapis.com/platform/federation_check", "labels": {"cloud": "azure"}},
        "resource": {"type": "global", "labels": {"project_id": PROJECT}},
        "points": [{
            "interval": {"endTime": datetime.datetime.now(datetime.timezone.utc).isoformat()},
            "value": {"int64Value": "1"},
        }],
    }]
}
r = requests.post(f"https://monitoring.googleapis.com/v3/projects/{PROJECT}/timeSeries", json=point, headers=headers, timeout=10)
print(r.status_code, r.text[:200] if r.status_code != 200 else "ok")

section("write: one log entry")
entry = {
    "logName": f"projects/{PROJECT}/logs/federation-check",
    "resource": {"type": "global", "labels": {"project_id": PROJECT}},
    "entries": [{"jsonPayload": {"message": "written from the container app with no key", "cloud": "azure"}}],
}
r = requests.post("https://logging.googleapis.com/v2/entries:write", json=entry, headers=headers, timeout=10)
print(r.status_code, r.text[:200] if r.status_code != 200 else "ok")
