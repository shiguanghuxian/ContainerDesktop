import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Image models")
struct ImageModelsTests {
    @Test("decodes image variant history and rootfs")
    func decodesImageVariantHistoryAndRootFS() throws {
        let image = try decodeImage("""
        [
          {
            "configuration": {
              "name": "docker.io/library/ubuntu:24.04",
              "creationDate": "2026-05-20T01:37:34Z",
              "descriptor": {
                "digest": "sha256:index",
                "mediaType": "application/vnd.oci.image.index.v1+json",
                "size": 6688
              }
            },
            "variants": [
              {
                "digest": "sha256:manifest",
                "platform": {
                  "os": "linux",
                  "architecture": "arm64",
                  "variant": "v8"
                },
                "size": 28878899,
                "config": {
                  "architecture": "arm64",
                  "os": "linux",
                  "variant": "v8",
                  "created": "2026-05-20T01:37:34.836311553Z",
                  "history": [
                    {
                      "created": "2026-05-20T01:37:31.378100123Z",
                      "created_by": "/bin/sh -c #(nop)  ARG RELEASE",
                      "empty_layer": true
                    },
                    {
                      "created": "2026-05-20T01:37:34.484290887Z",
                      "created_by": "/bin/sh -c #(nop) ADD file:abc in / "
                    },
                    {
                      "created": "2026-05-20T01:37:34.836311553Z",
                      "created_by": "/bin/sh -c #(nop)  CMD [\\"/bin/bash\\"]",
                      "empty_layer": true
                    }
                  ],
                  "rootfs": {
                    "type": "layers",
                    "diff_ids": [
                      "sha256:rootfs-layer"
                    ]
                  }
                }
              }
            ]
          }
        ]
        """)

        let variant = try #require(image.variants.first)
        #expect(variant.platformText == "linux/arm64/v8")
        #expect(variant.size == 28_878_899)
        #expect(variant.config?.history?.count == 3)
        #expect(variant.config?.rootfs?.diffIDs == ["sha256:rootfs-layer"])
    }

    @Test("maps non-empty history entries to diff ids")
    func mapsNonEmptyHistoryEntriesToDiffIDs() throws {
        let image = try decodeImage("""
        [
          {
            "configuration": {
              "name": "local/test:latest",
              "descriptor": {
                "digest": "sha256:index"
              }
            },
            "variants": [
              {
                "digest": "sha256:manifest",
                "platform": {
                  "os": "linux",
                  "architecture": "arm64"
                },
                "size": 100,
                "config": {
                  "history": [
                    {
                      "created_by": "/bin/sh -c #(nop)  ARG RELEASE",
                      "empty_layer": true
                    },
                    {
                      "created_by": "RUN /bin/sh -c apt-get update # buildkit"
                    },
                    {
                      "created_by": "COPY file /file # buildkit"
                    },
                    {
                      "created_by": "CMD [\\"/bin/sh\\"]",
                      "empty_layer": true
                    }
                  ],
                  "rootfs": {
                    "diff_ids": [
                      "sha256:first",
                      "sha256:second"
                    ]
                  }
                }
              }
            ]
          }
        ]
        """)

        let layers = try #require(image.variants.first?.layers)
        #expect(layers.map(\.diffID) == [nil, "sha256:first", "sha256:second", nil])
        #expect(layers[0].displayInstruction == "ARG RELEASE")
        #expect(layers[1].displayInstruction == "RUN /bin/sh -c apt-get update")
        #expect(layers[2].displayInstruction == "COPY file /file")
    }

    @Test("tolerates fewer diff ids than history entries")
    func toleratesFewerDiffIDsThanHistoryEntries() throws {
        let image = try decodeImage("""
        [
          {
            "configuration": {
              "name": "local/test:latest",
              "descriptor": {
                "digest": "sha256:index"
              }
            },
            "variants": [
              {
                "digest": "sha256:manifest",
                "platform": {
                  "os": "linux",
                  "architecture": "arm64"
                },
                "size": 100,
                "config": {
                  "history": [
                    {
                      "created_by": "RUN one"
                    },
                    {
                      "created_by": "RUN two"
                    }
                  ],
                  "rootfs": {
                    "diff_ids": [
                      "sha256:first"
                    ]
                  }
                }
              }
            ]
          }
        ]
        """)

        let layers = try #require(image.variants.first?.layers)
        #expect(layers.count == 2)
        #expect(layers[0].diffID == "sha256:first")
        #expect(layers[1].diffID == nil)
    }

    private func decodeImage(_ json: String) throws -> ImageSummary {
        let images = try JSONDecoder.containerDesktop.decode([ImageSummary].self, from: Data(json.utf8))
        return try #require(images.first)
    }
}
