# Release Workflow

This is the human release checklist for iNiR.

## Rules

- `main` is the release branch.
- `prerelease` is the staging branch.
- Pushes are explicit manual steps. Do not hide them behind helper scripts.
- Tag creation and GitHub Release creation are separate from branch pushes.
- `scripts/release.sh` never pushes branches or tags for you. It only builds notes and can publish a GitHub Release for an already-pushed tag.

## Version bump checklist

Update these together for every release:

- `VERSION`
- `CHANGELOG.md`
- `README.md`
- `ARCHITECTURE.md`
- `docs/readme/README.*.md`
- `distro/arch/inir-shell/PKGBUILD`
- `distro/arch/inir-shell/.SRCINFO`
- `distro/arch/inir-meta/PKGBUILD`
- `distro/arch/inir-meta/.SRCINFO`
- `sdata/dist-arch/inir-deps/PKGBUILD`
- `sdata/dist-arch/install-deps.sh`

## Native GitHub Wiki prep

The repository docs live in `docs/`, but GitHub Wiki is a separate git repository with a special page layout.

To prepare a wiki-ready snapshot locally:

```bash
./scripts/wiki-sync.sh
```

That generates:

- `wiki/Home.md`
- `wiki/_Sidebar.md`
- `wiki/_Footer.md`
- one page per `docs/*.md`

This keeps the content reviewable inside the main repo before copying or syncing it into the actual GitHub Wiki repo.

## Local release prep

1. Update changelog and versioned files.
2. Regenerate `.SRCINFO` for Arch packages.
3. Verify:

```bash
git diff --check
bash -n scripts/release.sh
./scripts/release.sh notes X.Y.Z
```

## Release steps

1. Fast-forward `main` from `prerelease`:

```bash
git checkout main
git merge prerelease --ff-only
```

2. Create the annotated tag:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z - short release tagline"
```

3. Push branch and tag explicitly:

```bash
git push origin main
git push origin vX.Y.Z
```

4. Publish the GitHub Release from the changelog:

```bash
./scripts/release.sh publish X.Y.Z
```

5. Sync `prerelease` back to the released `main` tip:

```bash
git checkout prerelease
git merge main --ff-only
git push origin prerelease
```

## Contributor and issue attribution

- Mention fixed issues in the changelog entry using their real GitHub issue numbers when they were actually resolved in that release.
- Mention contributed PRs by linking the PR number in the release entry.
- Native GitHub contributor attribution comes from commits on the default branch. If the contributor's authored commit lands on `main`, GitHub will credit it in the contributors graph automatically.
