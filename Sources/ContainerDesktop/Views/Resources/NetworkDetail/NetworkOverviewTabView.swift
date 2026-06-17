import SwiftUI

struct NetworkOverviewTabView: View {
    @Environment(\.appLanguage) private var language
    var network: NetworkSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailSection(title: language.resolved == .zhHans ? "网络" : "Network") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: network.name)
                    DetailInfoRow(title: language.t(.mode), value: network.configuration.mode)
                    DetailInfoRow(title: language.t(.plugin), value: network.configuration.plugin)
                    DetailInfoRow(title: language.t(.created), value: network.createdText)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "地址配置" : "Addressing") {
                DetailInfoCard {
                    DetailInfoRow(title: language.resolved == .zhHans ? "IPv4 状态" : "IPv4 status", value: network.status.ipv4Subnet, monospaced: true)
                    DetailInfoRow(title: language.resolved == .zhHans ? "IPv4 配置" : "IPv4 config", value: network.ipv4ConfigurationText, monospaced: true)
                    DetailInfoRow(title: "IPv6", value: network.ipv6ConfigurationText, monospaced: true)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "插件配置" : "Plugin Configuration") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.plugin), value: network.configuration.plugin)
                    DetailInfoRow(title: language.resolved == .zhHans ? "选项数量" : "Options", value: "\(network.configuration.options.count)")
                    DetailInfoRow(title: language.resolved == .zhHans ? "标签数量" : "Labels", value: "\(network.configuration.labels.count)")
                }
            }
        }
    }
}
