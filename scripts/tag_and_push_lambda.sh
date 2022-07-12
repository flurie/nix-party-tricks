#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

docker tag "$(docker images nix-lambda --format '{{.ID}}')" \
    "$(aws sts get-caller-identity | jq -r '.Account').dkr.ecr.us-east-2.amazonaws.com/nix:latest"
docker push \
    "$(aws sts get-caller-identity | jq -r '.Account').dkr.ecr.us-east-2.amazonaws.com/nix:latest"
