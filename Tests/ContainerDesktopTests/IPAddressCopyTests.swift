import Testing
@testable import ContainerDesktop

@Suite("IP address copy")
struct IPAddressCopyTests {
    @Test("normalizes display IP values for copy")
    func normalizesDisplayIPValuesForCopy() {
        #expect(IPAddressCopy.normalized("192.168.66.8") == "192.168.66.8")
        #expect(IPAddressCopy.normalized(" 192.168.66.8/24 ") == "192.168.66.8")
        #expect(IPAddressCopy.normalized("fd00::1") == "fd00::1")
        #expect(IPAddressCopy.normalized("fd00::1/64") == "fd00::1")
        #expect(IPAddressCopy.normalized("[fd00::1]") == "fd00::1")
        #expect(IPAddressCopy.normalized("[fd00::1]/64") == "fd00::1")
    }

    @Test("filters unavailable IP values")
    func filtersUnavailableIPValues() {
        #expect(IPAddressCopy.normalized(nil) == nil)
        #expect(IPAddressCopy.normalized("") == nil)
        #expect(IPAddressCopy.normalized("   ") == nil)
        #expect(IPAddressCopy.normalized("—") == nil)
        #expect(IPAddressCopy.normalized("n/a") == nil)
    }
}
