# HASH GitHub Actions

Shared GitHub Actions building blocks for `hashintel` repositories:

- Composite actions in [`.github/actions/`](.github/actions).
- Reusable workflows in [`.github/workflows/`](.github/workflows). Workflows whose names start with `preflight-` or `housekeeping-` are the ones callers use. `lint.yml` checks this repository only.
- The organization's Renovate preset, [`renovate-config.json`](renovate-config.json). Repositories extend it with `github>hashintel/actions:renovate-config`.

## Using a workflow

Pin the reference to a full commit SHA and add a `# main` comment so Renovate can update it:

```yaml
jobs:
  lint:
    uses: hashintel/actions/.github/workflows/preflight-lint.yml@<commit-sha> # main
```

## Workflow lint

`preflight-lint.yml` runs jactionlint with the `pedantic` profile. It includes the rule against mutable runner labels such as `ubuntu-latest`. Findings of every level fail the check, warnings and info included. To keep a finding that is justified, put an ignore comment for its rule on the line above it, with the reason on a comment line of its own. Text after the rule ID on the ignore line is read as part of the pattern, so the reason cannot go there.

```yaml
    # <reason>
    # jactionlint ignore=mutable-runner-label
    runs-on: ubuntu-latest
```

## Pull request checks

Call `preflight-pr-title.yml` and `preflight-dependencies.yml` from a workflow that runs on `pull_request`, not `pull_request_target`. The PR title check needs the `edited` type so it reruns when the title changes:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, edited]
  merge_group:

jobs:
  pr-title:
    uses: hashintel/actions/.github/workflows/preflight-pr-title.yml@<commit-sha> # main
  dependencies:
    uses: hashintel/actions/.github/workflows/preflight-dependencies.yml@<commit-sha> # main
    permissions:
      contents: read
      pull-requests: write
```

The dependency review posts its summary comment on a failing pull request from a branch of the same repository. A fork's pull request gets a read-only token, so it gets no comment, and the findings stay in the job summary. Both workflows still accept `pull_request_target` until every caller has moved.

## Skipping a check

Each job of the `preflight-` workflows has a boolean input that runs it, `true` by default. A caller that passes `false` skips the job. GitHub counts a skipped job as passed, so a ruleset that requires the check still lets the pull request merge:

```yaml
jobs:
  pr-title:
    uses: hashintel/actions/.github/workflows/preflight-pr-title.yml@<commit-sha> # main
    with:
      run-linear-issue-id: false
```

| Workflow | Input | Check |
| --- | --- | --- |
| `preflight-dependencies.yml` | `run-dependency-review` | Review |
| `preflight-lint.yml` | `run-actionlint` | Actionlint |
| `preflight-lint.yml` | `run-actions-lockfile` | Validate actions lockfile |
| `preflight-lint.yml` | `run-renovate-config` | Validate Renovate config |
| `preflight-pr-title.yml` | `run-linear-issue-id` | Linear Issue ID |
| `preflight-todo-comments.yml` | `run-todo-comments` | Scan |

## Renovate

`housekeeping-dependencies.yml` runs Renovate for the calling repository. Call it on a schedule and on dispatch from `main`:

```yaml
on:
  schedule:
    - cron: "0 3 * * *"
  workflow_dispatch:

jobs:
  renovate:
    name: Dependencies
    permissions:
      actions: read
      contents: read
      id-token: write
    uses: hashintel/actions/.github/workflows/housekeeping-dependencies.yml@<commit-sha> # main
    with:
      vault-role: ci-hashintel-<repository>-renovate
      environment: Renovate
    secrets:
      # Only in the `Renovate` environment of the called jobs; a called workflow gets only the secrets its caller names.
      # jactionlint ignore=secrets-outside-env
      CF_ACCESS_CLIENT_SECRET: ${{ secrets.CF_ACCESS_CLIENT_SECRET }}
      # Only in the `Renovate` environment of the called jobs; a called workflow gets only the secrets its caller names.
      # jactionlint ignore=secrets-outside-env
      RENOVATE_TOKEN_ENC_KEY: ${{ secrets.RENOVATE_TOKEN_ENC_KEY }}
```

The calling repository names its Vault role, `ci-<owner>-<repository>-renovate`, and the environment both jobs run in, `Renovate` by convention. The role accepts only that repository, that environment and `main`. The environment's deployment branches are limited to `main`, with no bypass for administrators, so that no job of another ref can read its secrets. It holds:

- The variable `VAULT_ADDR`, the address of the staging Vault.
- The variable `CF_ACCESS_CLIENT_ID` and the secret `CF_ACCESS_CLIENT_SECRET`, the ID and secret of the Cloudflare Access service token for the staging Vault.
- The secret `RENOVATE_TOKEN_ENC_KEY`, a random passphrase of the repository's own. The token's ciphertext is in the run log, which a public repository shows to everyone, so a passphrase shared between repositories would let a run of one decrypt the token of another. Nobody needs to know it, so generate it straight into the secret:

```bash
openssl rand -base64 48 | gh secret set RENOVATE_TOKEN_ENC_KEY --repo hashintel/<repository> --env Renovate
```
