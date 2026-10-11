# Every resource that can carry tags or labels carries the five the cost
# views rely on. Each provider exposes the merged set under its own name.
# aws has tags_all, which includes default_tags. google has
# terraform_labels, which includes default_labels. azurerm has no defaults,
# so tags is what each resource passes in.
package main

import rego.v1

required_tags := {"project", "env", "owner", "estate", "managed-by"}

estates := {"hub", "gcp", "aws", "azure"}

tags_of(rc) := t if {
	startswith(rc.type, "aws_")
	t := rc.change.after.tags_all
	is_object(t)
}

tags_of(rc) := t if {
	startswith(rc.type, "google_")
	t := rc.change.after.terraform_labels
	is_object(t)
}

tags_of(rc) := t if {
	startswith(rc.type, "azurerm_")
	t := rc.change.after.tags
	is_object(t)
}

deny contains msg if {
	some rc in resources
	tags := tags_of(rc)
	some key in required_tags
	not tags[key]
	msg := sprintf("%s has no %s tag", [rc.address, key])
}

deny contains msg if {
	some rc in resources
	tags := tags_of(rc)
	some key in required_tags
	tags[key] == ""
	msg := sprintf("%s has an empty %s tag", [rc.address, key])
}

deny contains msg if {
	some rc in resources
	tags := tags_of(rc)
	estate := tags.estate
	not estate in estates
	msg := sprintf("%s has estate %q, which is not one of hub, gcp, aws or azure", [rc.address, estate])
}
