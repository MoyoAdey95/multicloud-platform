# What is reachable from the internet, and what can be changed after it is
# published.
#
# A setting left out of the code is missing from the plan, not false, and a
# Rego comparison with a missing value is never true. So every rule here reads
# the value with object.get and a default, and treats a setting that is not
# written down as a failure. The safe value has to be set on purpose.
package main

import rego.v1

# The load balancer is the only thing open to the internet on AWS, on port 80
# because the lab has no domain or certificate. That is a warning, listed in
# the production deltas. Any other port open to everyone fails.
deny contains msg if {
	some rc in resources_of("aws_vpc_security_group_ingress_rule")
	rc.change.after.cidr_ipv4 == "0.0.0.0/0"
	not rc.change.after.from_port in {80, 443}
	msg := sprintf("%s opens port %v to the internet", [rc.address, rc.change.after.from_port])
}

warn contains msg if {
	some rc in resources_of("aws_lb_listener")
	rc.change.after.protocol == "HTTP"
	msg := sprintf("%s serves plain HTTP", [rc.address])
}

deny contains msg if {
	some rc in resources_of("google_storage_bucket")
	object.get(rc.change.after, "public_access_prevention", "unset") != "enforced"
	msg := sprintf("%s does not enforce public access prevention", [rc.address])
}

deny contains msg if {
	some rc in resources_of("google_storage_bucket")
	object.get(rc.change.after, "uniform_bucket_level_access", false) != true
	msg := sprintf("%s allows per-object ACLs", [rc.address])
}

deny contains msg if {
	some rc in resources_of("azurerm_container_registry")
	object.get(rc.change.after, "admin_enabled", true) != false
	msg := sprintf("%s has the admin user turned on", [rc.address])
}

deny contains msg if {
	some rc in resources_of("azurerm_container_app")
	some ingress in rc.change.after.ingress
	object.get(ingress, "allow_insecure_connections", true) != false
	msg := sprintf("%s accepts plain HTTP", [rc.address])
}

# The same digest runs everywhere, so a tag must never move to a different
# image once pushed.
deny contains msg if {
	some rc in resources_of("aws_ecr_repository")
	object.get(rc.change.after, "image_tag_mutability", "unset") != "IMMUTABLE"
	msg := sprintf("%s allows tags to be overwritten", [rc.address])
}

deny contains msg if {
	some rc in resources_of("google_artifact_registry_repository")
	object.get(rc.change.after, "format", "DOCKER") == "DOCKER"
	not object.get(rc.change.after, ["docker_config", 0, "immutable_tags"], false)
	msg := sprintf("%s allows tags to be overwritten", [rc.address])
}
