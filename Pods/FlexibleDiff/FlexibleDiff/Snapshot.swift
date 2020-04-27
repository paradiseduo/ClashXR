/// Represents a snapshot of a collection.
///
/// The changeset associated with the first snapshot received by any given observation
/// is generally irrelevant. Observations should special case the first snapshot as a
/// complete replacement, or whatever semantic that fits their purpose.
///
/// The previous version of the collection is unavailable on the initial snapshot,
/// since there is no history to refer to.
public struct Snapshot<Collection: Swift.Collection>: SnapshotProtocol {
	/// The previous version of the collection, or `nil` if `self` is an initial snapshot.
	public let previous: Collection?

	/// The current version of the collection.
	public let current: Collection

	/// The changeset which, when applied on `previous`, reproduces `current`.
	public let changeset: Changeset

	/// Create a snapshot.
	///
	/// - paramaters:
	///   - previous: The previous version of the collection.
	///   - current: The current version of the collection.
	///   - changeset: The changeset which, when applied on `previous`, reproduces
	///                `current`.
	public init(previous: Collection?, current: Collection, changeset: Changeset) {
		(self.previous, self.current, self.changeset) = (previous, current, changeset)
	}
}

/// A protocol for constraining associated types to a `Snapshot`.
public protocol SnapshotProtocol {
	associatedtype Collection: Swift.Collection

	var previous: Collection? { get }
	var current: Collection { get }
	var changeset: Changeset { get }
}

extension Snapshot where Collection.Iterator.Element: Equatable {
	public static func == (left: Snapshot<Collection>, right: Snapshot<Collection>) -> Bool {
		guard left.changeset == right.changeset else { return false }
		guard (left.previous != nil && right.previous != nil && left.previous!.elementsEqual(right.previous!))
		      || (left.previous == nil && right.previous == nil)
			else { return false }
		return left.current.elementsEqual(right.current)
	}
}
