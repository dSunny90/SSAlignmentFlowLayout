# SSAlignmentFlowLayout

📊 A lightweight, flexible `UICollectionViewFlowLayout` subclass for easily aligning cells per section with optional row limits.

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/) ![Swift](https://img.shields.io/badge/Swift-5.7-orange.svg) ![Platform](https://img.shields.io/badge/platform-iOS%2012-brightgreen) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Features

- Configure a single alignment for all sections, or use closures for section-specific logic.
- Optionally limit the number of rows per section.
- Integrates seamlessly with Interface Builder or programmatically.

---

## Usage
```swift
// 1. Single static alignment for all sections
collectionView.collectionViewLayout = SSAlignmentFlowLayout(alignment: .left)

// 2. Dynamic alignment & row limit via closures (safe of retain cycles)
collectionView.collectionViewLayout = SSAlignmentFlowLayout(
    alignmentProvider: { [weak self] section in
        guard let self else { return .left }
        return self.alignment(for: section)
    },
    limitOfRowsProvider: { section in
        section == 0 ? 2 : 0
    }
)
```

---

## Installation

SSAlignmentFlowLayout is available via Swift Package Manager.

### Using Xcode:

1. Open your project in Xcode
2. Go to File > Add Packages…
3. Enter the URL:  
```
https://github.com/dSunny90/SSAlignmentFlowLayout
```
4. Select the version and finish

### Using Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/dSunny90/SSAlignmentFlowLayout", from: "1.0.0")
]
```
