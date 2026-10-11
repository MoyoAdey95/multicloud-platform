# Shared helpers. Every rule reads Terraform's plan JSON, so it checks what
# would exist after the apply, including values that come from provider
# defaults such as default_tags and default_labels.
package main

import rego.v1

# Resources that will exist after the apply. A resource being destroyed has
# no "after" and nothing left to check.
resources contains rc if {
	some rc in input.resource_changes
	rc.change.after != null
	not "delete" in rc.change.actions
}

resources_of(type) := {rc | some rc in resources; rc.type == type}
