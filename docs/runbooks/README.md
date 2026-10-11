# Runbooks

Three runbooks for the things that can go wrong because this is a multicloud platform. Generic incident handling such as severity, rollback decisions, and the review afterwards. Already written up in [cloud-incident-runbooks](https://github.com/MoyoAdey95/cloud-incident-runbooks), and these link to it rather than repeat it.

| Runbook | When |
|---|---|
| [Estate down](estate-down.md) | One estate stops serving, or its error ratio alert fires |
| [Telemetry federation broken](telemetry-federation-broken.md) | An estate is serving but its metrics or logs stop reaching the hub |
| [Cost spike](cost-spike.md) | An estate's daily cost jumps, or a budget alert fires |

Severity follows [severity definitions](https://github.com/MoyoAdey95/cloud-incident-runbooks/blob/main/severity-definitions.md), and anything SEV2 or above gets a [post-incident review](https://github.com/MoyoAdey95/cloud-incident-runbooks/blob/main/templates/post-incident-review.md).
