import Foundation

/// Represents an atomic batch of changes made to a collection.
///
/// A `Changeset` represents changes as **offsets** of elements. You may
/// subscript a collection of zero-based indexing with the offsets, e.g. `Array`. You must
/// otherwise convert the offsets into indices before subscripting.
///
/// # Implicit order between offsets.
///
/// Removal offsets precede insertion offsets. Move offset pairs are semantically
/// equivalent to a pair of removal offset (source) and an insertion offset (destination).
///
/// ## Example: Reproducing an array.
///
/// Given a previous version of a collection, a current version of a collection, and a
/// `Changeset`, we can reproduce the current version by applying the `Changeset` to
/// the previous version.
///
/// - note: `Array` is a zero-based container, thus being able to consume zero-based
/// offsets directly. If you are working upon non-zero-based or undetermined collection
/// types, you **must** first convert offsets into indices.
///
/// 1. Clone the previous version.
///
///    ```
///    var elements = previous
///    ```
///
/// 2. Copy the position invariant mutations.
///
///    ```
///    for offset in changeset.mutations {
///        elements[offset] = current[offset]
///    }
///    ```
///
/// 2. Obtain all insertion and removal offsets, including move offsets.
///
///    ```
///    let removals = changeset.removals.union(IndexSet(changeset.moves.map { $0.source }))
///    let inserts = changeset.inserts.union(IndexSet(changeset.moves.map { $0.destination }))
///    ```
///
/// 3. Perform removals specified by `removals` and `moves` (sources).
///
///    ```
///    for range in removals.rangeView.reversed() {
///        elements.removeSubrange(range)
///    }
///    ```
///
/// 5. Perform inserts specified by `inserts` and `moves` (destinations).
///
///    ```
///    for range in inserts.rangeView {
///        elements.insert(contentsOf: current[range], at: range.lowerBound)
///    }
///    ```
///
public struct Changeset {
	/// Represents the context of a move operation applied to a collection.
	public struct Move {
		public let source: Int
		public let destination: Int
		public let isMutated: Bool

		public init(source: Int, destination: Int, isMutated: Bool) {
			(self.source, self.destination, self.isMutated) = (source, destination, isMutated)
		}
	}

	/// The offsets of inserted elements in the current version of the collection.
	///
	/// - important: To obtain the actual index, you must apply
	///              `Collection.index(self:_:offsetBy:)` on the current version, the
	///              start index and the inserting offset.
	public var inserts = IndexSet()

	/// The offsets of removed elements in the previous version of the collection.
	///
	/// - important: To obtain the actual index, you must apply
	///              `Collection.index(self:_:offsetBy:)` on the previous version, the
	///              start index and the removal offset.
	public var removals = IndexSet()

	/// The offsets of position-invariant mutations that are valid across both versions
	/// of the collection.
	///
	/// `mutations` only implies an invariant relative position. The actual indexes can
	/// be different, depending on the collection type.
	///
	/// If an element has both changed and moved, it is instead included in `moves` with
	/// an asserted mutation flag.
	///
	/// - important: To obtain the actual index, you must apply
	///              `Collection.index(self:_:offsetBy:)` on the relevant versions, the
	///              start index and the offset.
	public var mutations = IndexSet()

	/// The offset pairs of moves.
	///
	/// These represent only the required moves for reproducing the current version from the
	/// previous version — moves being implied by preceding removals and insertions could
	/// have been eliminated as an optimization.
	///
	/// The source offset is semantically equivalent to a removal offset, while the
	/// destination offset is semantically equivalent to an insertion offset.
	///
	/// - important: To obtain the actual index, you must apply
	///              `Collection.index(self:_:offsetBy:)` on the relevant versions, the
	///              start index and the move offsets.
	public var moves = [Move]()

	/// Indicate whether there is no change across both versions of the collection.
	public var hasNoChanges: Bool {
		return inserts.isEmpty && removals.isEmpty && mutations.isEmpty && moves.isEmpty
	}

	public init() {}

	public init(inserts: IndexSet = [], removals: IndexSet = [], mutations: IndexSet = [], moves: [Move] = []) {
		(self.inserts, self.removals) = (inserts, removals)
		(self.mutations, self.moves) = (mutations, moves)
	}

	public init<C: Collection>(initial: C) {
		self.init()
		self.inserts = IndexSet(integersIn: 0 ..< Int(initial.count))
	}

	public init<C: Collection, Identifier: Hashable>(
		previous: C?,
		current: C,
		identifier: (C.Element) -> Identifier,
		areEqual: (C.Element, C.Element) -> Bool
	) {
		guard let previous = previous else {
			self.init(initial: current)
			return
		}

		var table: [Identifier: DiffEntry] = Dictionary(minimumCapacity: Int(current.count))

		var oldIdentifiers = ContiguousArray(previous.map(identifier))
		var newIdentifiers = ContiguousArray(current.map(identifier))

		var oldReferences: [DiffReference] = []
		var newReferences: [DiffReference] = []

		let oldCount = oldIdentifiers.count
		let newCount = newIdentifiers.count

		oldReferences.reserveCapacity(oldCount)
		newReferences.reserveCapacity(newCount)

		func tableEntry(for identifier: Identifier) -> DiffEntry {
			if let entry = table[identifier] {
				return entry
			}

			let entry = DiffEntry()
			table[identifier] = entry
			return entry
		}

		// Pass 1: Scan the new snapshot.
		for offset in 0 ..< newCount {
			let entry = tableEntry(for: newIdentifiers[offset])

			entry.occurenceInNew += 1
			newReferences.append(.table(entry))
		}

		// Pass 2: Scan the old snapshot.
		for offset in 0 ..< oldCount {
			let entry = tableEntry(for: oldIdentifiers[offset])

			entry.locationsInOld.insert(offset)
			oldReferences.append(.table(entry))
		}

		// Pass 3: Single-occurence lines
		for newPosition in 0 ..< newCount {
			switch newReferences[newPosition] {
			case let .table(entry):
				if entry.occurenceInNew == 1 && entry.locationsInOld.count == 1 {
					let oldPosition = entry.locationsInOld.first!
					newReferences[newPosition] = .remote(oldPosition)
					oldReferences[oldPosition] = .remote(newPosition)
				}

			case .remote:
				break
			}
		}

		self.init()

		// Pass 4: Pair repeated values, and compute insertions.
		for newPosition in 0 ..< newCount {
			guard case let .table(entry) = newReferences[newPosition] else { continue }
			if let closestOld = entry.locationsInOld.closest(to: newPosition) {
				// Pull the closest old location from the all unassigned known old
				// locations of this entry. Then remove this instance from the table
				// entry, so that the unpaired instance would be identified by Pass 7
				// as removals.
				entry.locationsInOld.remove(closestOld)
				entry.occurenceInNew -= 1
				newReferences[newPosition] = .remote(closestOld)
				oldReferences[closestOld] = .remote(newPosition)
			} else if entry.occurenceInNew > 0 {
				// If no old location is left, it is treated as an inserted element.
				inserts.insert(newPosition)
			}
		}

		// Pass 5: Mark adjacent lines as direct moves.
		for newPosition in 0 ..< max(newCount - 1, 0) {
			guard case let .remote(oldPosition) = newReferences[newPosition],
			      oldPosition + 1 < oldCount,
			      oldIdentifiers[oldPosition + 1] == newIdentifiers[newPosition + 1],
			      case let .table(entry) = newReferences[newPosition + 1],
			      entry.locationsInOld.contains(oldPosition + 1) else {
				continue
			}

			newReferences[newPosition + 1] = .remote(oldPosition + 1)
			oldReferences[oldPosition + 1] = .remote(newPosition + 1)
			entry.occurenceInNew -= 1
			entry.locationsInOld.remove(oldPosition + 1)
		}

		// Pass 6: Mark adjacent lines as direct moves.
		for oldPosition in 0 ..< max(oldCount - 1, 0) {
			guard case let .remote(newPosition) = oldReferences[oldPosition],
			      newPosition + 1 < newCount,
			      oldIdentifiers[oldPosition + 1] == newIdentifiers[newPosition + 1],
			      case let .table(entry) = newReferences[newPosition + 1],
			      entry.locationsInOld.contains(oldPosition + 1) else {
				continue
			}

			newReferences[newPosition + 1] = .remote(oldPosition + 1)
			oldReferences[oldPosition + 1] = .remote(newPosition + 1)
			entry.occurenceInNew -= 1
			entry.locationsInOld.remove(oldPosition + 1)
		}

		// Pass 7: Compute removals. Prepare removal offsets for move elimination.
		for oldPosition in 0 ..< oldCount {
			if case let .table(entry) = oldReferences[oldPosition], entry.occurenceInNew == 0 {
				removals.insert(oldPosition)
			}
		}

		// Pass 8: Compute mutations and moves.
		var movePaths: [MovePath: Bool] = [:]

		for newPosition in 0 ..< newCount {
			guard case let .remote(oldPosition) = newReferences[newPosition] else {
				continue
			}

			#if swift(>=4.1)
				let previousIndex = previous.index(previous.startIndex, offsetBy: oldPosition)
				let currentIndex = current.index(current.startIndex, offsetBy: newPosition)
			#else
				let previousIndex = previous.index(previous.startIndex, offsetBy: C.IndexDistance(oldPosition))
				let currentIndex = current.index(current.startIndex, offsetBy: C.IndexDistance(newPosition))
			#endif

			let isMutated = !areEqual(previous[previousIndex], current[currentIndex])

			if newPosition - oldPosition != 0 {
				let path = MovePath(source: oldPosition, destination: newPosition)
				movePaths[path] = isMutated
			} else if isMutated {
				mutations.insert(oldPosition)
			}
		}

		// The following two passes perform move eliminations. The algorithm is
		// conservative and care about only one contiguous block immediately following the
		// deletion or the insertion.

		// Pass 9: Eliminating removal-caused immutable moves.
		for range in removals.rangeView {
			var path = MovePath(source: range.upperBound, destination: range.lowerBound)
			while path.destination < newCount, let isMutated = movePaths[path] {
				if !isMutated {
					movePaths.removeValue(forKey: path)
				}

				path = path.shifted(by: 1)
			}
		}

		// Pass 10: Eliminating insertion-caused immutable moves.
		for range in inserts.rangeView {
			var path = MovePath(source: range.lowerBound, destination: range.upperBound)
			while path.destination < newCount, let isMutated = movePaths[path] {
				if !isMutated {
					movePaths.removeValue(forKey: path)
				}

				path = path.shifted(by: 1)
			}
		}

		// Pass 11: Forge the move results.
		moves = movePaths.map { Changeset.Move(source: $0.source, destination: $0.destination, isMutated: $1) }
	}

	/// Compute the difference of `self` with regard to `old` by value equality.
	///
	/// `diff(with:)` works best with collections that contain unique values.
	///
	/// If the multiple elements are bound to the same identifier, the algorithm would
	/// generate moves at its best effort, with the rest being represented as inserts
	/// and/or removals.
	///
	/// - precondition: The collection type must exhibit array semantics.
	///
	/// - complexity: O(n) time and space.
	public init<C: Collection, Identifier: Hashable>(
		previous: C?,
		current: C,
		identifier: (C.Element) -> Identifier
	) where C.Element: Equatable {
		self.init(previous: previous, current: current, identifier: identifier, areEqual: ==)
	}

	/// Compute the difference of `self` with regard to `old` by value equality.
	///
	/// `diff(with:)` works best with collections that contain unique values.
	///
	/// If the multiple elements appear in the collection, the algorithm would generate
	/// moves at its best effort, with the rest being represented as inserts
	/// and/or removals.
	///
	/// - precondition: The collection type must exhibit array semantics.
	///
	/// - complexity: O(n) time and space.
	public init<C: Collection>(
		previous: C?,
		current: C
	) where C.Element: Hashable {
		self.init(previous: previous, current: current, identifier: { $0 }, areEqual: ==)
	}

	/// Compute the difference of `self` with regard to `old` by object identity.
	///
	/// If the same object appears multiple times in the collection, the algorithm would
	/// generate moves at its best effort, with the rest being represented as inserts
	/// and/or removals.
	///
	/// - precondition: The collection type must exhibit array semantics.
	///
	/// - complexity: O(n) time and space.
	public init<C: Collection>(
		previous: C?,
		current: C
	) where C.Element: AnyObject {
		self.init(previous: previous, current: current, identifier: ObjectIdentifier.init, areEqual: ===)
	}

	/// Compute the difference of `self` with regard to `old` using the given comparing
	/// strategy. The elements are identified by their object identity.
	///
	/// If the same object appears multiple times in the collection, the algorithm would
	/// generate moves at its best effort, with the rest being represented as inserts
	/// and/or removals.
	///
	/// - precondition: The collection type must exhibit array semantics.
	///
	/// - parameters:
	///   - strategy: The comparing strategy to use.
	///
	/// - complexity: O(n) time and space.
	public init<C: Collection>(
		previous: C?,
		current: C,
		comparingBy strategy: ObjectDiffStrategy = .value
	) where C.Element: AnyObject & Equatable {
		switch strategy.kind {
		case .value:
			self.init(previous: previous, current: current, identifier: ObjectIdentifier.init, areEqual: ==)
		case .identity:
			self.init(previous: previous, current: current, identifier: ObjectIdentifier.init, areEqual: ===)
		}
	}

	/// Compute the difference of `self` with regard to `old` using the given comparing
	/// strategy. The elements are identified by the given identifying strategy.
	///
	/// If the same object is identified multiple times in the collection, the algorithm
	/// would generate moves at its best effort, with the rest being represented as
	/// inserts and/or removals.
	///
	/// - precondition: The collection type must exhibit array semantics.
	///
	/// - parameters:
	///   - identifyingStrategy: The identifying strategy to use.
	///   - comparingStrategy: The comparingStrategy strategy to use.
	///
	/// - complexity: O(n) time and space.
	public init<C: Collection>(
		previous: C?,
		current: C,
		identifyingBy identifyingStrategy: ObjectDiffStrategy = .identity,
		comparingBy comparingStrategy: ObjectDiffStrategy = .value
	) where C.Element: AnyObject & Hashable {
		switch (identifyingStrategy.kind, comparingStrategy.kind) {
		case (.value, .value):
			self.init(previous: previous, current: current, identifier: { $0 }, areEqual: ==)
		case (.value, .identity):
			self.init(previous: previous, current: current, identifier: { $0 }, areEqual: ===)
		case (.identity, .identity):
			self.init(previous: previous, current: current, identifier: ObjectIdentifier.init, areEqual: ===)
		case (.identity, .value):
			self.init(previous: previous, current: current, identifier: ObjectIdentifier.init, areEqual: ==)
		}
	}
}

extension Changeset {
	/// The comparison strategies used by the collection diffing operators on collections
	/// that contain `Hashable` objects.
	public struct ObjectDiffStrategy {
		fileprivate enum Kind {
			case identity
			case value
		}

		/// Compare the elements by their object identity.
		public static let identity = ObjectDiffStrategy(kind: .identity)

		/// Compare the elements by their value equality.
		public static let value = ObjectDiffStrategy(kind: .value)

		fileprivate let kind: Kind

		private init(kind: Kind) {
			self.kind = kind
		}
	}
}

// The key equality implies only referential equality. But the value equality of the
// uniquely identified element across snapshots is uncertain. It is pretty common to diff
// elements with constant unique identifiers but changing contents. For example, we may
// have an array of `Conversation`s, identified by the backend ID, that is constantly
// updated with the latest messages pushed from the backend. So our diffing algorithm
// must have an additional mean to test elements for value equality.

private final class DiffEntry {
	var occurenceInNew: UInt = 0
	var locationsInOld = Set<Int>()
}

private enum DiffReference {
	case remote(Int)
	case table(DiffEntry)
}

private struct MovePath: Hashable {
	let source: Int
	let destination: Int

	func shifted(by offset: Int) -> MovePath {
		return MovePath(source: source + offset, destination: destination + offset)
	}

	static func == (left: MovePath, right: MovePath) -> Bool {
		return left.source == right.source && left.destination == right.destination
	}
}

#if !swift(>=3.2)
	extension SignedInteger {
		fileprivate init<I: SignedInteger>(_ integer: I) {
			self.init(integer.toIntMax())
		}
	}
#endif

extension Set where Element == Int {
	fileprivate func closest(to integer: Int) -> Int? {
		return self.min { abs($0 - integer) < abs($1 - integer) }
	}
}

extension Changeset.Move: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(source)
		hasher.combine(destination)
	}

	public static func == (left: Changeset.Move, right: Changeset.Move) -> Bool {
		return left.isMutated == right.isMutated && left.source == right.source && left.destination == right.destination
	}
}

extension Changeset: Equatable {
	public static func == (left: Changeset, right: Changeset) -> Bool {
		return left.inserts == right.inserts && left.removals == right.removals && left.mutations == right.mutations && Set(left.moves) == Set(right.moves)
	}
}

// Better debugging experience
extension Changeset: CustomDebugStringConvertible {
	public var debugDescription: String {
		func moveDescription(_ move: Move) -> String {
			return "\(move.source) -> \(move.isMutated ? "*" : "")\(move.destination)"
		}

		return ([
			"- inserted \(inserts.count) item(s) at [\(inserts.map(String.init).joined(separator: ", "))]" as String,
			"- deleted \(removals.count) item(s) at [\(removals.map(String.init).joined(separator: ", "))]" as String,
			"- mutated \(mutations.count) item(s) at [\(mutations.map(String.init).joined(separator: ", "))]" as String,
			"- moved \(moves.count) item(s) at [\(moves.map(moveDescription).joined(separator: ", "))]" as String,
		] as [String]).joined(separator: "\n")
	}
}
