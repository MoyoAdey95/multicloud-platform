# Decision records

Each record covers one choice someone reviewing this repo would reasonably question. They are short on purpose, and each points at the evidence or the doc that goes deeper.

| No. | Decision |
|---|---|
| [0001](0001-four-state-roots.md) | Four Terraform roots on one bucket, and the hub reads estates, never the reverse |
| [0002](0002-gcp-as-the-hub.md) | GCP is the hub |
| [0003](0003-federation-not-keys.md) | Federation everywhere, no stored keys, and two separate pools |
| [0004](0004-collector-sidecar.md) | A collector sidecar in each estate, labelling by cloud at collection time |
| [0005](0005-no-cross-provider-requests.md) | No request crosses a provider boundary |
| [0006](0006-request-counts-from-load-runs.md) | Cost per request divides by the load workflow's record, not the hub's metrics |
| [0007](0007-policy-on-plan-json.md) | Policy runs on Terraform's plan JSON with conftest |
| [0008](0008-ci-owns-images.md) | CI owns the running image, Terraform owns everything else |
