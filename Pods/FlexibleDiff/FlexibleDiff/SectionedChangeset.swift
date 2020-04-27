import Foundation

/// Represents an atomic batch of changes made to a sectioned collection.
public struct SectionedChangeset {
	/// Represents a mutated section for either or both its collection of items
	/// and its metadata.
	public struct MutatedSection {
		/// The offset of the section in the previous version of the sectioned
		/// collection.
		public let source: Int

		/// The offset of the section in the current version of the sectioned
		/// collection.
		public let destination: Int

		/// Represents changes within the section.
		///
		/// If the changeset specifies no change, it implies that only the
		/// section metadata has been changed.
		public let changeset: Changeset

		public init(source: Int, destination: Int, changeset: Changeset) {
			self.source = source
			self.destination = destination
			self.changeset = changeset
		}
	}

	/// The changes of sections.
	///
	/// - precondition: Offsets in `sections.mutations` and `sections.moves` must have a
	///                 corresponding entry in `mutatedSections` if they represent a
	///                 mutation.
	public var sections = Changeset()

	/// The changes of items in the mutated sections.
	///
	/// - precondition: `mutatedSections` must have an entry for every mutated
	///                 sections specified by `sections.mutations` and
	///                 `sections.moves`.
	public var mutatedSections: [MutatedSection] = []

	public init(sections: Changeset = Changeset(), mutatedSections: [MutatedSection] = []) {
		(self.sections, self.mutatedSections) = (sections, mutatedSections)
	}

	public init<C: Collection>(initial: C) {
		sections.inserts.insert(integersIn: 0 ..< Int(initial.count))
	}

	/// Compute the difference of a collection from its previous version.
	///
	/// The algorithm works best with collections of uniquely identified values.
	///
	/// If the multiple elements are bound to the same identifier, the algorithm
	/// would compute shortest moves at best effort, and removals or insertions
	/// depending on the change in the occurences.
	///
	/// - parameters:
	///   - previous: The previous version of the collection.
	///   - current: The collection.
	///   - sectionIdentifier: A lense to extract the unique identifier of the
	///                        given section.
	///   - areMetadataEqual: A predicate to evaluate equality of the two given
	///                       sections, which need not take account of the
	///                       items.
	///   - items: A lense to extract items from a given section.
	///   - itemIdentifier: A lense to extract the unique identifier of the
	///                     given item.
	///   - areItemsEqual: A predicate to evaluate equality of the two given
	///                    items.
	///
	/// - complexity: O(n) time and space.
	public init<Sections: Collection, Items: Collection, SectionIdentifier: Hashable, ItemIdentifier: Hashable>(
			previous: Sections,
			current: Sections,
			sectionIdentifier: (Sections.Element) -> SectionIdentifier,
			areMetadataEqual: (Sections.Element, Sections.Element) -> Bool,
			items: (Sections.Element) -> Items,
			itemIdentifier: (Items.Element) -> ItemIdentifier,
			areItemsEqual: (Items.Element, Items.Element) -> Bool
	) {
		let metadata = Changeset(previous: previous, current: current, identifier: sectionIdentifier, areEqual: areMetadataEqual)

		let moveDestinationLookup = Dictionary(uniqueKeysWithValues: metadata.moves.lazy.map { ($0.source, $0.destination) })
		let mutatedMoveDests = Set(metadata.moves.lazy.filter { $0.isMutated }.map { $0.destination })

		let allInsertions = metadata.inserts.union(IndexSet(moveDestinationLookup.values))
		let allRemovals = metadata.removals.union(IndexSet(moveDestinationLookup.keys))

		mutatedSections = Array()
		mutatedSections.reserveCapacity(Int(current.count))

		var moves: [Changeset.Move] = []
		var mutations = IndexSet()

		for (sourceOffset, section) in previous.enumerated() where !metadata.removals.contains(sourceOffset) {
			let destinationOffset: Int
			let isMove: Bool

			if let moveDestination = moveDestinationLookup[sourceOffset] {
				destinationOffset = moveDestination
				isMove = true
			} else {
				let postRemovalOffset = sourceOffset - allRemovals.count(in: 0 ..< sourceOffset)

				var insertionsBeforeOffset = 0
				for insertion in allInsertions {
					if insertion <= postRemovalOffset + insertionsBeforeOffset {
						insertionsBeforeOffset += 1
					} else {
						break
					}
				}

				destinationOffset = postRemovalOffset + insertionsBeforeOffset
				isMove = false
			}

			let previousItems = items(section)
			let currentIndex = current.index(current.startIndex, offsetBy: numericCast(destinationOffset))
			let currentItems = items(current[currentIndex])

			let changeset = Changeset(previous: previousItems,
			                          current: currentItems,
			                          identifier: itemIdentifier,
			                          areEqual: areItemsEqual)

			let isMutated = !changeset.hasNoChanges
				|| metadata.mutations.contains(sourceOffset)
				|| mutatedMoveDests.contains(destinationOffset)

			if isMutated {
				let section = SectionedChangeset.MutatedSection(source: sourceOffset,
                                                                destination: destinationOffset,
                                                                changeset: changeset)
				mutatedSections.append(section)
			}

			if isMove {
				moves.append(Changeset.Move(source: sourceOffset,
                                            destination: destinationOffset,
                                            isMutated: isMutated))
			} else if isMutated {
				mutations.insert(sourceOffset)
			}
		}

		sections = Changeset(inserts: metadata.inserts,
							 removals: metadata.removals,
							 mutations: mutations,
							 moves: moves)
	}
}

extension SectionedChangeset: CustomDebugStringConvertible {
	public var debugDescription: String {
		let contents: [String] = [
			sections.debugDescription,
			"- changesets of mutated sections: <<<",
			mutatedSections
				.map { entry in
					return "    section \(entry.source) -> \(entry.destination)\n"
						+ entry.changeset.debugDescription
							.split(separator: "\n")
							.map { "    \($0)" }
							.joined(separator: "\n")
				}
				.joined(separator: "\n"),
			"  >>>",
			]
		return contents.joined(separator: "\n")
	}
}

extension SectionedChangeset: Equatable {
	public static func == (lhs: SectionedChangeset, rhs: SectionedChangeset) -> Bool {
		func sourceOffsetIncreasingOrder(_ lhs: MutatedSection, _ rhs: MutatedSection) -> Bool {
			return lhs.source < rhs.source
		}

		return lhs.sections == rhs.sections
			&& lhs.mutatedSections.sorted(by: sourceOffsetIncreasingOrder) == rhs.mutatedSections.sorted(by: sourceOffsetIncreasingOrder)
	}
}

extension SectionedChangeset.MutatedSection: Equatable {
	public static func == (lhs: SectionedChangeset.MutatedSection, rhs: SectionedChangeset.MutatedSection) -> Bool {
		return lhs.source == rhs.source
			&& lhs.destination == rhs.destination
			&& lhs.changeset == rhs.changeset
	}
}
