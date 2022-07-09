#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq

# Expected Schema -
# {
#   "Version": 1,
#   "AccessKeyId": "an AWS access key",
#   "SecretAccessKey": "your AWS secret access key",
#   "SessionToken": "the AWS session token for temporary credentials", (optional, it turns out)
#   "Expiration": "ISO8601 timestamp when the credentials expire" (explicitly optional)
# }

# jq -nrR '[inputs | rtrimstr("\r") | ./","][1] | ["[default]", "aws_access_key_id = \(.[0])", "aws_secret_access_key = \(.[1])"] | join("\n")' "$PRJ_ROOT"/"$AWS_USERNAME"_accessKeys.csv

jq -nrcR '[inputs | rtrimstr("\r") | ./","][1] | { Version: 1, AccessKeyId: .[0], SecretAccessKey: .[1] }' "$PRJ_ROOT"/"$AWS_USERNAME"_accessKeys.csv
