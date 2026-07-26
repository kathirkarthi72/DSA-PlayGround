import SwiftUI
import DSACore

struct VisualizerPaneView: View {
    @Bindable var session: PlaygroundSession
    @Bindable var layout: PanelLayoutState
    var onOpenWindow: (() -> Void)? = nil
    var onDock: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Canvas View")
                    .font(.headline)
                    .foregroundStyle(PlaygroundTheme.text)

                playbackControls

                Spacer()
                Text(session.selectedModule.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlaygroundTheme.accent)

                PaneHeaderControls(
                    isVisible: $layout.showVisualizer,
                    isAdjusting: $layout.adjustVisualizer,
                    onOpenWindow: onOpenWindow,
                    onDock: onDock,
                    isDetached: layout.visualizerDetached
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            if layout.adjustVisualizer {
                PaneAdjustHint(text: "Adjust: drag the center split to resize this pane · min width \(Int(layout.visualizerMinWidth))")
                HStack {
                    Text("Min width")
                        .font(.caption2)
                        .foregroundStyle(PlaygroundTheme.muted)
                    Slider(value: $layout.visualizerMinWidth, in: 260...800, step: 10)
                    Text("\(Int(layout.visualizerMinWidth))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(PlaygroundTheme.muted)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
            }

            VisualizerHostView(box: session.visualizerBox, session: session)
                .id(session.selectedModuleID)

            hintBar
        }
        .background(PlaygroundTheme.background.opacity(0.4))
    }

    private var playbackControls: some View {
        HStack(spacing: 4) {
            Button {
                session.jumpToPreviousLine()
            } label: {
                Image(systemName: "backward.end")
            }
            .buttonStyle(.borderless)
            .disabled(!session.canStepBackward)
            .help("Previous line — canvas runs up to that line")

            Button {
                session.stepBackward()
            } label: {
                Image(systemName: "backward.frame.fill")
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
                Image(systemName: "forward.frame.fill")
            }
            .buttonStyle(.borderless)
            .disabled(!session.canStepForward)
            .help("Next step")

            Button {
                session.jumpToNextLine()
            } label: {
                Image(systemName: "forward.end")
            }
            .buttonStyle(.borderless)
            .disabled(!session.canStepForward)
            .help("Next line")

            Text(session.playbackIterationLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(PlaygroundTheme.muted)
                .padding(.leading, 4)
        }
        .controlSize(.small)
    }

    private var hintBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.28))
                Text("Hint")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlaygroundTheme.muted)
                if let line = session.runningSourceLine ?? session.activeSourceLine {
                    Text("· line \(line)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.28))
                }
                Spacer()
                if let line = session.runningSourceLine ?? session.activeSourceLine,
                   let code = session.activeLineContent {
                    HStack(spacing: 6) {
                        Text(code)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(PlaygroundTheme.text.opacity(0.85))
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PlaygroundTheme.accent)
                        Text(session.currentCaption)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PlaygroundTheme.accent)
                            .lineLimit(1)
                    }
                } else {
                    Text(session.currentCaption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PlaygroundTheme.accent)
                        .lineLimit(1)
                }
            }
            Text(session.currentHint)
                .font(.system(size: 11))
                .foregroundStyle(PlaygroundTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(PlaygroundTheme.muted.opacity(0.2)).frame(height: 1)
        }
    }
}
