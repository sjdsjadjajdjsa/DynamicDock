import SwiftUI

/// The song's lyrics. Synced lyrics keep the current line centred and
/// bright while the others fade back; unsynced lyrics are plain text the
/// user can scroll.
struct LyricsView: View {
    let lyrics: Lyrics
    let currentIndex: Int

    private static let fade: CGFloat = 0.16

    var body: some View {
        if DesignPreview.isSnapshot {
            // Scroll views cannot be drawn off screen, so snapshots show the
            // lines around the current one in a plain stack.
            VStack(alignment: .leading, spacing: 14) {
                ForEach(max(currentIndex - 1, 0)..<min(currentIndex + 4, lyrics.lines.count), id: \.self) { index in
                    line(index)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .clipped()
        } else {
            scrolling
        }
    }

    private var scrolling: some View {
        ScrollViewReader { reader in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: lyrics.isSynced ? 14 : 10) {
                    ForEach(lyrics.lines.indices, id: \.self) { index in
                        line(index)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // Room above and below, so the first and last lines can reach the centre.
                .padding(.vertical, lyrics.isSynced ? 90 : 24)
            }
            .scrollIndicators(.hidden)
            // Synced lyrics move on their own; unsynced ones are scrolled by hand.
            .scrollDisabled(lyrics.isSynced)
            .onAppear { scroll(reader, animated: false) }
            .onChange(of: currentIndex) { scroll(reader, animated: true) }
        }
        // Lines dissolve at the top and bottom instead of being cut off.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: Self.fade),
                    .init(color: .black, location: 1 - Self.fade),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func line(_ index: Int) -> some View {
        let text = Text(lyrics.lines[index].text)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

        if lyrics.isSynced {
            let isCurrent = index == currentIndex
            text
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.white.opacity(isCurrent ? 1 : (index < currentIndex ? 0.22 : 0.38)))
                .scaleEffect(isCurrent ? 1 : 0.94, anchor: .leading)
                .blur(radius: isCurrent ? 0 : 0.6)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentIndex)
        } else {
            text
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.78))
        }
    }

    private func scroll(_ reader: ScrollViewProxy, animated: Bool) {
        guard lyrics.isSynced else { return }
        let target = max(currentIndex, 0)
        // Before the first line the list rests at its top.
        let anchor: UnitPoint = currentIndex < 0 ? .top : .center
        if animated {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
                reader.scrollTo(target, anchor: anchor)
            }
        } else {
            reader.scrollTo(target, anchor: anchor)
        }
    }
}
