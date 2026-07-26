import SwiftUI
import DSACore

/// Persistent right-side Apple Intelligence chat (Ask / Agent).
struct AIAssistantPanelView: View {
    @Bindable var session: WorkspaceViewModel
    @Bindable var layout: PanelLayoutState
    @ObservedObject var intelligence: AppleIntelligenceGenerator

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            Divider()
            composer
        }
        .frame(minWidth: 260, idealWidth: max(layout.aiPanelWidth, 280), maxWidth: layout.adjustAIPanel ? 520 : 460)
        .background(.thinMaterial)
    }


    private var header: some View {
        HStack(spacing: 8) {
            Label("Apple Intelligence", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PlaygroundTheme.text)
            Spacer()
            if intelligence.isGenerating {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                session.clearAIConversation()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(PlaygroundTheme.muted)
            .help("Clear conversation")
            .disabled(session.aiMessages.isEmpty)

            PaneHeaderControls(
                isVisible: $layout.showAIPanel,
                isAdjusting: $layout.adjustAIPanel
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }



    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if session.aiMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(session.aiMessages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: session.aiMessages.count) { _, _ in
                if let last = session.aiMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.aiMode.emptyStateTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PlaygroundTheme.text)
            Text(session.aiMode.emptyStateDetail)
                .font(.caption)
                .foregroundStyle(PlaygroundTheme.muted)
            Text("Grounded on \(session.selectedModule.title) APIs, starters, and Question Bank.")
                .font(.caption)
                .foregroundStyle(PlaygroundTheme.muted)
            Text(intelligence.availabilityMessage)
                .font(.caption2)
                .foregroundStyle(PlaygroundTheme.accentSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func messageBubble(_ message: AIMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "You" : "Apple Intelligence")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(message.role == .user ? PlaygroundTheme.accent : PlaygroundTheme.accentSecondary)
            if let code = message.selectedCode, !code.isEmpty {
                Text(code)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(PlaygroundTheme.muted)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PlaygroundTheme.background.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(message.content)
                .font(.caption)
                .foregroundStyle(PlaygroundTheme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(message.role == .user ? PlaygroundTheme.background : PlaygroundTheme.background.opacity(0.55))
        )
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if layout.adjustAIPanel {
                HStack {
                    Text("Width")
                        .font(.caption2)
                        .foregroundStyle(PlaygroundTheme.muted)
                    Slider(value: $layout.aiPanelWidth, in: 260...520, step: 10)
                    Text("\(Int(layout.aiPanelWidth))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(PlaygroundTheme.muted)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            if !session.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 9))
                    Text("Code selection attached")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    Button {
                        session.selectedText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PlaygroundTheme.muted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(PlaygroundTheme.accent.opacity(0.12))
                .foregroundStyle(PlaygroundTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            TextField(
                composerPlaceholder,
                text: $session.aiDraftQuestion,
                axis: .vertical
            )
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .padding(8)
            .background(PlaygroundTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onSubmit {
                submit()
            }

            HStack {
                Menu {
                    Button {
                        session.aiMode = .ask
                        submit()
                    } label: {
                        Label("Ask (Explain)", systemImage: "questionmark.circle")
                    }
                    Button {
                        session.aiMode = .agent
                        submit()
                    } label: {
                        Label("Agent (Generate)", systemImage: "sparkles")
                    }
                } label: {
                    Label(session.aiMode == .ask ? "Ask" : "Agent", systemImage: session.aiMode == .ask ? "questionmark.circle" : "sparkles")
                } primaryAction: {
                    submit()
                }
                .menuStyle(.button)
                .buttonStyle(.borderedProminent)
                .tint(PlaygroundTheme.accent)
                .disabled(!canSubmit)

                Spacer()
                Text(session.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(PlaygroundTheme.muted)
                    .lineLimit(1)
            }
        }
        .padding(12)
    }

    private var composerPlaceholder: String {
        if session.aiMode == .ask, !session.selectedText.isEmpty {
            return "Ask about the selection…"
        }
        return session.aiMode.placeholder
    }

    private var canSubmit: Bool {
        guard !intelligence.isGenerating else { return false }
        if session.aiMode == .agent {
            return !session.aiDraftQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // Ask can run on selection alone with a default question.
        return true
    }

    private func submit() {
        layout.showAIPanel = true
        session.submitAIAssistant()
    }
}
