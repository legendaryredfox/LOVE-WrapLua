# ADR-001: Evaluate raylib4PlayStation as an alternative native layer

**Date:** 2026-09-27
**Status:** Decided: NO GO

---

## Context

LOVE-WrapLua targets four consoles: PSP, PS Vita (two runtimes: OneLua and
lpp-vita), and PS3. Each backend wraps its platform SDK in a `love.*` surface.
The question is whether to replace or augment those SDK wrappers with a raylib
backend, using `raylib4PlayStation` (Vita/PS4) and `nbe1233/raylib-ps3` (PS3 via
PSL1GHT+RSXGL).

The attraction is that raylib's module split (`rtextures`, `rshapes`, `rtext`,
`raudio`) maps cleanly onto `love.graphics`, and a single C layer could
consolidate the Vita and PS3 backends.

---

## Candidates reviewed

### raylib4PlayStation (Vita + PS4)

- Origin: `psp2dev/raylib4Vita`, then `frangar/fjtrujy`, eventually merged into
  `raylib4PlayStation/raylib4PlayStation` unifying Vita + PS4 on raylib 5.0.
- License: zlib.
- Maintained: active as of mid-2025.
- PSP support: none. raylib dropped PSP as a first-class target before 4.0.

### nbe1233/raylib-ps3 (PS3)

- Builds on PSL1GHT + RSXGL.
- Last substantive activity: 2022 (psxdev community wound down).
- Status: proof of concept, not a shipping baseline.

---

## Decision

**NO GO.** Do not add a raylib-backed backend.

### Reasons

1. **PSP is unsupported.** PSP is the highest-priority platform in this repo.
   raylib has no PSP target and will not gain one. A raylib backend would be
   dead weight on the platform that matters most.

2. **PS3 tiny3D is already bound in Lua.** The PS3 player exposes tiny3D as a
   `gfx` table of ~64 functions alongside the legacy globals the current backend
   uses. A first-class PS3 backend needs only a Lua wrapper, not new C. Adding
   a raylib layer would introduce a heavy C dependency to do what an already-
   present binding can do.

3. **raylib-ps3 is stale.** The PSL1GHT+RSXGL port is a 2022 proof of concept.
   Basing a backend on it trades tiny3D (actively maintained, already in the
   player) for an unmaintained dependency.

4. **Dependency cost is asymmetric.** raylib adds freetype2, OpenAL, GLFW
   (stubbed on console) and the full raylib source to the build. The native
   SDKs already ship those capabilities in the player binary. The net gain in
   functionality is zero; the maintenance surface grows.

5. **Module split is useful as a reference, not a dependency.** raylib's clean
   `rtextures`/`rshapes`/`rtext`/`raudio` boundary influenced the `core/`
   module split already completed. That value is captured without
   taking the dependency.

---

## Consequences

- The first-class PS3 backend proceeds with tiny3D + Mini2D. No C patches or new dependencies
  required.
- The Vita backends (OneLua, lpp-vita) continue on their respective SDKs.
- If PS4 ever enters scope, raylib4PlayStation can be re-evaluated then, in
  isolation from the existing four backends.
- This ADR was the last gate before the PS3 backend work began (it has since
  landed on tiny3D).
