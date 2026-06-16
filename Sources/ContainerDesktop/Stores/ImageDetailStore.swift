import Foundation
import Observation

@MainActor
@Observable
final class ImageDetailStore {
    let reference: String
    private let client: ContainerCLIClient

    var selectedTab: ImageDetailTab = .layers
    var selectedVariantDigest: String?
    var inspectText = ""
    var inspectSearchText = ""
    var inspectError: String?

    init(reference: String, client: ContainerCLIClient = ContainerCLIClient()) {
        self.reference = reference
        self.client = client
    }

    func bootstrap(image: ImageSummary) async {
        selectInitialVariant(from: image)
        await refreshInspect()
    }

    func selectInitialVariant(from image: ImageSummary) {
        guard selectedVariantDigest == nil else { return }
        selectedVariantDigest = preferredVariant(in: image)?.digest ?? image.variants.first?.digest
    }

    func selectedVariant(in image: ImageSummary) -> ImageSummary.Variant? {
        if let selectedVariantDigest,
           let selected = image.variants.first(where: { $0.digest == selectedVariantDigest }) {
            return selected
        }
        return preferredVariant(in: image) ?? image.variants.first
    }

    func refreshInspect() async {
        inspectError = nil
        inspectText = "加载详情..."
        do {
            inspectText = try await client.inspectImage(reference).prettyString
        } catch {
            inspectError = error.localizedDescription
            inspectText = error.localizedDescription
        }
    }

    private func preferredVariant(in image: ImageSummary) -> ImageSummary.Variant? {
        image.variants.first {
            $0.platform.os == "linux" && $0.platform.architecture == hostArchitecture
        } ?? image.variants.first {
            $0.platform.os != "unknown" && $0.platform.architecture != "unknown"
        }
    }

    private var hostArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "amd64"
        #else
        return "unknown"
        #endif
    }
}
