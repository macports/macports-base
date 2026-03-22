# AGENTS Instructions

These instructions apply to any automated coding agent working in this repository.

## Coding Standards
- Ensure that code you introduce builds on OS X 10.5+.
- Preserve existing code style and project conventions.
- Keep changes focused on the task at hand. Avoid unrelated refactors or cleanup unless the user asks for them.
- When you introduce a new feature or change user-visible behavior, update the relevant documentation in `./doc` and any other affected project documentation.
- In `./doc`, manpage content is generally maintained in `*.txt` AsciiDoc source files. Do not edit generated `*.xml`, `*.[157]`, `*.gz`, or `*.html` files directly unless the user explicitly asks. Some `*.[157]` files are alias stubs and should remain stubs.
- Add or update tests when test files for the affected modules already exist.
- Do not create entirely new test files unless the user has reviewed and approved that change.
- Add concise comments for newly introduced large or complex functions when the logic is not self-explanatory.

## Commits and Pull Requests
- If asked to create a commit, use a subject line formatted as `<component>: <description>`.
    - Examples:
        - `tests: fix rmrf helper to compile on OS X 10.5+`
        - `configure: add --with-git option`
- If the code is related to, fixes, or closes a MacPorts Trac issue, add `See:`, `Fixes:`, or `Closes:` entries as appropriate at the bottom of the commit message body.
