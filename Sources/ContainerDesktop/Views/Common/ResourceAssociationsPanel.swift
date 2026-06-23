import AppKit
import SwiftUI

struct ResourceAssociationsPanel: View {
    @Environment(\.appLanguage) private var language
    var sections: [ResourceAssociationSection]
    var onRoute: (AppResourceRoute) -> Void = { _ in }

    var body: some View {
        if !sections.isEmpty {
            PanelView(
                title: language.resolved == .zhHans ? "关联与快捷操作" : "Related Resources",
                subtitle: language.resolved == .zhHans ? "当前上下文里的资源、命令和复制入口" : "Resources, commands, and copy actions for this context",
                systemImage: "link"
            ) {
                VStack(spacing: 10) {
                    ForEach(portSections) { section in
                        portAssociationSection(section)
                    }

                    if !standardSections.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                            ForEach(standardSections) { section in
                                associationSection(section)
                            }
                        }
                    }
                }
            }
        }
    }

    private var portSections: [ResourceAssociationSection] {
        sections.filter { $0.id == "ports" }
    }

    private var standardSections: [ResourceAssociationSection] {
        sections.filter { $0.id != "ports" }
    }

    private func associationSection(_ section: ResourceAssociationSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(section.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 6) {
                ForEach(section.items.prefix(5)) { item in
                    associationItem(item)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
            .strokeBorder(CDTheme.separator)
        }
    }

    private func portAssociationSection(_ section: ResourceAssociationSection) -> some View {
        HStack(alignment: .center, spacing: 12) {
            associationHeader(section)
                .frame(minWidth: 140, idealWidth: 160, maxWidth: 180, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(section.items) { item in
                        portAssociationItem(item)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func associationItem(_ item: ResourceAssociationItem) -> some View {
        Button {
            perform(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if item.action != nil {
                    Image(systemName: actionIcon(for: item))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
        .help(item.subtitle)
    }

    private func portAssociationItem(_ item: ResourceAssociationItem) -> some View {
        Button {
            perform(item)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 15)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if item.action != nil {
                    Image(systemName: actionIcon(for: item))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(width: 172, height: 38)
            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
        .help(item.subtitle)
    }

    private func associationHeader(_ section: ResourceAssociationSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(section.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(section.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private func actionIcon(for item: ResourceAssociationItem) -> String {
        switch item.action {
        case .route:
            "arrow.right"
        case .copy:
            "doc.on.doc"
        case nil:
            "info.circle"
        }
    }

    private func perform(_ item: ResourceAssociationItem) {
        switch item.action {
        case .route(let route):
            onRoute(route)
        case .copy(let value):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        case nil:
            break
        }
    }
}
