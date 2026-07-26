import SwiftUI
import DSACore

/// Left of the console: iteration / algorithm flow from the playback timeline.
struct ExecutionFlowPanelView: View {
    @Bindable var session: WorkspaceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Flow")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlaygroundTheme.muted)
                Text(session.playbackIterationLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(PlaygroundTheme.accent)
                Spacer()
                Button {
                    session.jumpToPreviousLine()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!session.canStepBackward)
                .help("Previous source line")

                Button {
                    session.stepBackward()
                } label: {
                    Image(systemName: "backward.frame")
                }
                .buttonStyle(.borderless)
                .disabled(!session.canStepBackward)
                .help("Previous step")

                Button {
                    if session.isPlaying {
                        session.pausePlayback()
                    } else {
                        session.startPlayback()
                    }
                } label: {
                    Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(PlaygroundTheme.accent)
                }
                .buttonStyle(.borderless)
                .disabled(session.eventHistory.isEmpty && session.eventQueue.isEmpty)
                .help(session.isPlaying ? "Pause playback" : "Play/Resume playback")

                Button {
                    session.stepForward()
                } label: {
                    Image(systemName: "forward.frame")
                }
                .buttonStyle(.borderless)
                .disabled(!session.canStepForward)
                .help("Next step")

                Button {
                    session.jumpToNextLine()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!session.canStepForward)
                .help("Next source line")
            }

            if session.eventHistory.isEmpty {
                Text("Run the playground to see each iteration and what the code is doing.")
                    .font(.caption2)
                    .foregroundStyle(PlaygroundTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(session.eventHistory.enumerated()), id: \.element.id) { index, event in
                                flowRow(index: index, event: event)
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: session.currentStepIndex) { _, index in
                        guard index >= 0 else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
        .background(.ultraThinMaterial)
    }

    private func flowRow(index: Int, event: DSAEvent) -> some View {
        let selected = index == session.currentStepIndex
        return Button {
            session.jumpToStep(index)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(selected ? Color.black : PlaygroundTheme.muted)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(selected ? PlaygroundTheme.accent : PlaygroundTheme.muted.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(event.type.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PlaygroundTheme.text)
                        if let line = event.sourceLine {
                            Text("L\(line)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.28))
                        }
                    }
                    Text(event.caption)
                        .font(.system(size: 10))
                        .foregroundStyle(PlaygroundTheme.muted)
                        .lineLimit(2)
                    if selected {
                        Text(event.hint)
                            .font(.system(size: 10))
                            .foregroundStyle(PlaygroundTheme.text.opacity(0.85))
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? PlaygroundTheme.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? PlaygroundTheme.accent.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
