# Observability decisions

All three estates send their metrics and logs to one place, the hub project in GCP. Every series and every log line carries a `cloud` label, added at collection time, so one query can compare the estates or narrow to one of them. This page explains how that works, what went wrong on the way, and what was left out on purpose.

## The shape

A collector runs as a sidecar next to the app in each estate. It is the same image in all three, pushed to each registry by one build, so the digests match. It scrapes the app's `/metrics` every 30 seconds, receives the app's logs over OTLP on localhost, adds the `cloud` label, and exports to Managed Service for Prometheus and Cloud Logging in the hub. The only things that change between estates are the `CLOUD` environment variable and, on AWS and Azure, which credential file the collector reads.

The app itself has no idea which cloud it is on. Its metrics and logs are identical everywhere, and the label comes from the collector. That keeps one image valid for all three estates.

A sidecar rather than a node agent, because two of the three estates have no nodes to put an agent on. Cloud Run and Container Apps scale to zero, and a sidecar starts and stops with the replica it watches.

Managed Prometheus rather than running Prometheus, because the hub is already GCP and it gives PromQL with nothing to operate. The cost is that the AWS and Azure collectors send data out to Google over the internet, which is small at this volume, and that the view is Google's console for all three clouds. A production setup would put Grafana in front, which is in the production deltas.

## Credentials

The collectors on AWS and Azure sign in to Google by exchanging their own cloud's workload identity, with no keys stored anywhere. Both needed a small shim on localhost to bridge the gap between what Google's auth library expects and what Fargate and Container Apps actually provide. The details are in [identity decisions](identity-decisions.md).

## Labels and series

Managed Prometheus files every series under a `prometheus_target` resource built from `location`, `cluster`, `namespace`, `job` and `instance`. On GKE these are detected. Outside it nothing detects them, so the collector sets them. `location` is the hub's region, where the data is stored, not where the estate runs. `cluster` carries the estate name.

`job` and `instance` are the same in every estate, because every collector scrapes `127.0.0.1:8080`. `cluster` is what keeps the three estates apart. Within one estate, two replicas would write to the same series. At one replica each that never happens, but with more replicas the collector would need to add a replica ID. That is in the production deltas.

## Counters and start times

Two problems turned up in the counters, both about where a counter starts. Both were invisible on the dashboard and only showed up when comparing the app's own `/metrics` with what the hub stored.

The first was a fixed offset. The app's counters carry no start time, so Google's exporter took the first value it scraped as zero and reported everything after it relative to that. A replica that woke from zero served the request that woke it before the collector's first scrape, and that request never reached the hub. The controlled test on Azure on 8 October showed it directly. After one request the app said 1 and the hub said 0. After five more the app said 6 and the hub said 5. The same effect explains readings of 45 instead of 60 on GCP and AWS earlier that day, both taken soon after a new replica or task started. Nothing was being throttled.

The fix is the collector's `metric_start_time` processor with the `start_time_metric` strategy. The Python client publishes `process_start_time_seconds`, and the processor stamps it on every counter, so the hub sees the full count from the start. After the change, the app and the hub matched on all three estates, 2 and 2 then 7 and 7 on GCP and Azure, and every series on AWS.

The second problem came from the fix. A labelled series only exists once something increments it. On the AWS task, which never scales to zero, the first `/flaky` call of the morning created a series fifteen hours after the process started. The hub spread that first jump back to the process start time, so `increase()` over the last 30 minutes showed nothing, while GCP and Azure, freshly started, counted every call. The processor's documentation warns about exactly this case. It matters most for alerting, because the first error after a quiet spell on a long-running replica would never move the error ratio.

The fix is in the app. It now creates the series it knows about at zero when it starts, `GET` on `/` and `/flaky` with statuses 200 and 500. The first real request is then an increase from zero. After the change AWS counted 17 successes and 3 failures out of 20 calls, matching what curl saw. Scanner traffic still creates its own series on first use, and it is kept out of the panels and alerts anyway.

## Queries

Every panel and alert uses `rate()` or `increase()` and never a raw counter value. A raw value is the count since a particular replica started, which means nothing once replicas come and go. The instant query API also returns a series for five minutes after its last sample, so straight after the AWS task was replaced, a raw `sum()` included the old task's series and came out 27 too high. Rates over a window are not affected.

Requests to paths the app does not serve are labelled `route="unmatched"`. On AWS they are mostly scanners hitting the public load balancer with `POST` and `OPTIONS` requests to `/`, and random paths that return 404. They are left out of the rate, error and latency panels, and of both alerts, and shown only in the route breakdown. Labelling by route template rather than by raw path keeps a scan of random URLs in one series.

## Dashboard

The dashboard is defined in `envs/hub/dashboards/platform.json` and applied by Terraform. It has request rate, error ratio and p95 latency by cloud, requests per hour by cloud, route and status, and a logs panel of app errors from all three estates. A `cloud` variable at the top narrows every PromQL panel through `${cloud}` in its query.

Cloud Monitoring stores dashboards in a normalised form. It drops positions that are zero, adds a `valueType` to the variable and an empty `style` to the text tile. The first apply left Terraform wanting to change the dashboard on every plan. The JSON in the repo is now written in the normalised form, and the plan is clean.

## Alerts

There are two alert policies, each evaluated per cloud. One fires when more than 10% of requests on an estate return a 5xx. The other, a warning, fires when p95 latency on an estate goes over one second. Both queries group by `cloud`, so a problem on one estate opens an incident for that estate only. Both need at least 15 real requests in the five-minute window before they can fire, so one failed request on a quiet estate is not an incident. Both close themselves 30 minutes after the condition clears.

There is no alert on missing data. Cloud Run and Container Apps scale to zero between load runs, so no data is their normal state, and an absent-data alert would fire every hour. Whether an estate can serve at all is the load run's job, which records every request it makes.

`scripts/fire-alerts.sh` proves both alerts end to end. On 10 October the `errors` mode drove the error ratio to 0.35 on GCP, 0.34 on AWS and 0.24 on Azure. Three emails, one per cloud, arrived about three minutes after the traffic started, and a resolved notice followed on each thread once the traffic stopped. The `latency` mode applies the hub with a 1 ms threshold, runs the load workflow and puts the threshold back once the incidents are open. All three latency alerts fired. Screenshots of both are in `docs/evidence/`.

The latency histogram's smallest bucket is 5 ms, and every request the app serves finishes inside it, so p95 reads 0.005 on every estate. That is fine for an alert at one second, but it means the dashboard cannot show a difference below 5 ms. Finer buckets are in the production deltas.

## The load

All the traffic comes from `load.yml`, which sends 60 requests to `/` on each estate, one a second, and records the time of the first request and the p50 and p95. It is scheduled hourly, but GitHub dropped most scheduled runs. Between 5 and 8 October it ran 1, 5, 3 and 3 times a day against 24 expected. Every run that did happen reached all three estates. The panels are flat most of the time because of this, and it is why the alerts have a traffic floor.

The first request of a run shows the cold start. Azure took 26 to 28 seconds, GCP about 10 seconds when it had scaled to zero, and AWS, which never scales to zero, under a quarter of a second. The rest of each run sits under half a second on every estate, most of it network time between the GitHub runner and the endpoint.
