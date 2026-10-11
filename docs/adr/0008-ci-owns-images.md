# 0008 CI owns the running image

## Context

Terraform builds each estate, and CI deploys a new image to all three on every change to the app.

## Decision

Terraform owns the shape of each service, its size, sidecars, identity, and network. CI owns which image the app container runs. The image fields are in `lifecycle { ignore_changes }`. The app container's image on Cloud Run and Container Apps, and the task definition on the ECS service. The deploy workflow builds once, pushes the same digest to all three registries, checks the digests match, and deploys that digest.

## Rejected

Terraform deploying the image, which would mean an apply with cloud credentials on every app change. CI owning everything, which loses the reviewable plan for changes to the services' shape.

## Consequences

A deploy is never reported as drift. On AWS, a change Terraform makes to the task definition, such as a new collector image, registers a new revision but does not roll it out. The next deploy picks it up, because it copies the latest revision and changes only the app image. The collector image is still Terraform's, set by digest in each estate's variables.
