import SwiftUI

/// `DisclosureGroup` drop-in where the WHOLE header row (chevron + label
/// + trailing space) is the tap target — not just the chevron.
/// Built from stock primitives: `Button` (.plain) + `Image(systemName:)` +
/// conditional content. Toggling is instant — no animation lag, no
/// `DisclosureGroup` internal layout machinery.
struct ClickRowDisclosure<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text(title).font(.headline)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            if isExpanded {
                content()
                    .padding(.top, 4)
            }
        }
    }
}
