# SkipSentry

This is a [Skip](https://skip.tools) Swift/Kotlin library project that
abstracts the
[Sentry iOS](https://docs.sentry.io/platforms/apple/guides/ios/usage/)
and
[Sentry Android](https://docs.sentry.io/platforms/android/usage/)
SDKs.

It is currently in a primitive state and needs contributions
to flesh out the capabilities.

## Setup

To include this framework in your project, add the following
dependency to your `Package.swift` file:

```swift
let package = Package(
    name: "my-package",
    products: [
        .library(name: "MyProduct", targets: ["MyTarget"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip-sentry.git", "0.0.0"..<"2.0.0"),
    ],
    targets: [
        .target(name: "MyTarget", dependencies: [
            .product(name: "SkipSentry", package: "skip-sentry")
        ])
    ]
)
```

## Configuration

### Android

Follow the guide at [https://docs.sentry.io/platforms/android/configuration/](https://docs.sentry.io/platforms/android/configuration/).

### iOS

Follow the guide at [https://docs.sentry.io/platforms/apple/configuration/](https://docs.sentry.io/platforms/apple/configuration/).

## Building

This project is a Swift Package Manager module that uses the
[Skip](https://skip.tools) plugin to transpile Swift into Kotlin.

Building the module requires that Skip be installed using
[Homebrew](https://brew.sh) with `brew install skiptools/skip/skip`.
This will also install the necessary build prerequisites:
Kotlin, Gradle, and the Android build tools.

## Testing

The module can be tested using the standard `swift test` command
or by running the test target for the macOS destination in Xcode,
which will run the Swift tests as well as the transpiled
Kotlin JUnit tests in the Robolectric Android simulation environment.

Parity testing can be performed with `skip test`,
which will output a table of the test results for both platforms.

## License

This software is licensed under the
[GNU Lesser General Public License v3.0](https://spdx.org/licenses/LGPL-3.0-only.html),
with a [linking exception](https://spdx.org/licenses/LGPL-3.0-linking-exception.html)
to clarify that distribution to restricted environments (e.g., app stores) is permitted.
