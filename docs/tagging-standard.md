# Tagging standard

Every resource this repo creates on any of the three clouds carries the same five keys. The same keys on all three is what lets one cost query group spend by estate, and lets one policy check run against every plan.

| Key | Values | Meaning |
|---|---|---|
| project | multicloud-platform | Which piece of work the resource belongs to |
| env | dev | Environment. There is only one here |
| owner | moyo | Who to ask about it |
| estate | hub, gcp, aws, azure | Which part of the platform it belongs to |
| managed-by | terraform, console-bootstrap, cli-bootstrap | How it came to exist |

Keys and values are all lowercase with hyphens. GCP labels only allow lowercase letters, digits, underscores and hyphens, so a scheme that works as GCP labels also works as AWS and Azure tags, but not the other way round.

`estate` is set per root in `locals.tf` rather than as a variable, so a plan in the AWS root cannot label something as belonging to Azure. The hub and the GCP estate share a project, and this key is what tells their costs apart.

## How each provider applies them

The google provider takes the map once as `default_labels`, and the aws provider takes it once as `default_tags`. Every resource that supports labels or tags then gets them without the resource block mentioning them.

azurerm has no equivalent. Every Azure resource passes `local.common_tags` in its own `tags` argument, and one that leaves it out gets no tags at all. The policy checks in CI are what catch that.

## Where tags stop working

Some resources cannot carry tags or labels at all, and some cost lines belong to no resource, such as tax and support charges. Those show up as unallocated in the cost views rather than being spread across the estates.

On AWS a tag key only appears in billing data after it is activated as a cost allocation tag in the Billing console, and activation is not retroactive. `project` is already active in the account. `estate` is only needed in the AWS data if it is activated straight after the first AWS resources exist. With one estate per provider, `project` alone is enough to find the AWS estate's spend.

The `cloud` label on metrics and logs is a different thing. It is set by the collector on telemetry, not on resources, and is covered in the observability decisions.
