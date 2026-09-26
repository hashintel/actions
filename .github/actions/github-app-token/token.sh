#!/usr/bin/env bash
# Exchange a Vault-signed App JWT for an installation token.
set -euo pipefail

: "${VAULT_ADDR:?}" "${VAULT_TOKEN:?}" "${TRANSIT_KEY:?}" "${APP_ID:?}" "${REPOSITORY:?}"
: "${CF_ACCESS_CLIENT_ID:?}" "${CF_ACCESS_CLIENT_SECRET:?}"

base64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

# GitHub rejects App JWTs living longer than ten minutes. The backdated `iat`
# absorbs clock skew between the runner and GitHub.
now=$(date +%s)
header=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url)
payload=$(printf '{"iss":"%s","iat":%d,"exp":%d}' "${APP_ID}" "$((now - 60))" "$((now + 540))" | base64url)
signing_input="${header}.${payload}"

# transit hashes the input itself, so `prehashed` stays false.
request=$(jq --null-input \
    --arg input "$(printf '%s' "${signing_input}" | openssl base64 -A)" \
    '{input: $input, signature_algorithm: "pkcs1v15", hash_algorithm: "sha2-256", prehashed: false}')

signature=$(curl --silent --show-error --fail-with-body --request POST \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "Content-Type: application/json" \
    --header "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
    --header "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
    --data "${request}" \
    "${VAULT_ADDR%/}/v1/transit/sign/${TRANSIT_KEY}" | jq --exit-status --raw-output '.data.signature')

# Vault prefixes the base64 signature with the key version that produced it.
jwt="${signing_input}.$(printf '%s' "${signature#vault:v*:}" | tr '+/' '-_' | tr -d '=')"

github_api() {
    curl --silent --show-error --fail-with-body \
        --header "Authorization: Bearer ${jwt}" \
        --header "Accept: application/vnd.github+json" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        "$@"
}

# Looked up rather than configured, so a new caller needs no extra input.
# `--exit-status` so a 200 that carries no field fails here rather than further
# down as an unexplained 401.
installation=$(github_api "https://api.github.com/repos/${REPOSITORY}/installation" | jq --exit-status --raw-output '.id')
token=$(github_api --request POST \
    --data "$(jq --null-input --arg repo "${REPOSITORY#*/}" '{repositories: [$repo]}')" \
    "https://api.github.com/app/installations/${installation}/access_tokens" | jq --exit-status --raw-output '.token')

echo "::add-mask::${token}"
echo "token=${token}" >>"${GITHUB_OUTPUT}"
