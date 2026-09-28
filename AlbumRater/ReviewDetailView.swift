import SwiftUI

struct ReviewDetailView: View {
    let sessionID: UUID
    let store: ReviewsStore
    @State private var editingTrack: SessionTrack?

    var body: some View {
        // Leemos la sesión del store en cada render: al guardar una nota, la media se recalcula sola.
        if let session = store.session(id: sessionID) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.albumTitle).font(.title2.bold())
                        Text(session.artistName).font(.headline).foregroundStyle(.secondary)
                        Text(session.createdAt, format: .dateTime.day().month(.wide).year())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    AverageSummary(session: session)
                }
                Section("Canciones") {
                    ForEach(session.tracks) { track in
                        Button { editingTrack = track } label: { TrackRow(track: track) }
                            .tint(.primary)
                    }
                }
            }
            .navigationTitle(session.albumTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingTrack) { track in
                TrackRatingView(track: track, sessionID: session.id, store: store)
            }
        } else {
            ContentUnavailableView("Este álbum ya no existe", systemImage: "opticaldisc")
        }
    }
}

private struct AverageSummary: View {
    let session: ListeningSession

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text("Media del álbum").font(.subheadline).foregroundStyle(.secondary)
                Text(session.ratedCount == 0
                     ? "Puntúa una canción para empezar"
                     : "\(session.ratedCount) de \(session.tracks.count) canciones puntuadas")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(session.formattedAverage ?? "–")
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.default, value: session.averageScore)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TrackRow: View {
    let track: SessionTrack

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(track.position)")
                .font(.body.monospacedDigit()).foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                if let comment = track.rating?.comment {
                    Text(comment).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if let score = track.rating?.score {
                Text(score.formatted).font(.headline.monospacedDigit())
            } else {
                Text("Sin nota").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para puntuar")
    }
}
