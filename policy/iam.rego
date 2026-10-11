# Least privilege across the three clouds, checked on what the plan grants.
package main

import rego.v1

# AWS actions that have no resource-level permissions, so a policy can only
# grant them on "*". Anything else on "*" should name its resource.
aws_star_resource_ok := {
	"ecr:GetAuthorizationToken",
	"ecs:RegisterTaskDefinition",
	"ecs:DescribeTaskDefinition",
	"ssmmessages:CreateControlChannel",
	"ssmmessages:CreateDataChannel",
	"ssmmessages:OpenControlChannel",
	"ssmmessages:OpenDataChannel",
}

as_set(x) := {x} if is_string(x)

as_set(x) := {v | some v in x} if is_array(x)

aws_statements contains [rc.address, s] if {
	some rc in resources_of("aws_iam_role_policy")
	some s in json.unmarshal(rc.change.after.policy).Statement
}

deny contains msg if {
	some pair in aws_statements
	[address, s] := pair
	some action in as_set(s.Action)
	contains(action, "*")
	msg := sprintf("%s grants the wildcard action %s", [address, action])
}

deny contains msg if {
	some pair in aws_statements
	[address, s] := pair
	"*" in as_set(s.Resource)
	some action in as_set(s.Action)
	not action in aws_star_resource_ok
	msg := sprintf("%s grants %s on every resource", [address, action])
}

# A role GitHub can assume must be pinned to an exact subject. StringLike
# with a wildcard would let other branches, or other repositories, in.
deny contains msg if {
	some rc in resources_of("aws_iam_role")
	some s in json.unmarshal(rc.change.after.assume_role_policy).Statement
	contains(object.get(s, ["Principal", "Federated"], ""), "token.actions.githubusercontent.com")
	not s.Condition.StringEquals["token.actions.githubusercontent.com:sub"]
	msg := sprintf("%s trusts GitHub without an exact subject condition", [rc.address])
}

google_basic_roles := {"roles/owner", "roles/editor", "roles/viewer"}

google_iam_types := {
	"google_project_iam_member",
	"google_storage_bucket_iam_member",
	"google_bigquery_dataset_iam_member",
	"google_artifact_registry_repository_iam_member",
	"google_cloud_run_v2_service_iam_member",
	"google_service_account_iam_member",
}

deny contains msg if {
	some rc in resources
	rc.type in google_iam_types
	rc.change.after.role in google_basic_roles
	msg := sprintf("%s grants the basic role %s", [rc.address, rc.change.after.role])
}

# Keys are what every identity in this repo exists to avoid.
deny contains msg if {
	some rc in resources_of("google_service_account_key")
	msg := sprintf("%s creates a service account key", [rc.address])
}

# The one public grant is the Cloud Run invoker, which is what makes the GCP
# estate's endpoint public. Anything else given to everyone is a mistake.
deny contains msg if {
	some rc in resources
	rc.type in google_iam_types
	rc.change.after.member in {"allUsers", "allAuthenticatedUsers"}
	not public_invoker(rc)
	msg := sprintf("%s grants %s to %s", [rc.address, rc.change.after.role, rc.change.after.member])
}

public_invoker(rc) if {
	rc.type == "google_cloud_run_v2_service_iam_member"
	rc.change.after.role == "roles/run.invoker"
}

azure_broad_roles := {"Owner", "Contributor", "User Access Administrator"}

deny contains msg if {
	some rc in resources_of("azurerm_role_assignment")
	rc.change.after.role_definition_name in azure_broad_roles
	msg := sprintf("%s assigns %s", [rc.address, rc.change.after.role_definition_name])
}

# Role assignments go on the one resource that needs them, never on a whole
# subscription or resource group.
deny contains msg if {
	some rc in resources_of("azurerm_role_assignment")
	scope := rc.change.after.scope
	regex.match(`^/subscriptions/[^/]+(/resourceGroups/[^/]+)?/?$`, scope)
	msg := sprintf("%s is scoped to a whole subscription or resource group", [rc.address])
}
