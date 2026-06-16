import SwiftUI

struct ResourceToolbar<Actions: View>: View {
    @Binding var searchText: String
    var placeholder: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .frame(maxWidth: 360)
            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.separator)
            }

            Spacer()
            actions
        }
        .padding(.vertical, 6)
    }
}

struct ResourceTable<Header: View, Rows: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var rows: Rows

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(CDTheme.tableHeaderSurface)

            Divider()
            rows
        }
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

struct ResourceTableHeaderLabel: View {
    var title: String
    var width: CGFloat?
    var alignment: Alignment = .leading

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }
}

struct ResourceTableRow<Content: View>: View {
    var isSelected = false
    @ViewBuilder var content: Content
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(rowBackground)
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }

            Divider()
                .padding(.leading, 14)
        }
    }

    private var rowBackground: Color {
        if isSelected { return CDTheme.selectionSurface }
        if isHovering { return CDTheme.hoverSurface }
        return .clear
    }
}

struct ResourceStatusDot: View {
    var tint: Color
    var isHollow = false

    var body: some View {
        Image(systemName: isHollow ? "circle" : "circle.fill")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 20)
    }
}

struct RowActionButton: View {
    var systemImage: String
    var tint: Color = CDTheme.dockerBlue
    var isLoading = false
    var isDisabled = false
    var help: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDisabled ? .secondary : tint)
                        .frame(width: 28, height: 28)
                }
            }
            .background((isDisabled ? Color.secondary : tint).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .help(help ?? "")
    }
}

struct DestructiveRowActionButton: View {
    var systemImage: String = "trash"
    var isLoading = false
    var isDisabled = false
    var help: String?
    var action: () -> Void

    var body: some View {
        RowActionButton(
            systemImage: systemImage,
            tint: .red,
            isLoading: isLoading,
            isDisabled: isDisabled,
            help: help,
            action: action
        )
    }
}
