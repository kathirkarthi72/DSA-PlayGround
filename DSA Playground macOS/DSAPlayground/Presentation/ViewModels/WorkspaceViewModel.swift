import Foundation
import SwiftUI
import Combine
import DSACore
import Observation

/// Compatibility alias — existing views/commands still reference `PlaygroundSession`.
typealias PlaygroundSession = WorkspaceViewModel

/// Main MVVM ViewModel for the playground workspace (Presentation layer).
@MainActor
@Observable
final class WorkspaceViewModel {
    let registry: DSAModuleRegistry
    let runner: SwiftPlaygroundRunner
    let intelligence: AppleIntelligenceGenerator

    private let documentStore: DocumentStoring
    private let runUseCase: RunPlaygroundUseCase
    private let askUseCase: AskIntelligenceUseCase
    private var cancellables = Set<AnyCancellable>()

    var selectedModuleID: String
    var diagnostics: [CodeDiagnostic] = []
    var selectedDiagnosticID: UUID?

    var animationSpeed: Double = 1.0
    // Cache for per-document visualizer states
    private var documentVisualizers: [UUID: VisualizerBox] = [:]
    private var documentEventHistories: [UUID: [DSAEvent]] = [:]
    private var documentStepIndices: [UUID: Int] = [:]
    private var documentCaptions: [UUID: String] = [:]
    private var documentHints: [UUID: String] = [:]
    private var documentRunningSourceLines: [UUID: Int?] = [:]

    var currentCaption: String {
        get { documentCaptions[activeDocumentID] ?? "" }
        set { documentCaptions[activeDocumentID] = newValue }
    }

    var currentHint: String {
        get { documentHints[activeDocumentID] ?? "Run code or use built-ins to see step-by-step hints." }
        set { documentHints[activeDocumentID] = newValue }
    }

    var visualizerBox: VisualizerBox {
        get {
            let docID = activeDocumentID
            if let cached = documentVisualizers[docID] {
                return cached
            }
            let viz = selectedModule.makeVisualizer()
            let box = VisualizerBox(visualizer: viz)
            documentVisualizers[docID] = box
            return box
        }
        set {
            documentVisualizers[activeDocumentID] = newValue
        }
    }
    var problemPrompt: String = ""
    var statusMessage: String = "Paste a problem, use built-in actions, or generate with Apple Intelligence."
    var autoRunAfterAdapt: Bool = true
    var useAICompletion: Bool = true
    var showLineNumbers: Bool = true
    var enableCodeFolding: Bool = true
    var showDiagnosticsPanel: Bool = true
    /// Editor monospace point size (persisted via App Settings).
    var editorFontSize: Double = 13
    /// Filters the interview question bank in the navigator.
    var questionBankQuery: String = ""

    var hoveredSourceLine: Int? = nil
    var selectedSourceLine: Int? = nil
    /// Line currently playing from a run (1-based).
    var runningSourceLine: Int? {
        get { documentRunningSourceLines[activeDocumentID] ?? nil }
        set { documentRunningSourceLines[activeDocumentID] = newValue }
    }
    /// Neighbors of the active canvas/run line — auto-updated with selection.
    var previousSourceLine: Int? = nil
    var nextSourceLine: Int? = nil

    /// Caret focus (1-based); follows canvas selection / running line.
    var focusedLine: Int = 1
    var focusedColumn: Int = 1
    var selectedText: String = ""

    /// Apple Intelligence conversation shown in the right panel.
    var aiMessages: [AIMessage] = []
    var conversationHasCode: Bool {
        aiMessages.contains { message in
            if let code = message.selectedCode, !code.isEmpty {
                return true
            }
            return message.content.contains("```")
        }
    }
    var aiDraftQuestion: String = ""
    /// Ask explains code; Agent generates Swift into the editor.
    var aiMode: AIAssistantMode = .ask

    /// Applied playback timeline (supports step back / jump-to-line).
    var eventHistory: [DSAEvent] {
        get { documentEventHistories[activeDocumentID] ?? [] }
        set { documentEventHistories[activeDocumentID] = newValue }
    }
    /// Index into `eventHistory` of the last applied event (`-1` = reset).
    var currentStepIndex: Int {
        get { documentStepIndices[activeDocumentID] ?? -1 }
        set { documentStepIndices[activeDocumentID] = newValue }
    }

    var eventQueue: [DSAEvent] = []
    private(set) var isPlaying = false
    private var playTask: Task<Void, Never>?
    private var builtInScript: String = ""
    private var suppressNextAdapt = false
    private var diagnosticsTask: Task<Void, Never>?
    /// Bumped so `@Observable` tracks document-store mutations.
    private(set) var workspaceRevision: Int = 0

    var selectedModule: any DSAModule {
        registry.module(id: selectedModuleID) ?? registry.modules[0]
    }

    private var currentWorkspace: ModuleWorkspace {
        get {
            _ = workspaceRevision
            return documentStore.ensureWorkspace(for: selectedModuleID, starterCode: selectedModule.starterCode)
        }
        set {
            documentStore.save(newValue)
            workspaceRevision &+= 1
        }
    }

    var documents: [EditorDocument] {
        get { currentWorkspace.documents }
        set {
            var ws = currentWorkspace
            ws.documents = newValue
            currentWorkspace = ws
        }
    }

    var activeDocumentID: UUID {
        get { currentWorkspace.activeDocumentID }
        set {
            var ws = currentWorkspace
            ws.activeDocumentID = newValue
            currentWorkspace = ws
        }
    }

    var activeDocumentIndex: Int? {
        documents.firstIndex(where: { $0.id == activeDocumentID })
    }

    var sourceCode: String {
        get { documents.first(where: { $0.id == activeDocumentID })?.content ?? "" }
        set {
            guard let index = activeDocumentIndex else { return }
            var docs = documents
            docs[index].content = newValue
            documents = docs
            scheduleDiagnostics()
        }
    }

    var activeSourceLine: Int? {
        hoveredSourceLine ?? selectedSourceLine ?? runningSourceLine
    }

    var activeLineContent: String? {
        guard let line = activeSourceLine else { return nil }
        let lines = sourceCode.components(separatedBy: .newlines)
        guard line > 0 && line <= lines.count else { return nil }
        let trimmed = lines[line - 1].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Line emphasized in the editor: canvas/diagnostic wins over caret.
    var editorHighlightedLine: Int? {
        activeSourceLine ?? focusedLine
    }

    /// Total lines in the active document (at least 1).
    private var sourceLineCount: Int {
        max(1, sourceCode.components(separatedBy: .newlines).count)
    }

    /// Keeps previous / next lines in sync with a canvas or run line.
    func syncSourceLineContext(around line: Int?, updateFocus: Bool = true) {
        guard let line, line > 0 else {
            previousSourceLine = nil
            nextSourceLine = nil
            return
        }
        let count = sourceLineCount
        let clamped = min(max(1, line), count)
        previousSourceLine = clamped > 1 ? clamped - 1 : nil
        nextSourceLine = clamped < count ? clamped + 1 : nil
        if updateFocus {
            focusedLine = clamped
        }
    }

    /// Pin a line from canvas click and refresh previous / next / caret.
    func selectCanvasSourceLine(_ line: Int?) {
        selectedSourceLine = line
        hoveredSourceLine = line
        syncSourceLineContext(around: line ?? runningSourceLine, updateFocus: true)
    }

    /// Update the running animation line and refresh previous / next / caret.
    func setRunningSourceLine(_ line: Int?) {
        runningSourceLine = line
        hoveredSourceLine = line
        syncSourceLineContext(around: line ?? selectedSourceLine, updateFocus: true)
    }

    /// Hover preview — updates context highlights without stealing the caret.
    func hoverCanvasSourceLine(_ line: Int?) {
        hoveredSourceLine = line
        syncSourceLineContext(
            around: line ?? selectedSourceLine ?? runningSourceLine,
            updateFocus: false
        )
    }

    var activeDiagnostics: [CodeDiagnostic] {
        diagnostics.filter { $0.documentID == activeDocumentID }
    }

    var selectedDiagnostic: CodeDiagnostic? {
        guard let selectedDiagnosticID else { return activeDiagnostics.first }
        return diagnostics.first(where: { $0.id == selectedDiagnosticID })
    }

    var navigatorRoots: [NavigatorNode] {
        _ = workspaceRevision
        return registry.modules.map { module in
            let ws = documentStore.ensureWorkspace(for: module.id, starterCode: module.starterCode)
            let files = ws.documents.map {
                NavigatorFile(
                    moduleID: module.id,
                    documentID: $0.id,
                    name: $0.name,
                    isEntrypoint: $0.isEntrypoint
                )
            }
            return .module(
                id: module.id,
                title: module.title,
                systemImage: module.systemImage,
                files: files
            )
        }
    }

    var selectedModuleFiles: [NavigatorFile] {
        _ = workspaceRevision
        let ws = documentStore.ensureWorkspace(for: selectedModuleID, starterCode: selectedModule.starterCode)
        return ws.documents.map {
            NavigatorFile(
                moduleID: selectedModuleID,
                documentID: $0.id,
                name: $0.name,
                isEntrypoint: $0.isEntrypoint
            )
        }
    }

    var filteredInterviewQuestions: [InterviewQuestion] {
        let all = selectedModule.interviewQuestions
        let query = questionBankQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { $0.searchText.contains(query) }
    }

    /// Question Bank row currently mirrored by the active editor tab, if any.
    var activeInterviewQuestionID: String? {
        guard let name = documents.first(where: { $0.id == activeDocumentID })?.name else { return nil }
        return selectedModule.interviewQuestions.first(where: {
            sanitizedQuestionFileName($0.title) == name
        })?.id
    }

    func interviewQuestion(id: String) -> InterviewQuestion? {
        selectedModule.interviewQuestions.first(where: { $0.id == id })
            ?? filteredInterviewQuestions.first(where: { $0.id == id })
    }

    var canStepBackward: Bool { currentStepIndex >= 0 }
    var canStepForward: Bool {
        currentStepIndex + 1 < eventHistory.count || !eventQueue.isEmpty
    }
    var playbackIterationLabel: String {
        guard !eventHistory.isEmpty else { return "No steps" }
        let current = max(0, currentStepIndex + 1)
        return "Step \(current) / \(eventHistory.count)"
    }
    var activeFlowEvent: DSAEvent? {
        guard currentStepIndex >= 0, currentStepIndex < eventHistory.count else { return nil }
        return eventHistory[currentStepIndex]
    }

    init(registry: DSAModuleRegistry) {
        self.registry = registry
        let documentStore = InMemoryDocumentStore()
        let runner = SwiftPlaygroundRunner()
        let intelligence = AppleIntelligenceGenerator()
        self.documentStore = documentStore
        self.runner = runner
        self.intelligence = intelligence
        self.runUseCase = RunPlaygroundUseCase(runner: runner)
        self.askUseCase = AskIntelligenceUseCase(intelligence: intelligence)

        let first = registry.modules[0]
        self.selectedModuleID = first.id
        _ = documentStore.ensureWorkspace(for: first.id, starterCode: first.starterCode)
        for module in registry.modules.dropFirst() {
            _ = documentStore.ensureWorkspace(for: module.id, starterCode: module.starterCode)
        }

        self.builtInScript = first.bootstrapCode
        let viz = first.makeVisualizer()
        self.visualizerBox = VisualizerBox(visualizer: viz)
        self.currentCaption = viz.caption
        scheduleDiagnostics()
        bindCombineStreams()
    }

    private func bindCombineStreams() {
        runner.consolePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChangeNotify()
            }
            .store(in: &cancellables)

        intelligence.isGeneratingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChangeNotify()
            }
            .store(in: &cancellables)
    }

    /// `@Observable` does not expose `objectWillChange`; bump a dummy for Combine-driven refresh.
    private var combineTick: Int = 0
    private func objectWillChangeNotify() {
        combineTick &+= 1
    }

    // MARK: - Navigator / modules

    func selectModule(id: String) {
        if id != selectedModuleID {
            questionBankQuery = ""
        }
        guard id != selectedModuleID, let module = registry.module(id: id) else { return }
        runner.stop()
        playTask?.cancel()
        eventQueue.removeAll()
        eventHistory.removeAll()
        currentStepIndex = -1
        isPlaying = false
        selectedModuleID = id
        _ = documentStore.ensureWorkspace(for: id, starterCode: module.starterCode)
        builtInScript = module.bootstrapCode
        let viz = module.makeVisualizer()
        visualizerBox = VisualizerBox(visualizer: viz)
        currentCaption = viz.caption
        currentHint = "Run code or use built-ins to see step-by-step hints."
        runningSourceLine = nil
        previousSourceLine = nil
        nextSourceLine = nil
        statusMessage = "Switched to \(module.title)."
        runner.objectWillChange.send()
        scheduleDiagnostics()
    }

    func openNavigatorFile(_ file: NavigatorFile) {
        if file.moduleID != selectedModuleID {
            selectModule(id: file.moduleID)
        }
        selectDocument(id: file.documentID)
    }

    func loadSample() {
        suppressNextAdapt = true
        replaceEntrypointContent(selectedModule.starterCode)
        builtInScript = selectedModule.bootstrapCode
        statusMessage = "Loaded sample for \(selectedModule.title)."
        scheduleDiagnostics()
    }

    func resetVisualization() {
        playTask?.cancel()
        eventQueue.removeAll()
        eventHistory.removeAll()
        currentStepIndex = -1
        isPlaying = false
        visualizerBox.visualizer.reset()
        currentCaption = visualizerBox.visualizer.caption
        currentHint = "Run code or use built-ins to see step-by-step hints."
        builtInScript = selectedModule.bootstrapCode
        hoveredSourceLine = nil
        selectedSourceLine = nil
        runningSourceLine = nil
        previousSourceLine = nil
        nextSourceLine = nil
    }

    // MARK: - Playback scrubbing

    func pausePlayback() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }

    func startPlayback() {
        playTask?.cancel()
        if currentStepIndex + 1 >= eventHistory.count && eventQueue.isEmpty {
            replayToStep(-1)
        }
        isPlaying = true
        playNext()
    }

    func stepBackward() {
        pausePlayback()
        guard currentStepIndex >= 0 else { return }
        replayToStep(currentStepIndex - 1)
        statusMessage = "Stepped back · \(playbackIterationLabel)"
    }

    func stepForward() {
        pausePlayback()
        if currentStepIndex + 1 < eventHistory.count {
            replayToStep(currentStepIndex + 1)
            statusMessage = "Stepped forward · \(playbackIterationLabel)"
        } else if !eventQueue.isEmpty {
            applyNextEvent(animated: true)
        }
    }

    /// Jump canvas to the previous distinct source line in the timeline.
    func jumpToPreviousLine() {
        pausePlayback()
        guard currentStepIndex > 0 else {
            replayToStep(-1)
            return
        }
        let currentLine = eventHistory[currentStepIndex].sourceLine
        var target = currentStepIndex - 1
        while target >= 0 {
            let line = eventHistory[target].sourceLine
            if let line, line != currentLine { break }
            target -= 1
        }
        replayToStep(target)
        statusMessage = "Jumped to previous line · \(playbackIterationLabel)"
    }

    /// Jump canvas to the next distinct source line in the timeline.
    func jumpToNextLine() {
        pausePlayback()
        guard currentStepIndex + 1 < eventHistory.count else {
            stepForward()
            return
        }
        let currentLine = eventHistory[currentStepIndex].sourceLine
        var target = currentStepIndex + 1
        while target < eventHistory.count {
            let line = eventHistory[target].sourceLine
            if let line, line != currentLine { break }
            target += 1
        }
        if target >= eventHistory.count { target = eventHistory.count - 1 }
        replayToStep(target)
        statusMessage = "Jumped to next line · \(playbackIterationLabel)"
    }

    /// Replay the canvas up through the last event at `line` (1-based).
    func jumpToSourceLine(_ line: Int) {
        pausePlayback()
        guard line > 0 else { return }
        if let idx = eventHistory.lastIndex(where: { $0.sourceLine == line }) {
            replayToStep(idx)
            statusMessage = "Canvas at line \(line) · \(playbackIterationLabel)"
            return
        }
        if let idx = eventHistory.lastIndex(where: {
            guard let source = $0.sourceLine else { return false }
            return source <= line
        }) {
            replayToStep(idx)
            statusMessage = "Canvas nearest line \(line) · \(playbackIterationLabel)"
            return
        }
        selectCanvasSourceLine(line)
        statusMessage = "No run event for line \(line) yet — run the playground first."
    }

    func jumpToStep(_ index: Int) {
        pausePlayback()
        replayToStep(index)
        statusMessage = "Flow jump · \(playbackIterationLabel)"
    }

    // MARK: - Editor caret / selection

    func updateCaret(line: Int, column: Int, selectedText: String) {
        focusedLine = max(1, line)
        focusedColumn = max(1, column)
        self.selectedText = selectedText
    }

    // MARK: - Run

    func run() {
        let adaptation = CodeAdapter.adapt(sourceCode, preferredModuleID: selectedModuleID)
        if adaptation.adaptedCode != sourceCode {
            suppressNextAdapt = true
            sourceCode = adaptation.adaptedCode
        }
        if let moduleID = adaptation.detectedModuleID, moduleID != selectedModuleID {
            selectModulePreservingCode(id: moduleID, code: sourceCode)
        }
        resetVisualization()
        let docs = documents
        let activeID = activeDocumentID
        let activeName = documents.first(where: { $0.id == activeID })?.name ?? "main.swift"
        statusMessage = "Running \(activeName)…"
        Task {
            await runUseCase.execute(
                documents: docs,
                activeDocumentID: activeID
            ) { [weak self] event in
                self?.enqueue(event)
            }
            if self.runner.state == .failed {
                self.ingestCompilerConsole()
            }
        }
    }

    func runSelection(_ selection: String? = nil) {
        let snippet = (selection ?? selectedText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snippet.isEmpty else {
            statusMessage = "Select some code first, then Run Selection."
            return
        }
        resetVisualization()
        let support = documents
        statusMessage = "Running selection…"
        Task {
            await runUseCase.executeSelection(
                selection: snippet,
                supportDocuments: support
            ) { [weak self] event in
                self?.enqueue(event)
            }
            if self.runner.state == .failed {
                self.ingestCompilerConsole()
            }
        }
    }

    func stop() {
        runner.stop()
        playTask?.cancel()
        eventQueue.removeAll()
        isPlaying = false
    }

    func handleEditorChange(from oldValue: String, to newValue: String) {
        scheduleDiagnostics()
        if suppressNextAdapt {
            suppressNextAdapt = false
            return
        }
        let grewALot = newValue.count > oldValue.count + 40
        let looksPasted = newValue.contains("func ") || newValue.contains("class ") || newValue.contains("struct ")
        guard grewALot || looksPasted else { return }
        adaptCurrentCode(autoRun: autoRunAfterAdapt)
    }

    func adaptCurrentCode(autoRun: Bool) {
        let adaptation = CodeAdapter.adapt(sourceCode, preferredModuleID: selectedModuleID)
        if let moduleID = adaptation.detectedModuleID, moduleID != selectedModuleID {
            selectModulePreservingCode(id: moduleID, code: adaptation.adaptedCode)
        } else if adaptation.adaptedCode != sourceCode {
            suppressNextAdapt = true
            sourceCode = adaptation.adaptedCode
        }

        if !adaptation.notes.isEmpty {
            statusMessage = adaptation.notes.joined(separator: " · ")
            runner.log("Adapted pasted code:\n- " + adaptation.notes.joined(separator: "\n- ") + "\n")
        } else {
            statusMessage = "Code ready to run."
        }

        if autoRun {
            run()
        }
    }

    func performBuiltIn(_ action: DSABuiltInAction) {
        if builtInScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            builtInScript = selectedModule.bootstrapCode
        }
        if !builtInScript.contains("Animated") {
            builtInScript = selectedModule.bootstrapCode + "\n" + builtInScript
        }
        builtInScript += "\n" + action.snippet
        suppressNextAdapt = true
        if let entry = documents.first(where: { $0.isEntrypoint }) {
            activeDocumentID = entry.id
        }
        sourceCode = builtInScript + "\n"
        statusMessage = "Built-in: \(action.title)"
        run()
    }

    /// Routes the right-panel composer to Ask or Agent based on `aiMode`.
    func submitAIAssistant() {
        switch aiMode {
        case .ask:
            askAppleIntelligence()
        case .agent:
            generateWithAppleIntelligence()
        }
    }

    func generateWithAppleIntelligence(prompt: String? = nil) {
        aiMode = .agent
        let text = (prompt ?? aiDraftQuestion).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "Describe what code to generate in Agent mode."
            return
        }
        problemPrompt = text
        aiDraftQuestion = ""
        let module = selectedModule
        let context = makeIntelligenceContext(existingSource: sourceCode)
        aiMessages.append(AIMessage(role: .user, content: text))
        statusMessage = "Agent generating Swift…"

        Task {
            if let code = await intelligence.generateSwiftSolution(
                prompt: text,
                context: context
            ) {
                suppressNextAdapt = true
                if let entry = documents.first(where: { $0.isEntrypoint }) {
                    activeDocumentID = entry.id
                }
                sourceCode = code
                builtInScript = module.bootstrapCode
                statusMessage = "Generated via \(intelligence.lastSource) (grounded on built-in \(module.title) APIs)"
                aiMessages.append(AIMessage(
                    role: .assistant,
                    content: "Generated Swift for \(module.title) using the playground’s built-in Animated* base (no duplicated DSAKit). Inserted into the active entry file — Canvas View updates when it runs."
                ))
                adaptCurrentCode(autoRun: true)
            } else {
                aiMessages.append(AIMessage(
                    role: .assistant,
                    content: "Couldn’t generate Swift for that prompt. Try a clearer DSA problem description."
                ))
                statusMessage = "Agent generation failed."
            }
        }
    }

    // MARK: - Ask AI about selection

    func askAppleIntelligence(question: String? = nil, code: String? = nil) {
        aiMode = .ask
        let selected = (code ?? selectedText).trimmingCharacters(in: .whitespacesAndNewlines)
        let q = (question ?? aiDraftQuestion).trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveQuestion = q.isEmpty
            ? "Explain this code using the built-in \(selectedModule.title) APIs — do not suggest reimplementing Animated* types."
            : q

        let userMessage = AIMessage(
            role: .user,
            content: effectiveQuestion,
            selectedCode: selected.isEmpty ? nil : selected
        )
        aiMessages.append(userMessage)
        aiDraftQuestion = ""
        statusMessage = "Asking Apple Intelligence…"

        let context = makeIntelligenceContext(existingSource: sourceCode)
        Task {
            let reply = await askUseCase.execute(
                question: effectiveQuestion,
                selectedCode: selected,
                context: context
            )
            aiMessages.append(reply)
            statusMessage = "Apple Intelligence replied."
        }
    }

    func makeIntelligenceContext(existingSource: String? = nil) -> DSAIntelligenceContext {
        DSAIntelligenceContextBuilder.make(
            module: selectedModule,
            existingSource: existingSource ?? sourceCode
        )
    }

    func clearAIConversation() {
        aiMessages.removeAll()
    }

    // MARK: - Tabs

    func selectDocument(id: UUID) {
        activeDocumentID = id
        selectedDiagnosticID = activeDiagnostics.first?.id
        scheduleDiagnostics()
    }

    func addDocument() {
        let count = documents.count + 1
        let doc = EditorDocument(name: "File\(count).swift", content: "// New playground file\n", isEntrypoint: false)
        var docs = documents
        docs.append(doc)
        documents = docs
        activeDocumentID = doc.id
        scheduleDiagnostics()
    }

    /// Opens an interview question as a new (or reused) editor tab.
    /// Running uses the active tab as `main.swift`, so demos with top-level statements work.
    func openInterviewQuestion(_ question: InterviewQuestion) {
        let fileName = sanitizedQuestionFileName(question.title)
        var ws = currentWorkspace
        if let existing = ws.documents.first(where: { $0.name == fileName }) {
            ws.activeDocumentID = existing.id
            currentWorkspace = ws
            statusMessage = "Opened \(question.title) — press Run to execute this tab"
            scheduleDiagnostics()
            return
        }
        let doc = EditorDocument(
            name: fileName,
            content: makeInterviewQuestionEditorContent(question),
            isEntrypoint: false
        )
        ws.documents.append(doc)
        ws.activeDocumentID = doc.id
        currentWorkspace = ws
        statusMessage = "Opened \(question.title) — press Run to execute this tab"
        scheduleDiagnostics()
    }

    private func makeInterviewQuestionEditorContent(_ question: InterviewQuestion) -> String {
        let descriptionLines = question.description
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "// \($0)" }
            .joined(separator: "\n")
        let approachLines = question.approach
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "// \($0)" }
            .joined(separator: "\n")
        return """
        // \(question.title) · \(question.difficulty)
        //
        // Description:
        \(descriptionLines)
        //
        // Approach:
        \(approachLines)
        //
        // Tags: \(question.tags.joined(separator: ", "))
        // Tip: With this tab selected, Run compiles it as the program entry.
        // Source: QuestionBank/\(question.moduleID ?? selectedModuleID)/\(question.id).json

        \(question.swiftCode)
        """
    }

    private func sanitizedQuestionFileName(_ title: String) -> String {
        let cleaned = title
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : Character("-") }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = cleaned.isEmpty ? "Question" : cleaned
        return "\(base).swift"
    }

    func closeDocument(id: UUID) {
        guard documents.count > 1,
              let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeDocumentID == id
        var docs = documents
        let removed = docs.remove(at: index)
        if removed.isEntrypoint, let first = docs.first {
            docs[0].isEntrypoint = true
            docs[0].name = "main.swift"
        }
        documents = docs
        if wasActive {
            activeDocumentID = documents[min(index, documents.count - 1)].id
        }
        var ws = currentWorkspace
        ws.foldedRegions[id] = nil
        currentWorkspace = ws
        scheduleDiagnostics()
    }

    func renameActiveDocument(to name: String) {
        guard let index = activeDocumentIndex else { return }
        var clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasSuffix(".swift") { clean += ".swift" }
        var docs = documents
        if docs[index].isEntrypoint {
            docs[index].name = "main.swift"
        } else {
            docs[index].name = clean
        }
        documents = docs
    }

    // MARK: - Diagnostics

    func scheduleDiagnostics() {
        diagnosticsTask?.cancel()
        diagnosticsTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            self.refreshDiagnostics()
        }
    }

    func refreshDiagnostics() {
        guard let doc = documents.first(where: { $0.id == activeDocumentID }) else {
            diagnostics = []
            return
        }
        var all: [CodeDiagnostic] = DiagnosticsEngine.analyze(document: doc, allDocuments: documents)
        if !doc.isEntrypoint, let entry = documents.first(where: { $0.isEntrypoint }) {
            all.append(contentsOf: DiagnosticsEngine.analyze(document: entry, allDocuments: documents).prefix(3))
        }
        diagnostics = all
        if selectedDiagnosticID == nil || !diagnostics.contains(where: { $0.id == selectedDiagnosticID }) {
            selectedDiagnosticID = diagnostics.first?.id
        }
    }

    func acceptFix(for diagnostic: CodeDiagnostic) {
        guard let index = documents.firstIndex(where: { $0.id == diagnostic.documentID }),
              let fixed = DiagnosticsEngine.applyFix(diagnostic, to: documents[index].content) else {
            statusMessage = "No automatic fix available for this issue."
            return
        }
        var docs = documents
        docs[index].content = fixed
        documents = docs
        activeDocumentID = diagnostic.documentID
        statusMessage = "Applied fix: \(diagnostic.suggestion)"
        scheduleDiagnostics()
    }

    func acceptSelectedFix() {
        guard let diagnostic = selectedDiagnostic else { return }
        acceptFix(for: diagnostic)
    }

    // MARK: - Folding

    func foldableLines(in content: String) -> Set<Int> {
        guard enableCodeFolding else { return [] }
        var result = Set<Int>()
        let lines = content.components(separatedBy: .newlines)
        for (idx, line) in lines.enumerated() where line.contains("{") && !line.contains("}") {
            result.insert(idx + 1)
        }
        return result
    }

    func foldedStartLines(for documentID: UUID) -> Set<Int> {
        Set((currentWorkspace.foldedRegions[documentID] ?? []).map(\.startLine))
    }

    func toggleFold(at line: Int) {
        guard enableCodeFolding, let index = activeDocumentIndex else { return }
        let docID = documents[index].id
        var ws = currentWorkspace
        var regions = ws.foldedRegions[docID] ?? []

        if let existing = regions.first(where: { $0.startLine == line }) {
            var content = documents[index].content
            let lines = content.components(separatedBy: .newlines)
            if lines.indices.contains(line - 1),
               lines[line - 1].contains("/* folded") {
                var newLines = lines
                newLines.remove(at: line - 1)
                let restored = existing.foldedContent.components(separatedBy: .newlines)
                newLines.insert(contentsOf: restored, at: line - 1)
                var docs = documents
                docs[index].content = newLines.joined(separator: "\n")
                documents = docs
            }
            regions.removeAll { $0.startLine == line }
            ws.foldedRegions[docID] = regions
            currentWorkspace = ws
        } else {
            guard let endLine = braceBlockEndLine(in: documents[index].content, startingAtLine: line) else { return }
            var lines = documents[index].content.components(separatedBy: .newlines)
            let start = line - 1
            let end = endLine - 1
            guard lines.indices.contains(start), lines.indices.contains(end), end >= start else { return }
            let foldedContent = lines[start...end].joined(separator: "\n")
            let openIndent = String(lines[start].prefix(while: { $0 == " " || $0 == "\t" }))
            let placeholder = "\(openIndent){ /* folded \(end - start) lines */ }"
            lines.removeSubrange(start...end)
            lines.insert(placeholder, at: start)
            var docs = documents
            docs[index].content = lines.joined(separator: "\n")
            documents = docs
            regions.append(FoldRegion(
                startLine: line,
                endLine: endLine,
                placeholder: placeholder,
                foldedContent: foldedContent
            ))
            ws.foldedRegions[docID] = regions
            currentWorkspace = ws
        }
        scheduleDiagnostics()
    }

    private func braceBlockEndLine(in content: String, startingAtLine line: Int) -> Int? {
        let lines = content.components(separatedBy: .newlines)
        guard lines.indices.contains(line - 1) else { return nil }
        var depth = 0
        var started = false
        for idx in (line - 1)..<lines.count {
            for ch in lines[idx] {
                if ch == "{" {
                    depth += 1
                    started = true
                } else if ch == "}" {
                    depth -= 1
                    if started && depth == 0 {
                        return idx + 1
                    }
                }
            }
        }
        return nil
    }

    private func replaceEntrypointContent(_ content: String) {
        var docs = documents
        if let index = docs.firstIndex(where: { $0.isEntrypoint }) {
            docs[index].content = content
            documents = docs
            activeDocumentID = docs[index].id
        } else {
            let main = EditorDocument(name: "main.swift", content: content, isEntrypoint: true)
            docs.insert(main, at: 0)
            documents = docs
            activeDocumentID = main.id
        }
    }

    private func selectModulePreservingCode(id: String, code: String) {
        guard let module = registry.module(id: id) else { return }
        runner.stop()
        playTask?.cancel()
        eventQueue.removeAll()
        isPlaying = false
        selectedModuleID = id
        _ = documentStore.ensureWorkspace(for: id, starterCode: module.starterCode)
        suppressNextAdapt = true
        replaceEntrypointContent(code)
        builtInScript = module.bootstrapCode
        let viz = module.makeVisualizer()
        visualizerBox = VisualizerBox(visualizer: viz)
        currentCaption = viz.caption
    }

    private func ingestCompilerConsole() {
        guard let entry = documents.first(where: { $0.isEntrypoint }) else { return }
        let parsed = DiagnosticsEngine.parseCompilerOutput(runner.consoleOutput, documentID: entry.id)
        if !parsed.isEmpty {
            diagnostics = parsed + diagnostics.filter { diag in
                !parsed.contains(where: { $0.line == diag.line && $0.message == diag.message })
            }
            selectedDiagnosticID = diagnostics.first?.id
        }
    }

    private func enqueue(_ event: DSAEvent) {
        eventQueue.append(event)
        if !isPlaying {
            isPlaying = true
            playNext()
        }
    }

    private func playNext() {
        guard isPlaying else { return }
        let delay = max(0.14, 0.62 / animationSpeed)
        
        if currentStepIndex + 1 < eventHistory.count {
            replayToStep(currentStepIndex + 1)
            statusMessage = "Playing · \(playbackIterationLabel)"
            
            playTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.playNext()
            }
        } else if !eventQueue.isEmpty {
            applyNextEvent(animated: true)
            statusMessage = "Playing · \(playbackIterationLabel)"
            
            playTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.playNext()
            }
        } else {
            isPlaying = false
            statusMessage = "Playback finished · \(playbackIterationLabel)"
        }
    }

    private func applyNextEvent(animated: Bool) {
        guard !eventQueue.isEmpty else {
            isPlaying = false
            return
        }
        var event = eventQueue.removeFirst()
        if event.sourceLine == nil {
            event.sourceLine = SourceLineLocator.line(
                forValue: event.value,
                message: event.message,
                in: sourceCode
            )
        }
        // Drop any scrubbed-ahead future when live events resume from mid-timeline.
        if currentStepIndex + 1 < eventHistory.count {
            eventHistory.removeSubrange((currentStepIndex + 1)...)
        }
        eventHistory.append(event)
        currentStepIndex = eventHistory.count - 1
        let apply = {
            self.visualizerBox.visualizer.apply(event)
            self.currentCaption = event.caption
            self.currentHint = event.hint
            if let line = event.sourceLine {
                self.setRunningSourceLine(line)
            }
        }
        if animated {
            withAnimation(PlaygroundTheme.springBouncy, apply)
        } else {
            apply()
        }
    }

    private func replayToStep(_ index: Int) {
        visualizerBox.visualizer.reset()
        currentCaption = visualizerBox.visualizer.caption
        currentHint = "Run code or use built-ins to see step-by-step hints."
        currentStepIndex = -1
        runningSourceLine = nil
        previousSourceLine = nil
        nextSourceLine = nil

        let end = min(index, eventHistory.count - 1)
        guard end >= 0 else { return }

        for i in 0...end {
            let event = eventHistory[i]
            visualizerBox.visualizer.apply(event)
            currentCaption = event.caption
            currentHint = event.hint
            if let line = event.sourceLine {
                setRunningSourceLine(line)
            }
            currentStepIndex = i
        }
    }
}

@MainActor
final class VisualizerBox: ObservableObject {
    let visualizer: any DSAVisualizer

    init(visualizer: any DSAVisualizer) {
        self.visualizer = visualizer
    }
}

struct VisualizerHostView: View {
    @ObservedObject var box: VisualizerBox
    @Bindable var session: WorkspaceViewModel

    var body: some View {
        AnyView(box.visualizer.makeView())
            .environment(
                \.hoverSourceLine,
                Binding(
                    get: { session.hoveredSourceLine },
                    set: { session.hoverCanvasSourceLine($0) }
                )
            )
            .environment(
                \.selectedSourceLine,
                Binding(
                    get: { session.selectedSourceLine },
                    set: { session.selectCanvasSourceLine($0) }
                )
            )
    }
}
