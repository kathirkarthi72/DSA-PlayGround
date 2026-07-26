# Design patterns

## MVVM (Model–View–ViewModel)

| Layer | Implementation |
|-------|----------------|
| Model | `EditorDocument`, `DSAEvent`, module packages, AI messages |
| ViewModel | `WorkspaceViewModel` (aliased as `PlaygroundSession`) |
| View | `ContentView`, `EditorPaneView`, `DSAFileNavigatorView`, `AIAssistantPanelView`, AppKit editor |

Views observe ViewModel state (`@Observable` / `@Bindable`). User actions call ViewModel methods (`run()`, `askAppleIntelligence()`, `openNavigatorFile()`). Views do not compile code or call Foundation Models.

## Clean Architecture

Dependency rule: **Presentation → Domain ← Data**.

- Domain defines protocols (`PlaygroundRunning`, `IntelligenceGenerating`, `DocumentStoring`).
- Data implements those ports.
- Use cases (`RunPlaygroundUseCase`, `AskIntelligenceUseCase`) orchestrate without knowing SwiftUI.

## Registry

`DSAModuleRegistry` holds pluggable `DSAModule` instances. The composition root registers Array, Linked List, Stack, Queue, Hash Table, Heap, and Tree. The navigator and toolbar read modules from the registry only.

## Adapter

`CodeAdapter` rewrites pasted student APIs (`Stack` → `AnimatedStack`, etc.) and can suggest a module switch. Keeps the playground tolerant of common problem-set code styles.

## Observer / reactive streams

- **Observation** (`@Observable`) for ViewModel UI state
- **Combine** publishers on the runner and AI generator for busy/console updates
- **SwiftUI environment** bindings (`hoverSourceLine`, `selectedSourceLine`) connect visualizer hover/click back to the editor highlight

## Actor isolation

`AppleIntelligenceActor` isolates AI work off the main actor. The MainActor `AppleIntelligenceGenerator` façade updates `@Published` status for the UI and implements `IntelligenceGenerating`.

## Facade

`WorkspaceViewModel` is a façade over document store, runner, diagnostics, AI use cases, and visualizer playback so menus and panes keep a single session object.

## Strategy (visualizers)

Each DSA module supplies its own `DSAVisualizer` strategy (`makeVisualizer()`). The host plays the same `DSAEvent` stream against whichever strategy is active.
