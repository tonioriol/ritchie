# Acestreamio addon repo: detailed CI/release plan (SemVer releases → GHCR → auto-deploy)

Goal: when you merge changes to the addon repo, it **automatically**:

1) decides whether a new release is warranted (based on commit messages)
2) creates a SemVer git tag like `v1.0.0` (no manual tagging)
3) builds and pushes `ghcr.io/tonioriol/acestreamio:v1.0.0`
4) the cluster updates itself via Argo CD Image Updater (no git commits in the GitOps repo)

This repo already has the cluster-side wiring:

- Image updater install: [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1)
- Allow in-cluster app mutation: [`apps/root.yaml`](apps/root.yaml:1)
- `acestreamio` tracked for updates: [`apps/acestreamio.yaml`](apps/acestreamio.yaml:1)

Argo CD Image Updater is configured to deploy **only** SemVer tags matching:

- `^v?\d+\.\d+\.\d+$`

## Phase 1 — Put container build *in the addon repo*

Best practice is that the addon repo contains:

- `Dockerfile`
- `.dockerignore`
- `package.json` and lockfile
- GitHub Actions workflows

You can copy the bootstrap Dockerfile from this GitOps repo:

- [`docker/acestreamio/Dockerfile`](docker/acestreamio/Dockerfile:1)

Recommended additions:

1) Add `.dockerignore` to avoid huge builds:
   - `node_modules`
   - `.git`
   - local caches
2) Ensure the container runs production install (`npm ci --omit=dev`) and starts reliably.
3) Keep the container listening on the configured port (the cluster uses port 7000).

## Phase 2 — Adopt Conventional Commits (release signal)

semantic-release uses commit messages to decide version bumps.

Adopt this convention (examples):

- `fix: handle HEAD requests correctly` → patch bump
- `feat: add new channel list endpoint` → minor bump
- `feat!: change manifest schema` or `BREAKING CHANGE: ...` → major bump

Recommended: enforce via a PR check (commitlint) so main stays clean.

## Phase 3 — Add semantic-release (SemVer generator)

### 3.1 Add dependencies

In addon repo `devDependencies`:

- `semantic-release`
- `@semantic-release/commit-analyzer`
- `@semantic-release/release-notes-generator`
- `@semantic-release/github`
- (optional) `@semantic-release/changelog`
- (optional) `@semantic-release/git`

### 3.2 Add config

Create `.releaserc.json` in the addon repo:

```json
{
  "branches": ["main"],
  "tagFormat": "v${version}",
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/github"
  ]
}
```

If you want changelog commits back into the addon repo, add `@semantic-release/changelog` + `@semantic-release/git`.

## Phase 4 — GitHub Actions workflows (recommended split)

Use **two** workflows:

1) CI workflow (on PRs + pushes) → runs tests/lint.
2) Release workflow (on pushes to main) → runs semantic-release and creates tag/release.
3) Image build workflow (on tag push `v*.*.*`) → builds/pushes GHCR image.

Splitting image build into “on tag push” keeps the logic simple and guarantees: **only released versions are built/pushed**.

### 4.1 CI workflow (example)

`.github/workflows/ci.yml`

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm test --if-present
      - run: npm run lint --if-present
```

### 4.2 Release workflow (semantic-release)

`.github/workflows/release.yml`

```yaml
name: Release
on:
  push:
    branches: [main]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npx semantic-release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Notes:

- `fetch-depth: 0` is important so semantic-release can see tags.
- You do not need a PAT for creating releases/tags; `GITHUB_TOKEN` works with correct permissions.

### 4.3 Image build workflow (on SemVer tags)

`.github/workflows/image.yml`

```yaml
name: Build & Push Image
on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ghcr.io/tonioriol/acestreamio:${{ github.ref_name }}
```

This produces:

- `ghcr.io/tonioriol/acestreamio:v1.0.0`

## Phase 5 — Verify end-to-end

1) Merge a commit with Conventional Commit message that should produce a release.
2) Confirm semantic-release created a tag `vX.Y.Z` and GitHub Release.
3) Confirm GHCR has `ghcr.io/tonioriol/acestreamio:vX.Y.Z`.
4) Confirm Argo CD Image Updater picks it up and ArgoCD rolls out.

Cluster-side prerequisites (already in place in this repo):

- Image updater controller installed via [`apps/argocd-image-updater.yaml`](apps/argocd-image-updater.yaml:1)
- ArgoCD “ignore differences” allowing `Application` Helm param mutation via [`apps/root.yaml`](apps/root.yaml:1)

Cluster secrets:

- `argocd/ghcr-pull` must exist so Image Updater can list tags (private GHCR)
- `media/ghcr-pull` must exist so the nodes can pull images

## Where should Dockerfile live?

Best practice: **addon repo**.

This GitOps repo should hold only deployment config (Helm/ArgoCD). Keeping Dockerfile + workflows in the addon repo ensures “code + build definition + release logic” evolve together.
