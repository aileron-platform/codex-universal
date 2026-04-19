Customized from [OpenAI codex-universal](https://github.com/openai/codex-universal) and used as the base image for `workspace-runtime`.

## Key Differences from Upstream

The upstream image installs everything as `root` under `/root/`.
This repo adapts it to run as `developer`, with tools installed under `/home/developer/`, so services inside `workspace-runtime` can run without root privileges.

Main changes:

- add a `developer` user with passwordless sudo
- install tools such as `pyenv`, `nvm`, `mise`, and `pipx` under `/home/developer/`
- remove language stacks not needed by this project, such as Rust, Go, Swift, Ruby, PHP, Elixir, Bun, and LLVM
- keep only Java 8, 17, and 21

## Build

This image is published by this repository's GitHub Actions workflow to Docker Hub as `ailerondocker/codex-universal`.
`workspace-runtime` should reference the published image through `docker-image://`.

```bash
# Build locally when you need to validate Dockerfile changes before pushing
docker build -t ailerondocker/codex-universal:latest .

# After changes are merged to main, GitHub Actions publishes:
# - ailerondocker/codex-universal:latest-amd64
# - ailerondocker/codex-universal:latest-arm64
# - ailerondocker/codex-universal:latest
```

The first build is expensive because it downloads and installs Python, Node.js, Java, and other tooling. Expect roughly 30 to 60 minutes. Rebuilds are much faster if the Dockerfile has not changed.

## Why Not Use Inline `additional_contexts`?

When Docker Compose uses a local directory in `additional_contexts`, BuildKit may attempt an inline build. This Dockerfile is large enough that inline builds can fail and produce a broken image, which then causes errors such as `unable to find user root` in the `workspace-runtime` Dockerfile.

Using a pre-built image via `docker-image://ailerondocker/codex-universal:latest` avoids that failure mode.

## `docker-compose.yml` Example

```yaml
workspace-runtime:
  build:
    additional_contexts:
      codex-universal: docker-image://ailerondocker/codex-universal:latest
```

## Language Runtimes

| Language | Versions | Manager |
|---|---|---|
| Python | 3.10, 3.11.12, 3.12, 3.13, 3.14.0 | `pyenv` |
| Node.js | 18, 20, 22, 24 | `nvm` |
| Java | 8, 17, 21 | `mise` |

### Runtime Version Selection

Use `CODEX_ENV_*` environment variables:

| Variable | Purpose |
|---|---|
| `CODEX_ENV_PYTHON_VERSION` | Python version |
| `CODEX_ENV_NODE_VERSION` | Node.js version |

See `setup_universal.sh` for details.
