#!/usr/bin/env bash
# Plans every root, turns each plan into JSON and checks it against the rules
# in policy/. The same check runs in CI on every pull request. Plan JSON can
# hold values that should not be committed, so it goes in .plans/, which git
# ignores, and is replaced on every run.
#
#   scripts/policy-check.sh            all four roots
#   scripts/policy-check.sh aws azure  only the roots named
#
# Run from the repo root, signed in to the clouds whose roots you name.
set -euo pipefail

roots=("$@")
[ ${#roots[@]} -gt 0 ] || roots=(hub gcp aws azure)

conftest verify -p policy

mkdir -p .plans
for root in "${roots[@]}"; do
  (
    cd "envs/$root"
    terraform plan -no-color -lock=false -out="../../.plans/$root.tfplan" > /dev/null
    terraform show -json "../../.plans/$root.tfplan" > "../../.plans/$root.json"
    rm "../../.plans/$root.tfplan"
  )
done

conftest test -p policy $(printf '.plans/%s.json ' "${roots[@]}")
