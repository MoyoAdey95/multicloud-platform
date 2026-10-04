"""Hands this workload's own cloud identity to Google's auth library.

Runs next to the collector on AWS and Azure, on 127.0.0.1:8099 only. Google's
library can read AWS credentials from EC2-style metadata and an OIDC token
from a URL, but neither matches what Fargate or Container Apps provide. This
fills that gap and nothing else. It stores nothing and never logs a token.

SHIM_MODE=aws    /creds -> a role name, /creds/<name> -> ECS task credentials
SHIM_MODE=azure  /token -> {"access_token": managed identity token}

Proven inside both estates first, see spikes/ and docs/identity-decisions.md.
"""

import http.server
import json
import os
import time
import urllib.parse
import urllib.request

MODE = os.environ["SHIM_MODE"]
_cache = {"token": None, "expires": 0}


def aws_credentials():
    uri = os.environ["AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"]
    return urllib.request.urlopen(f"http://169.254.170.2{uri}", timeout=5).read()


# The token lasts about 24 hours. It is reused until ten minutes before it
# expires rather than fetched for every exchange.
def azure_token():
    if _cache["token"] and time.time() < _cache["expires"] - 600:
        return _cache["token"]
    query = urllib.parse.urlencode({
        "resource": "api://AzureADTokenExchange",
        "api-version": "2019-08-01",
        "client_id": os.environ["AZURE_CLIENT_ID"],
    })
    req = urllib.request.Request(
        f"{os.environ['IDENTITY_ENDPOINT']}?{query}",
        headers={"X-IDENTITY-HEADER": os.environ["IDENTITY_HEADER"]},
    )
    body = json.loads(urllib.request.urlopen(req, timeout=10).read())
    _cache["token"] = body["access_token"]
    _cache["expires"] = int(body["expires_on"])
    return _cache["token"]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            if MODE == "aws" and self.path == "/creds":
                body = b"task-role"
            elif MODE == "aws" and self.path == "/creds/task-role":
                body = aws_credentials()
            elif MODE == "azure" and self.path == "/token":
                body = json.dumps({"access_token": azure_token()}).encode()
            else:
                self.send_response(404)
                self.end_headers()
                return
        except Exception as e:
            print(f"credential fetch failed: {type(e).__name__}", flush=True)
            self.send_response(502)
            self.end_headers()
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


print(f"credential shim ({MODE}) on 127.0.0.1:8099", flush=True)
http.server.ThreadingHTTPServer(("127.0.0.1", 8099), Handler).serve_forever()
