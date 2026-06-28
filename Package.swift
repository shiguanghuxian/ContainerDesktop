// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ContainerDesktop",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "ContainerDesktop", targets: ["ContainerDesktop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
        .package(url: "https://github.com/mchakravarty/CodeEditorView.git", exact: "0.15.4"),
    ],
    targets: [
        .executableTarget(
            name: "ContainerDesktop",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "CodeEditorView", package: "CodeEditorView"),
                .product(name: "LanguageSupport", package: "CodeEditorView"),
            ],
            path: "Sources/ContainerDesktop"
        ),
        .testTarget(
            name: "ContainerDesktopTests",
            dependencies: [
                "ContainerDesktop",
                .product(name: "Yams", package: "Yams"),
                .product(name: "TOMLKit", package: "TOMLKit"),
            ],
            path: "Tests/ContainerDesktopTests"
        ),
    ]
)
