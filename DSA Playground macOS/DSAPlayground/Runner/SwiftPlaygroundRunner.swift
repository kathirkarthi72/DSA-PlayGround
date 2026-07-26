import Foundation
import Combine
import DSACore

@MainActor
final class SwiftPlaygroundRunner: ObservableObject, PlaygroundRunning {
    typealias State = PlaygroundRunState

    @Published private(set) var state: State = .idle
    @Published private(set) var consoleOutput: String = ""

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var eventHandler: ((DSAEvent) -> Void)?
    private var workDirectory: URL?

    var isBusy: Bool {
        state == .compiling || state == .running
    }

    var runState: PlaygroundRunState { state }

    var statePublisher: AnyPublisher<PlaygroundRunState, Never> {
        $state.eraseToAnyPublisher()
    }

    var consolePublisher: AnyPublisher<String, Never> {
        $consoleOutput.eraseToAnyPublisher()
    }

    func log(_ text: String) {
        appendConsole(text)
    }

    func run(source: String, onEvent: @escaping (DSAEvent) -> Void) async {
        await run(sources: [("main.swift", source)], onEvent: onEvent)
    }

    func run(sources: [(name: String, content: String)], onEvent: @escaping (DSAEvent) -> Void) async {
        stop()
        eventHandler = onEvent
        consoleOutput = ""
        state = .compiling

        do {
            let workDir = try prepareWorkDirectory(sources: sources)
            workDirectory = workDir
            let binaryURL = workDir.appendingPathComponent("playground")
            try await compile(workDir: workDir, output: binaryURL)
            appendConsole("Compiled successfully.\nRunning…\n")
            state = .running
            try await execute(binaryURL)
            if state == .running {
                state = .finished
                appendConsole("\nFinished.\n")
            }
        } catch {
            state = .failed
            appendConsole("\n\(error.localizedDescription)\n")
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        outputPipe = nil
        errorPipe = nil
        if state == .compiling || state == .running {
            state = .idle
            appendConsole("\nStopped.\n")
        }
        cleanupWorkDirectory()
    }

    private func prepareWorkDirectory(sources: [(name: String, content: String)]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DSAPlayground-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let kitSources = try resolveDSAKitSources()
        for file in kitSources {
            let destination = dir.appendingPathComponent(file.lastPathComponent)
            try FileManager.default.copyItem(at: file, to: destination)
        }

        var wroteMain = false
        for source in sources {
            let cleaned = sanitizeStudentSource(source.content)
            let fileName: String
            if source.name == "main.swift" || (!wroteMain && source.name.hasSuffix(".swift") && sources.count == 1) {
                fileName = "main.swift"
                wroteMain = true
            } else if source.name == "main.swift" {
                fileName = "main.swift"
                wroteMain = true
            } else {
                fileName = source.name.hasSuffix(".swift") ? source.name : source.name + ".swift"
            }
            let url = dir.appendingPathComponent(fileName)
            try cleaned.write(to: url, atomically: true, encoding: .utf8)
        }
        if !wroteMain {
            let fallback = sources.first.map { sanitizeStudentSource($0.content) } ?? "\n"
            try fallback.write(to: dir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        }
        return dir
    }

    private func sanitizeStudentSource(_ source: String) -> String {
        let lines = source
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("import DSAKit") { return false }
                return true
            }
        return lines.joined(separator: "\n") + "\n"
    }

    private func resolveDSAKitSources() throws -> [URL] {
        let fm = FileManager.default
        let required = [
            "EventEmitter.swift",
            "AnimatedArray.swift",
            "AnimatedBinaryTree.swift",
            "AnimatedHashTable.swift",
            "AnimatedHeap.swift",
            "AnimatedLinkedList.swift",
            "AnimatedQueue.swift",
            "AnimatedStack.swift"
        ]

        // Bundled flat in Resources/ (XcodeGen copy) or under DSAKitSources/
        if let resourceRoot = Bundle.main.resourceURL {
            let nested = required.compactMap { name -> URL? in
                let url = resourceRoot.appendingPathComponent("DSAKitSources").appendingPathComponent(name)
                return fm.fileExists(atPath: url.path) ? url : nil
            }
            if nested.count == required.count { return nested }

            let flat = required.compactMap { name -> URL? in
                let url = resourceRoot.appendingPathComponent(name)
                return fm.fileExists(atPath: url.path) ? url : nil
            }
            if flat.count == required.count { return flat }
        }

        let directoryCandidates: [URL] = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/DSAKitSources"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Packages/DSAKit/Sources/DSAKit")
        ]

        for directory in directoryCandidates {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue {
                let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "swift" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                if !files.isEmpty { return files }
            }
        }
        throw RunnerError.missingDSAKitSources
    }

    private func compile(workDir: URL, output: URL) async throws {
        let sources = try FileManager.default.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .map(\.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swiftc"] + sources + ["-o", output.path]
        process.currentDirectoryURL = workDir

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errText = String(data: errData, encoding: .utf8) ?? ""
        let outText = String(data: outData, encoding: .utf8) ?? ""
        if !outText.isEmpty { appendConsole(outText) }
        if !errText.isEmpty { appendConsole(errText) }

        guard process.terminationStatus == 0 else {
            throw RunnerError.compileFailed(errText.isEmpty ? "Compilation failed." : errText)
        }
    }

    private func execute(_ binaryURL: URL) async throws {
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = []

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        self.process = process
        self.outputPipe = stdout
        self.errorPipe = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                self?.consumeStdout(text)
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(data: data, encoding: .utf8) ?? ""
            Task { @MainActor in
                self?.appendConsole(text)
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus == 0 || proc.terminationReason == .exit {
                    continuation.resume()
                } else if proc.terminationReason == .uncaughtSignal {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RunnerError.runtimeFailed("Process exited with status \(proc.terminationStatus)"))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
        self.process = nil
        cleanupWorkDirectory()
    }

    private var stdoutBuffer = ""

    private func consumeStdout(_ chunk: String) {
        stdoutBuffer += chunk
        while let range = stdoutBuffer.range(of: "\n") {
            let line = String(stdoutBuffer[..<range.lowerBound])
            stdoutBuffer = String(stdoutBuffer[range.upperBound...])
            handleEventLine(line)
        }
    }

    private func handleEventLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = trimmed.data(using: .utf8) else { return }
        do {
            let decoded = try JSONDecoder().decode(PlaygroundEventDTO.self, from: data)
            let event = decoded.asDSAEvent()
            eventHandler?(event)
        } catch {
            appendConsole(trimmed + "\n")
        }
    }

    private func appendConsole(_ text: String) {
        consoleOutput += text
    }

    private func cleanupWorkDirectory() {
        if let workDirectory {
            try? FileManager.default.removeItem(at: workDirectory)
        }
        workDirectory = nil
    }
}

private struct PlaygroundEventDTO: Codable {
    var type: String
    var structure: String
    var index: Int?
    var value: String?
    var secondaryValue: String?
    var highlight: [Int]?
    var nodes: [String]?
    var message: String?
    var meta: [String: String]?
    var sourceLine: Int?

    func asDSAEvent() -> DSAEvent {
        DSAEvent(
            type: type,
            structure: structure,
            index: index,
            value: value,
            secondaryValue: secondaryValue,
            highlight: highlight ?? [],
            nodes: nodes,
            message: message,
            meta: meta,
            sourceLine: sourceLine
        )
    }
}

enum RunnerError: LocalizedError {
    case missingDSAKitSources
    case compileFailed(String)
    case runtimeFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingDSAKitSources:
            return "Could not find DSAKit sources to compile student code."
        case .compileFailed(let message):
            return "Compile error:\n\(message)"
        case .runtimeFailed(let message):
            return "Runtime error:\n\(message)"
        }
    }
}
