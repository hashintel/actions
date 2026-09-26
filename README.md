# HASH GitHub Actions

Shared GitHub Actions building blocks for `hashintel` repositories:

- Composite actions in [`.github/actions/`](.github/actions).
- Reusable workflows in [`.github/workflows/`](.github/workflows). Workflows whose names start with `preflight-` or `housekeeping-` are the ones callers use. `lint.yml` checks this repository only.
- The organization's Renovate preset, [`renovate-config.json`](renovate-config.json). Repositories extend it with `github>hashintel/actions:renovate-config`.

## Using a workflow

Pin the reference to a full commit SHA and add a `# main` comment so Renovate can update it:

```yaml
jobs:
  actionlint:
    uses: hashintel/actions/.github/workflows/preflight-actionlint.yml@<commit-sha> # main
```
