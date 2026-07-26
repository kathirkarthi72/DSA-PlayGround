import Foundation

public struct AnimatedHashTable<Key: Hashable, Value> {
    private struct Entry {
        var key: Key
        var value: Value
    }

    private var buckets: [[Entry]]
    private let capacity: Int
    private let name: String

    public init(capacity: Int = 8, name: String? = nil, line: Int = #line) {
        self.capacity = max(2, capacity)
        self.buckets = Array(repeating: [], count: self.capacity)
        let actualName = name ?? "Table \(InstanceCounter.shared.nextIndex(for: "hashTable"))"
        self.name = actualName
        EventEmitter.emit(PlaygroundEvent(
            type: "reset",
            structure: "hashTable",
            nodes: Array(repeating: "·", count: self.capacity),
            message: "\(actualName) ready (capacity \(self.capacity))",
            meta: ["capacity": String(self.capacity), "name": actualName],
            sourceLine: line
        ))
    }

    private func bucketIndex(for key: Key) -> Int {
        var hasher = Hasher()
        hasher.combine(key)
        let hash = hasher.finalize()
        return abs(hash) % capacity
    }

    private func snapshotNodes() -> [String] {
        buckets.enumerated().map { index, bucket in
            if bucket.isEmpty { return "·" }
            return bucket.map { "\(EventEmitter.valueString($0.key)):\(EventEmitter.valueString($0.value))" }
                .joined(separator: ",")
        }
    }

    public mutating func put(_ key: Key, _ value: Value, line: Int = #line) {
        let index = bucketIndex(for: key)
        EventEmitter.emit(PlaygroundEvent(
            type: "probe",
            structure: "hashTable",
            index: index,
            value: EventEmitter.valueString(key),
            highlight: [index],
            nodes: snapshotNodes(),
            message: "\(name): Probe bucket \(index) for key \(EventEmitter.valueString(key))",
            meta: ["name": name],
            sourceLine: line
        ))

        if let existing = buckets[index].firstIndex(where: { $0.key == key }) {
            buckets[index][existing].value = value
        } else {
            buckets[index].append(Entry(key: key, value: value))
        }

        EventEmitter.emit(PlaygroundEvent(
            type: "put",
            structure: "hashTable",
            index: index,
            value: EventEmitter.valueString(key),
            secondaryValue: EventEmitter.valueString(value),
            highlight: [index],
            nodes: snapshotNodes(),
            message: "\(name): Put \(EventEmitter.valueString(key)) → \(EventEmitter.valueString(value)) @ bucket \(index)",
            meta: ["bucketCount": String(buckets[index].count), "name": name],
            sourceLine: line
        ))
    }

    public func get(_ key: Key, line: Int = #line) -> Value? {
        let index = bucketIndex(for: key)
        EventEmitter.emit(PlaygroundEvent(
            type: "probe",
            structure: "hashTable",
            index: index,
            value: EventEmitter.valueString(key),
            highlight: [index],
            nodes: snapshotNodes(),
            message: "\(name): Probe bucket \(index) for key \(EventEmitter.valueString(key))",
            meta: ["name": name],
            sourceLine: line
        ))
        guard let entry = buckets[index].first(where: { $0.key == key }) else {
            EventEmitter.emit(PlaygroundEvent(
                type: "get",
                structure: "hashTable",
                index: index,
                value: EventEmitter.valueString(key),
                highlight: [index],
                nodes: snapshotNodes(),
                message: "\(name): Get \(EventEmitter.valueString(key)) → miss",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        EventEmitter.emit(PlaygroundEvent(
            type: "get",
            structure: "hashTable",
            index: index,
            value: EventEmitter.valueString(key),
            secondaryValue: EventEmitter.valueString(entry.value),
            highlight: [index],
            nodes: snapshotNodes(),
            message: "\(name): Get \(EventEmitter.valueString(key)) → \(EventEmitter.valueString(entry.value))",
            meta: ["name": name],
            sourceLine: line
        ))
        return entry.value
    }

    @discardableResult
    public mutating func remove(_ key: Key, line: Int = #line) -> Value? {
        let index = bucketIndex(for: key)
        EventEmitter.emit(PlaygroundEvent(
            type: "probe",
            structure: "hashTable",
            index: index,
            value: EventEmitter.valueString(key),
            highlight: [index],
            nodes: snapshotNodes(),
            message: "\(name): Probe bucket \(index) for key \(EventEmitter.valueString(key))",
            meta: ["name": name],
            sourceLine: line
        ))
        guard let existing = buckets[index].firstIndex(where: { $0.key == key }) else {
            EventEmitter.emit(PlaygroundEvent(
                type: "remove",
                structure: "hashTable",
                index: index,
                value: EventEmitter.valueString(key),
                highlight: [index],
                nodes: snapshotNodes(),
                message: "\(name): Remove \(EventEmitter.valueString(key)) → miss",
                meta: ["name": name],
                sourceLine: line
            ))
            return nil
        }
        let value = buckets[index].remove(at: existing).value
        EventEmitter.emit(PlaygroundEvent(
            type: "remove",
            structure: "hashTable",
            index: index,
            value: EventEmitter.valueString(key),
            secondaryValue: EventEmitter.valueString(value),
            highlight: [index],
            nodes: snapshotNodes(),
            message: "\(name): Remove \(EventEmitter.valueString(key))",
            meta: ["name": name],
            sourceLine: line
        ))
        return value
    }
}
