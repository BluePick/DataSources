//
//  SectionDataSource.swift
//  DataSources
//
//  Created by muukii on 8/8/17.
//  Copyright © 2017 muukii. All rights reserved.
//

import Foundation

public protocol SectionDataSourceType {

  associatedtype ItemType : Diffable
  associatedtype AdapterType : Updating

  func update(items: [ItemType], updateMode: SectionDataSource<ItemType, AdapterType>.UpdateMode, immediately: Bool, completion: @escaping () -> Void)

  func asSectionDataSource() -> SectionDataSource<ItemType, AdapterType>
}

/// Type of Model erased SectionDataSource
final class AnySectionDataSource<A: Updating> {

  let source: Any

  private let _numberOfItems: () -> Int
  private let _item: (IndexPath) -> Any
  
  init<T>(source: SectionDataSource<T, A>) {
    self.source = source
    _numberOfItems = {
      source.numberOfItems()
    }
    _item = {
      let index = source.toIndex(from: $0)
      return source.snapshot[index]
    }
  }

  public func numberOfItems() -> Int {
    return _numberOfItems()
  }

  public func item(for indexPath: IndexPath) -> Any {
    return _item(indexPath)
  }

  func restore<T>(itemType: T.Type) -> SectionDataSource<T, A> {
    guard let r = source as? SectionDataSource<T, A> else {
      fatalError("itemType is different to SectionDataSource.ItemType")
    }
    return r
  }
}

/// DataSource for a section
public final class SectionDataSource<T: Diffable, A: Updating>: SectionDataSourceType {

  public typealias ItemType = T
  public typealias AdapterType = A

  public enum UpdateMode {
    case everything
    case partial(animated: Bool)
  }

  // MARK: - Properties

  private(set) public var items: [T] = []

  fileprivate var snapshot: [T] = []

  private let updater: SectionUpdater<T, A>

  private let throttle = Throttle(interval: 0.1)

  public var displayingSection: Int

  fileprivate let isEqual: (T, T) -> Bool

  // MARK: - Initializers

  public init(itemType: T.Type? = nil, adapter: A, displayingSection: Int = 0, isEqual: @escaping EqualityChecker<T>) {
    self.updater = SectionUpdater(adapter: adapter)
    self.isEqual = isEqual
    self.displayingSection = displayingSection
  }

  // MARK: - Functions

  public func numberOfItems() -> Int {
    return snapshot.count
  }

  public func item(at indexPath: IndexPath) -> T {
    let index = toIndex(from: indexPath)
    return snapshot[index]
  }

  /// Reserves that a move occurred in DataSource by View operation.
  ///
  /// If you moved item on View, operation following order,
  /// 1. Call reserveMoved(...
  /// 2. Reorder items
  /// 3. update(items: [T]..
  ///
  /// - Parameters:
  ///   - sourceIndexPath:
  ///   - destinationIndexPath:
  public func reserveMoved(source sourceIndexPath: IndexPath, destination destinationIndexPath: IndexPath) {

    precondition(
      sourceIndexPath.section == displayingSection,
      "sourceIndexPath.section \(sourceIndexPath.section) must be equal to \(displayingSection)"
    )
    precondition(
      destinationIndexPath.section == displayingSection,
      "destinationIndexPath.section \(sourceIndexPath.section) must be equal to \(displayingSection)"
    )

    let o = snapshot.remove(at: sourceIndexPath.item)
    snapshot.insert(o, at: destinationIndexPath.item)
  }

  public func update(items: [T], updateMode: UpdateMode, immediately: Bool = false, completion: @escaping () -> Void) {

    self.items = items

    let task = { [weak self] in
      guard let `self` = self else { return }

      let old = self.snapshot
      let new = self.items
      self.snapshot = new

      var _updateMode: SectionUpdater<T, A>.UpdateMode {
        switch updateMode {
        case .everything:
          return .everything
        case .partial(let animated):
          return .partial(animated: animated, isEqual: self.isEqual)
        }
      }

      self.updater.update(
        targetSection: self.displayingSection,
        currentDisplayingItems: old,
        newItems: new,
        updateMode: _updateMode,
        completion: completion
      )
    }

    if immediately {
      throttle.cancel()
      task()
    } else {
      throttle.on {
        task()
      }
    }
  }

  public func asSectionDataSource() -> SectionDataSource<ItemType, AdapterType> {
    return self
  }

  public func indexPath(item: Int) -> IndexPath {
    return IndexPath(item: item, section: displayingSection)
  }

  @inline(__always)
  fileprivate func toIndex(from indexPath: IndexPath) -> Int {
    assert(indexPath.section == displayingSection, "IndexPath.section (\(indexPath.section)) must be equal to displayingSection (\(displayingSection)).")
    return indexPath.item
  }
}

extension SectionDataSource {

  /// IndexPath of Item
  ///
  /// IndexPath will be found by isEqual closure.
  ///
  /// - Parameter item:
  /// - Returns:
  public func indexPath(of item: T) -> IndexPath {
    let index = items.index(where: { isEqual($0, item) })!
    return IndexPath(item: index, section: displayingSection)
  }
}

extension SectionDataSource where T : AnyObject {

  /// IndexPath of Item
  ///
  /// IndexPath will be found by the pointer for Item.
  ///
  /// - Parameter item:
  /// - Returns:
  public func indexPathPointerPersonality(of item: T) -> IndexPath {
    let index = items.index(where: { $0 === item })!
    return IndexPath(item: index, section: displayingSection)
  }
}

extension SectionDataSource where T : Equatable {

  public convenience init(itemType: T.Type? = nil, adapter: A, displayingSection: Int = 0) {
    self.init(adapter: adapter, displayingSection: displayingSection, isEqual: { a, b in a == b })
  }
}
