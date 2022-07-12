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

jq -nrcR '[inputs | rtrimstr("\r") | ./","][1] | { Version: 1, AccessKeyId: .[0], SecretAccessKey: .[1] }' "$PRJ_ROOT"/"$AWS_USERNAME"_accessKeys.csv
