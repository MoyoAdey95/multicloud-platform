# Each rule is tested against a plan it should pass and one it should fail,
# so a rule that silently stops matching shows up here rather than as a
# clean result on a real plan. Run with: conftest verify -p policy
package main

import rego.v1

plan(type, after) := {"resource_changes": [{
	"address": sprintf("%s.test", [type]),
	"type": type,
	"change": {"actions": ["create"], "after": after},
}]}

good_tags := {"project": "multicloud-platform", "env": "dev", "owner": "moyo", "estate": "aws", "managed-by": "terraform"}

test_tags_pass if {
	count(deny) == 0 with input as plan("aws_s3_bucket", {"tags_all": good_tags})
}

test_tags_missing if {
	deny["aws_s3_bucket.test has no owner tag"] with input as plan("aws_s3_bucket", {"tags_all": object.remove(good_tags, ["owner"])})
}

test_tags_bad_estate if {
	count(deny) == 1 with input as plan("azurerm_resource_group", {"tags": object.union(good_tags, {"estate": "prod"})})
}

test_labels_google if {
	count(deny) == 1 with input as plan("google_storage_bucket", {
		"terraform_labels": object.remove(good_tags, ["env"]),
		"public_access_prevention": "enforced",
		"uniform_bucket_level_access": true,
	})
}

test_deleted_resources_ignored if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_s3_bucket.gone", "type": "aws_s3_bucket",
		"change": {"actions": ["delete"], "after": null},
	}]}
}

policy_doc(statements) := json.marshal({"Version": "2012-10-17", "Statement": statements})

test_aws_wildcard_action if {
	count(deny) > 0 with input as plan("aws_iam_role_policy", {"policy": policy_doc([{"Effect": "Allow", "Action": "s3:*", "Resource": "arn:aws:s3:::b/*"}])})
}

test_aws_star_resource_allowed if {
	count(deny) == 0 with input as plan("aws_iam_role_policy", {"policy": policy_doc([{"Effect": "Allow", "Action": ["ecr:GetAuthorizationToken"], "Resource": "*"}])})
}

test_aws_star_resource_denied if {
	count(deny) == 1 with input as plan("aws_iam_role_policy", {"policy": policy_doc([{"Effect": "Allow", "Action": ["s3:GetObject"], "Resource": "*"}])})
}

trust(condition) := json.marshal({"Statement": [{
	"Effect": "Allow",
	"Principal": {"Federated": "arn:aws:iam::1:oidc-provider/token.actions.githubusercontent.com"},
	"Action": "sts:AssumeRoleWithWebIdentity",
	"Condition": condition,
}]})

test_github_trust_exact if {
	count(deny) == 0 with input as plan("aws_iam_role", {"tags_all": good_tags, "assume_role_policy": trust({"StringEquals": {"token.actions.githubusercontent.com:sub": "repo:o/r:ref:refs/heads/main"}})})
}

test_github_trust_wildcard if {
	count(deny) == 1 with input as plan("aws_iam_role", {"tags_all": good_tags, "assume_role_policy": trust({"StringLike": {"token.actions.githubusercontent.com:sub": "repo:o/r:*"}})})
}

test_google_basic_role if {
	count(deny) == 1 with input as plan("google_project_iam_member", {"role": "roles/editor", "member": "serviceAccount:x"})
}

test_google_public_invoker_allowed if {
	count(deny) == 0 with input as plan("google_cloud_run_v2_service_iam_member", {"role": "roles/run.invoker", "member": "allUsers"})
}

test_google_public_other_denied if {
	count(deny) == 1 with input as plan("google_storage_bucket_iam_member", {"role": "roles/storage.objectViewer", "member": "allUsers"})
}

test_google_sa_key if {
	count(deny) == 1 with input as plan("google_service_account_key", {})
}

test_azure_scope_resource_ok if {
	count(deny) == 0 with input as plan("azurerm_role_assignment", {"role_definition_name": "AcrPush", "scope": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.ContainerRegistry/registries/r"})
}

test_azure_scope_group_denied if {
	count(deny) == 1 with input as plan("azurerm_role_assignment", {"role_definition_name": "AcrPush", "scope": "/subscriptions/s/resourceGroups/rg"})
}

test_azure_contributor_denied if {
	count(deny) == 1 with input as plan("azurerm_role_assignment", {"role_definition_name": "Contributor", "scope": "/subscriptions/s/resourceGroups/rg/providers/Microsoft.App/containerApps/a"})
}

test_ingress_80_warns_only if {
	count(deny) == 0 with input as plan("aws_vpc_security_group_ingress_rule", {"tags_all": good_tags, "cidr_ipv4": "0.0.0.0/0", "from_port": 80})
	count(warn) == 1 with input as plan("aws_lb_listener", {"tags_all": good_tags, "protocol": "HTTP"})
}

test_ingress_ssh_denied if {
	count(deny) == 1 with input as plan("aws_vpc_security_group_ingress_rule", {"tags_all": good_tags, "cidr_ipv4": "0.0.0.0/0", "from_port": 22})
}

test_public_bucket_denied if {
	count(deny) == 1 with input as plan("google_storage_bucket", {"terraform_labels": good_tags, "public_access_prevention": "inherited", "uniform_bucket_level_access": true})
}

test_acr_admin_denied if {
	count(deny) == 1 with input as plan("azurerm_container_registry", {"tags": good_tags, "admin_enabled": true})
}

test_mutable_ecr_denied if {
	count(deny) == 1 with input as plan("aws_ecr_repository", {"tags_all": good_tags, "image_tag_mutability": "MUTABLE"})
}

test_aws_read_only_wildcards_allowed if {
	count(deny) == 0 with input as plan("aws_iam_role_policy", {"policy": policy_doc([{"Effect": "Allow", "Action": ["ec2:Describe*", "ecs:List*"], "Resource": "*"}])})
}

test_aws_get_wildcard_denied if {
	count(deny) == 2 with input as plan("aws_iam_role_policy", {"policy": policy_doc([{"Effect": "Allow", "Action": ["s3:Get*"], "Resource": "*"}])})
}

test_azure_reader_on_group_allowed if {
	count(deny) == 0 with input as plan("azurerm_role_assignment", {"role_definition_name": "Reader", "scope": "/subscriptions/s/resourceGroups/rg"})
}

test_azure_reader_on_subscription_denied if {
	count(deny) == 1 with input as plan("azurerm_role_assignment", {"role_definition_name": "Reader", "scope": "/subscriptions/s"})
}
