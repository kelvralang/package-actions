# Kelvra package actions

Versioned reusable GitHub Actions workflows for Kelvra source and native package
repositories. Package repositories intentionally pin the stable major contract:

```yaml
jobs:
  ci:
    uses: kelvralang/package-actions/.github/workflows/source-ci.yml@v2
    with:
      package_name: my-package
      runtime_ref: main
```

The four public workflows are:

- `source-ci.yml`: metadata checks, runtime build, package validation, and an
  isolated local-path dependency test.
- `source-release.yml`: source archive, SHA-256 checksum, and GitHub Release.
- `native-ci.yml`: the same compatibility checks across the requested native
  target matrix.
- `native-release.yml`: target artifacts, checksums, and GitHub Release.

Native `targets` is a JSON array. Version 2 maps `linux-x86_64-gnu`,
`linux-arm64-gnu`, and `macos-arm64` to GitHub-hosted runners. Package-specific
setup, CMake flags, test commands, working directories, and artifact paths are
explicit optional inputs; defaults match the template repositories.

## Contract fixtures and releases

`fixtures.yml` calls all four reusable workflows. Release workflows run with
`publish_release: false`, producing workflow artifacts without creating a
GitHub Release. Run the Linux fixtures locally with:

```sh
./scripts/test-contract.sh
```

Release immutable contract tags such as `v2.0.0` only after the fixture workflow
passes. Move the `v2` major tag to that exact tested commit after the immutable
tag and GitHub Release exist. Packages consume `@v2`; they never consume
`@main`.

The guarded release helper enforces a clean `main`, an exact match with
`origin/main`, and a successful `fixtures.yml` run for that commit before it
creates the immutable release and advances the major tag:

```sh
./scripts/release-v2.sh v2.0.0
```

## Bootstrap a package

```sh
./scripts/new-package.sh my-source-package
./scripts/new-package.sh --native my-native-package
```

The command creates an independent repository from the relevant GitHub
template, rewrites the package/module identifiers and caller inputs, applies
the standard repository settings and `main` protection, validates locally, and
opens the initial setup pull request. Pass `--kelvra /path/to/kelvra` to avoid
building Kelvra `main` for validation.
