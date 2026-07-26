import SwiftUI
import DSACore

/// Sidebar: DSA picker on top, then Files + Interview Question Bank sections.
struct DSAFileNavigatorView: View {
    @Bindable var session: WorkspaceViewModel
    @Bindable var layout: PanelLayoutState

    var body: some View {
        VStack(spacing: 0) {
            header
            if layout.adjustSidebar {
                PaneAdjustHint(text: "Adjust: drag the NavigationSplitView divider to resize the sidebar")
            }

            Picker("DSA", selection: Binding(
                get: { session.selectedModuleID },
                set: { session.selectModule(id: $0) }
            )) {
                ForEach(session.registry.modules.map(\.id), id: \.self) { moduleID in
                    if let module = session.registry.module(id: moduleID) {
                        Label(module.title, systemImage: module.systemImage)
                            .tag(moduleID)
                    }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: Binding(
                get: { selectedNavigatorID },
                set: { handleSelection($0) }
            )) {
                Section("Files") {
                    ForEach(session.selectedModuleFiles) { file in
                        Label {
                            HStack(spacing: 6) {
                                SwiftFileIcon(size: 12)
                                Text(file.name)
                                    .font(.system(size: 12, weight: file.isEntrypoint ? .semibold : .regular))
                                if file.isEntrypoint {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(PlaygroundTheme.accentSecondary)
                                }
                            }
                        } icon: {
                            EmptyView()
                        }
                        .tag(fileTag(file))
                        .help(file.isEntrypoint ? "Entrypoint (main.swift)" : file.name)
                    }
                }

                Section("Question Bank") {
                    if session.filteredInterviewQuestions.isEmpty {
                        Text(session.questionBankQuery.isEmpty
                             ? "No questions for this DSA yet."
                             : "No matches.")
                            .font(.system(size: 11))
                            .foregroundStyle(PlaygroundTheme.muted)
                    } else {
                        ForEach(session.filteredInterviewQuestions) { question in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 6) {
                                    Text(question.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(PlaygroundTheme.text)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Text(question.difficulty)
                                        .font(.system(size: 9, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(difficultyColor(question.difficulty).opacity(0.18))
                                        .foregroundStyle(difficultyColor(question.difficulty))
                                        .clipShape(Capsule())
                                }
                                Text(question.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(PlaygroundTheme.muted)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !question.tags.isEmpty {
                                    Text(question.tags.joined(separator: " · "))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(PlaygroundTheme.accent.opacity(0.85))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                            .tag(questionTag(question))
                            .help(question.description)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            TextField("Search questions…", text: $session.questionBankQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .navigationSplitViewColumnWidth(
            min: 180,
            ideal: layout.sidebarWidth,
            max: layout.adjustSidebar ? 420 : 340
        )
    }

    private var header: some View {
        HStack {
            Text("EXPLORER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PlaygroundTheme.muted)
                .tracking(0.6)
            Spacer()
            PaneHeaderControls(
                isVisible: $layout.showSidebar,
                isAdjusting: $layout.adjustSidebar,
                showAdjust: true
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PlaygroundTheme.panel)
    }

    private var selectedNavigatorID: String? {
        if let questionID = session.activeInterviewQuestionID {
            return "question:\(questionID)"
        }
        return "file:\(session.selectedModuleID):\(session.activeDocumentID.uuidString)"
    }

    private func fileTag(_ file: NavigatorFile) -> String {
        "file:\(file.moduleID):\(file.documentID.uuidString)"
    }

    private func questionTag(_ question: InterviewQuestion) -> String {
        "question:\(question.id)"
    }

    private func handleSelection(_ tag: String?) {
        guard let tag else { return }
        if tag.hasPrefix("question:") {
            let questionID = String(tag.dropFirst("question:".count))
            guard let question = session.interviewQuestion(id: questionID) else { return }
            session.openInterviewQuestion(question)
            return
        }
        guard tag.hasPrefix("file:") else { return }
        let parts = tag.split(separator: ":")
        guard parts.count >= 3,
              let documentID = UUID(uuidString: String(parts[2])) else { return }
        let moduleID = String(parts[1])
        session.openNavigatorFile(
            NavigatorFile(
                moduleID: moduleID,
                documentID: documentID,
                name: "",
                isEntrypoint: false
            )
        )
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return Color(red: 0.25, green: 0.72, blue: 0.45)
        case "hard": return Color(red: 0.90, green: 0.35, blue: 0.38)
        default: return Color(red: 0.95, green: 0.62, blue: 0.28)
        }
    }
}
