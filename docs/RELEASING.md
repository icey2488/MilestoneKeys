# Releasing MilestoneKeys

Releases are built and uploaded by the [BigWigs packager](https://github.com/BigWigsMods/packager)
via `.github/workflows/release.yml`, which fires on any pushed tag matching `v*`.
Nothing is published unless a tag is pushed.

---

## Per-patch bump (the only recurring work)

When Blizzard ships a new patch, exactly one thing in this addon needs changing:
the `## Interface` number in `MilestoneKeys.toc`.

**There is no dungeon list to update.** MilestoneKeys hardcodes no instance IDs,
challenge map IDs, or season pools. The keystone pool is resolved at runtime in
three places, all of which pick up new dungeons automatically:

| Location | Call |
|---|---|
| `UI.lua` `BuildDungeonList()` | `C_ChallengeMode.GetMapTable()`, rebuilt each time the options panel opens |
| `Core.lua` `GetCurrentDungeonContext()` | Same call, matching `GetInstanceInfo()` against `GetMapUIInfo()` |
| `Predict.lua` `GetMDTDungeonIdx()` | Resolves `challengeMapID` → MDT `dungeonIdx`; MDT owns route and forces data |

Interface number format is the patch version with periods and leading zeroes
removed: `12.1.0` → `120100`. Confirm in-game with:

```
/dump select(4, GetBuildInfo())
```

Reference: [Getting the current interface number](https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number).

---

## Release checklist

1. **Bump the TOC.** In `MilestoneKeys.toc`, set `## Interface` to the new number
   and `## Version` to the new version. These must be in the same commit — the
   packager reads both.

2. **Write the CHANGELOG entry.** Add a `## [x.y.z] - YYYY-MM-DD` section to
   `CHANGELOG.md` above the previous release. This file is shipped verbatim to
   CurseForge, Wago, and WoWInterface via the `manual-changelog` directive in
   `.pkgmeta` — users read it, so write it for them, not for maintainers.

3. **Know what happens if CurseForge lacks the game version.** The packager sends
   every `## Interface` value in the TOC as a supported game version, resolving
   it against `api/game/wow/versions` (game type `517` for retail).

   An unmatched version **does not fail the build.** `release.sh` silently falls
   back to the next-highest registered version below it, or failing that the
   highest version overall, and logs:

   ```
   WARNING: No CurseForge game version match for "12.1.0", using "12.0.7"
   ```

   That is the dangerous case, not a hard failure — the release uploads looking
   healthy while telling the CurseForge app the addon is not compatible with the
   current patch. **Grep the job log for `No CurseForge game version match`
   after every release.** If it appears, wait for CurseForge to register the
   version and re-tag; do not paper over it with `-g`.

   In practice this is rare. CurseForge registers new versions while the patch is
   on PTR, typically weeks ahead of launch, so by live day the version is already
   there. A genuine hard failure only happens if the versions API can't be
   reached at all, which skips the CurseForge upload entirely and sets a non-zero
   exit code.

4. **Commit, tag, push.**

   ```bash
   git add MilestoneKeys.toc CHANGELOG.md
   git commit -m "chore: bump to x.y.z, TOC Interface NNNNNN for patch X.Y"
   git push origin main

   git tag -a vx.y.z -m "vx.y.z"
   git push origin vx.y.z
   ```

   The tag is what triggers the workflow. The packager derives the version from
   the tag name, so the tag and `## Version` must agree.

5. **Watch the run.** Actions → "Package and Release". Two things commonly go
   wrong:
   - *Externals checkout fails* — the CurseForge SVN repos in `.pkgmeta` are
     occasionally down. Re-run the job.
   - *Silently downgraded game version* — see step 3. This one is a warning in a
     green build, so it will not announce itself.

6. **Verify the artifact.** Download the zip from the GitHub release and confirm
   it contains `Libs/` (pulled fresh from upstream, not the committed copies),
   your curated `CHANGELOG.md`, and no `docs/`, `README.md`, or `.github/`.

---

## Required secrets

Set in repository Settings → Secrets and variables → Actions. Only `CF_API_KEY`
is needed for CurseForge; the rest are optional and their upload steps are
skipped if absent.

| Secret | Purpose |
|---|---|
| `CF_API_KEY` | CurseForge upload (project ID comes from `X-Curse-Project-ID` in the TOC) |
| `GITHUB_TOKEN` | Provided automatically; creates the GitHub release |
| `WAGO_API_TOKEN` | Wago upload |
| `WOWI_API_TOKEN` | WoWInterface upload |

---

## Packaging notes

- `.pkgmeta` `externals` replaces the committed `Libs/` with fresh upstream
  checkouts at build time. The committed copies exist only so the addon loads
  from a local working directory — they are never what ships.
- `CHANGELOG.md` is deliberately not in the `ignore` list. The packager reads the
  manual changelog from the checkout, so the *upload* text would be correct
  either way, but an ignored file never reaches the package directory and the
  release zip would ship with no changelog at all. Do not re-add it to `ignore`.
- Releases through v1.1.2 predate the `manual-changelog` directive, so they
  shipped a packager-generated commit dump. That is expected, not a regression.
- The addon is single-flavor (retail only, one `## Interface` line), so
  `enable-toc-creation` is not needed.
