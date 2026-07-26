# Architecture

DSA Playground’s host app is organized with **Clean Architecture** boundaries and an **MVVM** presentation layer. DSA visualization modules remain isolated Swift packages under `Packages/`.

## Layer overview

```mermaid
flowchart TD
    subgraph App [App Layer - Composition Root]
        A[DSAPlaygroundApp]
        B[PanelLayoutState]
    end

    subgraph Presentation [Presentation Layer - MVVM]
        C[WorkspaceViewModel]
        D[ContentView / Editor]
        E[Navigator / AI Panel]
    end

    subgraph Domain [Domain Layer]
        F[RunPlaygroundUseCase]
        G[AskUseCase]
        H[Entities / Protocols]
    end

    subgraph Data [Data Layer]
        I[InMemoryDocumentStore]
        J[AppleIntelligenceActor]
        K[SwiftPlaygroundRunner]
        L[CodeAdapter]
        M[DiagnosticsEngine]
    end

    subgraph Packages [External Packages]
        N[DSACore]
        O[DSAKit]
        P[Structure Modules]
    end

    App -->|Wires dependencies| Presentation
    Presentation -->|Use Cases & Protocols| Domain
    Data -->|Implements Protocols| Domain
    Data --> Packages
```

## Domain

| Type | Role |
|------|------|
| `EditorDocument`, `CodeDiagnostic`, `FoldRegion`, `ModuleWorkspace` | Editor models |
| `AIMessage` | Chat turns for the right panel |
| `NavigatorNode` / `NavigatorFile` | Explorer tree |
| `PlaygroundRunState` | Compile/run lifecycle |
| `DocumentStoring`, `PlaygroundRunning`, `IntelligenceGenerating` | Ports |
| `RunPlaygroundUseCase` | Full-file and selection runs |
| `AskIntelligenceUseCase` | Selection Q&A |

Domain types are UI-agnostic. Use cases depend only on protocols.

## Data

| Type | Role |
|------|------|
| `InMemoryDocumentStore` | Per-DSA file workspaces (thread-safe) |
| `AppleIntelligenceActor` | Off-main-actor explain/answer work |
| `AppleIntelligenceGenerator` | MainActor façade + Combine publishers (`IntelligenceGenerating`) |
| `SwiftPlaygroundRunner` | `swiftc` + process I/O (`PlaygroundRunning`) |
| `CodeAdapter` | Paste → DSAKit adaptation |
| `DiagnosticsEngine` | Heuristic + compiler diagnostics |

### Actors

- **`AppleIntelligenceActor`** — Foundation Models / local tutor explanation without blocking the UI.
- Process compile/run remains coordinated on the main actor via `SwiftPlaygroundRunner`, with async `run` and pipe handlers hopping back to `@MainActor`.

### Combine

- `SwiftPlaygroundRunner.statePublisher` / `consolePublisher`
- `AppleIntelligenceGenerator.isGeneratingPublisher`

`WorkspaceViewModel` subscribes so status UI stays in sync with `@Observable` state.

## Presentation (MVVM)

| Piece | Role |
|-------|------|
| **Model** | Domain entities + DSA events from packages |
| **ViewModel** | `WorkspaceViewModel` (`typealias PlaygroundSession`) |
| **View** | SwiftUI panes + AppKit `CodeEditorView` / `PlaygroundTextView` |

Responsibilities of `WorkspaceViewModel`:

- Selected DSA module and per-module documents
- Editor caret / selection
- Run / stop / selection-run
- Diagnostics scheduling
- AI conversation (`aiMessages`)
- Visualizer event playback queue

Views bind with `@Bindable` / `@ObservedObject` and never talk to `swiftc` or Foundation Models directly.

## App composition root

`DSAPlaygroundApp` builds a `DSAModuleRegistry` (Array, Linked List, Stack, Queue, Hash Table, Heap, Tree), constructs `WorkspaceViewModel`, and owns `PanelLayoutState` for pane visibility and sizing.

## Runtime data flow

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Editor as Code Editor
    participant VM as WorkspaceViewModel
    participant UC as RunPlaygroundUseCase
    participant Runner as SwiftPlaygroundRunner
    participant Canvas as Canvas View
    participant AI as Apple Intelligence

    %% Compilation Flow
    User->>Editor: Edit Code / Press Run
    Editor->>VM: Update Source Code
    VM->>UC: Run Playground (Source)
    UC->>Runner: Compile & Execute
    Runner-->>VM: Diagnostics & Console Output
    VM-->>Editor: Display Problems / Console
    Runner->>Canvas: Stream DSAEvents (JSON)
    Canvas->>Editor: Highlight Active Line
    
    %% AI Flow
    User->>Editor: Select Code & Ask AI
    Editor->>VM: Pass Selection
    VM->>AI: AskIntelligenceUseCase
    AI-->>VM: Append AIMessage
    VM-->>User: Display AI Response
```

## Package boundary

Visualizer modules implement `DSAModule` / `DSAVisualizer` from **DSACore**. Student code links **DSAKit** sources copied into the temp compile directory. Adding a structure means a new package + registry entry — the host architecture does not change.
