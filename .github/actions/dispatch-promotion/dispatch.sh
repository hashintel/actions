#!/usr/bin/env bash
# Start the promote workflow for one commit and print the run it started.
set -euo pipefail

: "${GITHUB_APP_TOKEN:?}" "${REPOSITORY:?}" "${TARGET_ENVIRONMENT:?}" "${COMMIT_SHA:?}"
: "${GITHUB_API_URL:?}" "${GITHUB_STEP_SUMMARY:?}"

# The environment, preceded by the project when one is given.
target="${PROJECT:+${PROJECT} }${TARGET_ENVIRONMENT}"

# `dry_run` defaults to true in the workflow, which previews without deploying.
# An empty PROJECT is left out, so the workflow applies its own default.
request=$(jq --null-input \
    --arg commit "${COMMIT_SHA}" \
    --arg environment "${TARGET_ENVIRONMENT}" \
    --arg project "${PROJECT:-}" \
    '{
        ref: "main",
        inputs: (
            {image_tag: $commit, target_environment: $environment, dry_run: "false", force_deploy: "false"}
            + if $project == "" then {} else {project: $project} end
        ),
        return_run_details: true
    }')

if ! response=$(curl --silent --show-error --fail-with-body --request POST \
    --header "Authorization: Bearer ${GITHUB_APP_TOKEN}" \
    --header "Accept: application/vnd.github+json" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --data "${request}" \
    "${GITHUB_API_URL}/repos/${REPOSITORY}/actions/workflows/promote.yml/dispatches"); then
    echo "::error::Dispatching the promotion to ${target} failed: ${response}"
    exit 1
fi

# The run exists once the request succeeds, so a response without its URL is not a failure.
run_url=$(jq --raw-output '.html_url // empty' <<<"${response}" 2>/dev/null) || run_url=""
echo "Promotion to ${target}: ${run_url:-started, GitHub returned no run URL}" | tee -a "${GITHUB_STEP_SUMMARY}"
