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

## Workflow lint profile

`preflight-lint.yml` runs jactionlint with the `pedantic` profile, which every repository is moving to. A caller still fixing its findings can pass `jactionlint-profile: correctness` or `default` for the time being:

```yaml
jobs:
  lint:
    uses: hashintel/actions/.github/workflows/preflight-lint.yml@<commit-sha> # main
    with:
      jactionlint-profile: correctness
```

The input is removed once every caller lints with `pedantic`. Mutable runner labels such as `ubuntu-latest` fail with every profile.

Findings of every level fail the check, warnings and info included. To keep a finding that is justified, put an ignore comment for its rule on the line above it, with the reason on a comment line of its own. Text after the rule ID on the ignore line is read as part of the pattern, so the reason cannot go there.

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
