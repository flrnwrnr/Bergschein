# AGENTS.md

## Project overview

This is a native iOS app built with SwiftUI.

Use:
- Swift 6 (strict concurrency enabled)
- SwiftUI
- async/await
- SwiftData where applicable
- StoreKit 2 for purchases
- XCTest for unit tests

Do not introduce new dependencies unless explicitly requested.

## Project structure

A quick map so you don't have to search for it:
- `Views/` — SwiftUI views, UI only
- `ViewModels/` (or `Stores/`) — state and logic
- `Services/` — networking, external APIs, and non-SwiftData persistence
- `Models/` — data structures and SwiftData `@Model` types

Adjust the paths above if they don't match reality, then follow the existing structure.

## Working style

Before making larger changes:
1. Inspect the relevant files.
2. Explain the intended approach briefly.
3. Make small, focused changes.
4. Keep diffs minimal.
5. Do not rewrite unrelated code.

Prefer incremental implementation over large rewrites.

## Architecture

Use:
- Views for UI only
- ViewModels or Stores for state and logic
- Services for networking, external APIs, and non-SwiftData persistence
- Models for data structures

Avoid business logic directly inside SwiftUI views.

For SwiftData specifically: the `ModelContext` lives in the SwiftUI environment, and `@Model` types are accessed from Views/ViewModels via `@Query` or the context — not wrapped behind a Service. Use Services only for persistence that is not SwiftData (e.g. file storage, remote sync).

## Swift style

- No force unwraps unless clearly safe and justified.
- Prefer `guard` for early exits.
- Prefer `let` over `var`.
- Use meaningful names.
- Keep functions small.
- Avoid overly clever code (no operator overloading for non-obvious semantics, no reflection-based magic).
- Use async/await instead of completion handlers.
- Mark UI updates on the MainActor where needed.

## Concurrency (Swift 6)

- Resolve actor-isolation and Sendable warnings properly. Do not silence them with `@unchecked Sendable` or `nonisolated(unsafe)`.
- Annotate UI-facing types and view models with `@MainActor`.
- Keep work off the main actor when it is not UI work.

## SwiftUI rules

- Keep views small and composable.
- Extract subviews when a body becomes too large.
- Avoid unnecessary `AnyView`.
- Avoid heavy work inside `body`.
- Use existing design components before creating new ones.
- Support Dynamic Type where reasonable.
- Add accessibility labels for interactive elements.

## Localization

All user-facing strings must be localizable.

Do not hardcode visible text directly in views unless this project already uses that pattern.

## Testing

When changing logic:
- Add or update unit tests.
- Cover edge cases.
- Do not remove existing tests unless explicitly requested.

Verify that the project still builds:

```sh
xcodebuild build -scheme AppList -destination 'platform=iOS Simulator,name=iPhone 16'
```

Before considering work complete, run or suggest the tests:

```sh
xcodebuild test -scheme AppList -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Git and safety

- Do not commit unless explicitly asked.
- Do not change signing settings.
- Do not change bundle identifiers.
- Do not edit generated files.
- Do not touch secrets, API keys, provisioning profiles, or certificates.
- Do not modify project files (`*.pbxproj`, `*.xcconfig`, `*.entitlements`) unless explicitly asked.

## Final response

After changes, summarize:
- what changed
- which files changed
- any tests run
- any risks or follow-up work
