// swift-tools-version: 6.0
import PackageDescription

// Capas de la app:
// - AlbumRaterCore: modelos, validación y estado de pantalla. Sin dependencias; tests unitarios.
// - AlbumRaterData: acceso a Supabase. Tests de integración contra un Supabase local.
// Las vistas SwiftUI viven en el proyecto de Xcode y se prueban con tests de UI.
let package = Package(
    name: "AlbumRaterKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AlbumRaterCore", targets: ["AlbumRaterCore"]),
        .library(name: "AlbumRaterData", targets: ["AlbumRaterData"]),
    ],
    dependencies: [
        // Misma versión exacta que el proyecto de Xcode.
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.2"),
    ],
    targets: [
        .target(name: "AlbumRaterCore"),
        .target(
            name: "AlbumRaterData",
            dependencies: ["AlbumRaterCore", .product(name: "Supabase", package: "supabase-swift")]
        ),
        .testTarget(name: "AlbumRaterCoreTests", dependencies: ["AlbumRaterCore"]),
        .testTarget(
            name: "AlbumRaterDataTests",
            dependencies: ["AlbumRaterData", .product(name: "Supabase", package: "supabase-swift")]
        ),
    ]
)
