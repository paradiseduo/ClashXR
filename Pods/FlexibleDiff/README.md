## Introduction
**FlexibleDiff** is a simple collection diffing μframework for Swift, allowing
separated defintions of identity and equality for the purpose of diffing.

For general business concerns, full inequality of two instances does not
necessarily mean inequality in term of identity — it just means the data being
held has changed if the identity of both instances are the same. However, as
most of the diffing μframeworks rely on only — and therefore are constrained
by — the `Equatable` requirement, they are not capable of expressing the
identical-but-unequal scenarios which are common especially in interactive
applications.

*FlexibleDiff* addresses the issue by supporting changeset computation with
custom definitions for equality _and_ identity.

For example, given these definitions:
```swift
let previous: [Book]
let current: [Book]

struct Book: Equatable {
    let isbn: String
    var name: String
    var publishedOn: [Date]
}
```

We may supply a custom identity definition, and get to know about in-place
mutated books, or mutated books at a different position, on the basis of books
being  identified only by their ISBN.

```swift
let changeset = Changeset(previous: previous,
                          current: current,
                          identifier: { book in book.isbn },
                          areEqual: Book.==)
```

The improved expressivity of the diff, as compared to conventional `Equatable`
-based μframeworks, allows more fitting collection view animations to be issued.

On top of the flexible API, *FlexibleDiff* provides also several conveniences for
common use cases:

| `Collection.Element` | Identified By | Compared By |
| ---- | --- | ---- |
| `AnyObject` | Object identity | Object identity |
| `AnyObject & Equatable` | Object identity | Object identity or value equality. |
| `AnyObject & Hashable` | Object identity, or value equality. | Object identity, or value equality. |
| `Hashable`| Value equality | Value equality |

## Getting Started
**FlexibleDiff** is offered as a standalone Xcode project, and supports both
Carthage and CocoaPods.

```
# Carthage
github "RACCommunity/FlexibleDiff"

# CocoaPods
pod "FlexibleDiff"
```

## The Example App
The Xcode workspace includes an example app using FlexibleDiff. Be sure to run `git submodule update --init` to fetch the dependencies before building the app target in Xcode.

## Note on the algorithm
The implementation is evolved from the popular O(n) diff algorithm by Paul
Heckel, in [his 1978 paper "A technique for isolating differences between files"](https://dl.acm.org/citation.cfm?id=359467).
The algorithm serves as the basis of many frameworks across multiple platforms, including but not
limited to [IGListKit](https://github.com/Instagram/IGListKit).

## License
Licensed under the MIT License.
