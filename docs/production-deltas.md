# Production deltas

What this lab does differently from how I would run it for real, and why each shortcut was taken. Some were chosen at the start to keep a personal lab cheap and small. Others came out of building it.

## Structure

**The hub and the GCP estate share a project.** It kept the bootstrap to one project, but it means their costs are told apart only by a label, and unlabelled charges such as Managed Prometheus are assumed to be the hub's. In production the hub would have its own project, and each estate its own project, AWS account, or Azure subscription, created by a landing zone rather than by hand.

**There is no organisation layer.** No AWS Organizations with service control policies, no Azure management groups or Azure Policy, no GCP organisation policies. The policy rules in `policy/` check what Terraform would build, but nothing stops a person with console access doing something else. Drift detection finds that the next night. The providers' own policy services would stop it at the time, and in production they would back up the plan checks.

**The state bucket was made by hand** and uses Google-managed encryption. In production it would be created by the landing zone, with a customer-managed key and access logs.

## Identity

**I apply from my laptop with broad rights in all three clouds.** In production people would have read access, and applies would run from CI after review, with a GitHub environment that needs approval. The read-only plan identities are already built that way.

**ECS Exec is on** so the federation experiment could run inside the task. That gives the task role four Session Manager actions it does not otherwise need. In production it would be off and turned on only during an incident.

**On Azure, the read-only plan identity can read the Container App's secrets.** The azurerm provider calls `listSecrets` on every read, and no built-in role grants that without write access so a custom role allows that one action on that one app. The app keeps no secrets, which is what makes this acceptable. An app that did would need its secrets in Key Vault instead.

## Network

**The AWS load balancer serves plain HTTP.** There is no domain or certificate. The policy rules warn on it rather than fail. In production it would be HTTPS only, with HTTP redirecting.

**The Fargate task has a public IP** so it can pull images and reach Google without a NAT gateway, which would cost more than the rest of the estate. Inbound is still only from the load balancer. In production the task would sit in private subnets with VPC endpoints for ECR and a NAT gateway or proxy for the telemetry going out.

**Container Apps runs without a VNet, and Cloud Run accepts traffic from anywhere.** Both are public by design here. In production they would sit behind each cloud's load balancer and WAF with internal ingress on the service.

**Telemetry crosses the internet** from AWS and Azure to Google. In production at volume the egress cost and the dependency on the public path would both be reasons to look at an interconnect, or at a collector tier inside each cloud that batches before sending.

## Telemetry

**Every replica in an estate writes the same label set.** All collectors scrape `127.0.0.1:8080`, so `instance` is the same everywhere. At one replica that is harmless. At more, the collector would need to add a replica ID, or two replicas would write to the same series.

**The latency histogram's smallest bucket is 5 ms**, and every request finishes inside it, so p95 always reads 0.005. Finer buckets at 1 ms and 2.5 ms would make the latency panel useful.

**On Cloud Run the collector only gets CPU while a request is being served**, because the service uses request-based billing. Exports can be delayed until the next request or until the instance shuts down. In production the service would use instance-based CPU, or the collector would run outside the request path.

**There is no alert on missing data**, because two estates scale to zero. In production the estates would have traffic all the time, and an uptime check from outside each cloud would cover "is it serving" better than an alert on absent metrics.

**The view is Google's console.** In production Grafana would sit in front of Managed Prometheus with the dashboard and its `cloud` variable in the same JSON form.

## Images

**The ECR lifecycle rule keeps the ten most recent images of any tag, and the app and collector images share the repository.** After ten more app deploys, the collector image the task depends on would be expired, and the next task start would fail to pull it. In production the collector would have its own repository, or the rule would keep images by tag prefix, and the collector would be pinned by a tag the rule never expires.

## Cost

**`estate` is not an activated cost allocation tag in AWS.** That did no harm here with one estate per account, but it would matter in a shared one.

**The unit cost view infers the owner of untagged AWS charges** for the three services the estate uses. That is only safe because nothing else in the account uses them. In a shared account those charges would be shown as unallocated.

**The cost history is a week.** Billing data lags by a day or more, and the lab ran for about a week, so every figure is a small sample. In production the same views would run over months.

## CI

**GitHub's scheduled runs are unreliable.** The hourly load workflow ran 1, 5, 3, and 3 times a day against 24 expected, and repo 8 measured scheduled runs starting hours late. In production, load and drift checks would be triggered by each cloud's own scheduler, or by a scheduler outside GitHub.

**Every workflow step that pipes into another command needs `pipefail`.** Without a named shell, GitHub runs `bash -e`, and `conftest test | tee` took tee's exit code. A policy failure was printed and the job passed, and so did a real Azure plan error.

**Policy rules need tests for the absent case**, not only for wrong values. The first version of the storage rules let a bucket through because the settings were left out of the code, and a comparison with a missing value is never true.

**Some actions still run on older Node versions.** `hashicorp/setup-terraform@v3` prints a Node deprecation warning on every run. In production every action would be pinned by commit SHA and kept up to date by Dependabot.
