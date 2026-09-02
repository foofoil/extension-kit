# foofoil extension-kit

Reusable Extension API contracts for [foofoil](https://github.com/foofoil/foofoil).

This package is the independent source for Extension API v1: the stable C ABI, Manifest schema, capability identifiers, content-request and session value types, navigator and media contracts, compatibility fixtures, and contract tests. It is infrastructure for first-party foofoil extensions, not a user-facing app.

Host loading, installation, the Extension Registry client, and UI stay in foofoil. Capability extensions such as Hi-Fi live in their own repositories and are installed from inside foofoil.

## What This Package Provides

- `FoofoilExtensionABI` — versioned C function-table header (`foofoil_extension_create`)
- `FoofoilExtensionKit` — Swift value types and validators for Manifest, `ContentRequest`, `ContentSession`, capabilities, navigator contributions, and media playback snapshots
- Manifest JSON Schema and compatibility fixtures
- Contract tests for encoding, validation, and API negotiation

The long-term binary boundary is the C ABI and JSON value messages. Swift protocols, SwiftUI views, and in-process objects are not part of the public Extension API.

## Requirements

- macOS 15 or later
- Swift 6 / Xcode with the configured macOS SDK

## Use in an Extension

Add the package as a sibling checkout or a Git dependency:

```swift
dependencies: [
    .package(path: "../extension-kit")
    // or .package(url: "https://github.com/foofoil/extension-kit", from: "1.0.0")
]
```

Then declare `FoofoilExtensionKit` and/or `FoofoilExtensionABI` as target dependencies. Extensions may also speak only the C ABI and JSON messages, without importing the Swift module.

A `.foofoilextension` bundle looks like:

```text
Hi-Fi.foofoilextension
└── Contents
    ├── Info.plist
    ├── MacOS/
    │   └── <runtime>
    └── Resources
        └── ExtensionManifest.json
```

See the Manifest schema at `Sources/FoofoilExtensionKit/Resources/ExtensionManifest.schema.json`.

## Build and Test

```sh
swift test
```

## Related Repositories

| Repository | Role |
| --- | --- |
| [foofoil](https://github.com/foofoil/foofoil) | Lightweight macOS host app, Extension Manager, and built-in content providers |
| [hifi](https://github.com/foofoil/hifi) | Hi-Fi audio extension for foofoil |

[简体中文](README.zh-CN.md)

## License

extension-kit is licensed under the [MIT License](LICENSE), copyright © 2026 Beijing Memory Vision Technology Co., Ltd.
