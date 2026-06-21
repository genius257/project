# Project

Portable Windows dev-tool bundle. Provides PHP, Node.js, and (later) other
developer tools from a single self-contained directory — no system install,
no admin rights, no permanent PATH changes. Runs from `cmd.exe` with `curl`
as the only external dependency.

## Entry points

- `init.bat` / `init.sh` — open a new shell with `tools\` prepended to PATH
  for the session, exposing the wrappers in `tools\`. The `.sh` works in
  Git Bash; `source init.sh` to update the current bash, `./init.sh` to
  spawn a new interactive bash.
- `setup.bat` / `setup.sh` — interactive menu that installs tools by
  dispatching to `setup\<tool>.bat`. The `.sh` is a thin shim that runs the
  `.bat` under `cmd //c`; install logic lives in one place (the `.bat`).

## Layout

- `bin\` — vendored binaries used by both setup and runtime (`7zr.exe`,
  `7za.exe`).
- `downloads\` — cache of release archives; re-used across reinstalls.
- `setup\` — per-tool installers (`php.bat`, `node.bat`, `phpactor.bat`,
  `composer.bat`) plus the extractor bootstrap (`setup_7z.bat`). Each has a
  `.sh` shim sibling that delegates to the `.bat` under `cmd //c`.
- `scripts\` — shared PowerShell helpers invoked by the installers:
  `write_active_wrapper.ps1` (writes the bare `tools\<tool>.bat` + extensionless
  `tools\<tool>` bash wrapper pointing at the chosen install) and
  `rebuild_version_tiers.ps1` (regenerates all tier wrappers). Single source
  of truth for wrapper templates — installers never inline them.
- `installs\<tool>\<install-name>\` — actual tool installs live here. Sibling
  of `tools\`, not nested inside it — bash command lookup uses exact names,
  so the bare `tools\php` wrapper file can't share a parent with a `php\`
  folder. Example: `installs\php\php-8.4.12-nts-Win32-vs17-x64\`,
  `installs\node\node-v22.5.1-win-x64\`, `installs\phpactor\2026.05.30.2\`.
- `tools\` — wrappers only. `tools\<tool>.bat` (cmd) + extensionless
  `tools\<tool>` (bash). Both reference `..\installs\<tool>\<install>`.
  Tier wrappers (`tools\php8.bat`, `tools\php8.4`, etc.) follow the same
  pairing rule. cmd finds the `.bat` via PATHEXT; bash finds the
  extensionless file by exact name.

Existing legacy installs under `tools\<tool>\<install>` are migrated to
`installs\<tool>\<install>` the first time you run that tool's
`setup\<tool>.bat`.

## Patterns

- **Sibling wrappers**: If a tool's install folder also contains sibling
  executables (e.g. `npm.exe`, `npx.exe` inside a Node.js install), generate
  wrappers for them by calling `write_active_wrapper.ps1` with the appropriate
  `-Tool` name and the same `-InstallName`. Do **not** inline custom wrapper
  output — the script is the single source of truth.

## Topic instructions

Detailed guidance lives in `.instructions/`. Load the file relevant to the
task at hand instead of reading everything up front:

- `.instructions/portability.md` — what is/isn't OK to depend on. Read this
  before touching any setup, bootstrap, or extraction code.
- `.instructions/architecture.md` — folder responsibilities and the contract
  between layers (`bin\` → `setup\` → `tools\` → wrappers).
- `.instructions/extractors.md` — `7zr.exe` vs `7za.exe`, the bootstrap chain,
  and which formats each handles.
- `.instructions/adding-a-tool.md` — recipe for adding a new tool installer,
  using `setup\php.bat` and `setup\node.bat` as references.
