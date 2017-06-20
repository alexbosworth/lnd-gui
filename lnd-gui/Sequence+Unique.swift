//
//  Sequence+Unique.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/3/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

// MARK: - Hashable Uniqueness
extension Sequence where Iterator.Element: Hashable {
  /** Unique elements in the sequence
   */
  var uniqueElements: [Iterator.Element] { return Array(Set(self)) }
}

// MARK: - Equatable Uniqueness
public extension Sequence where Iterator.Element: Equatable {
  /** Unique elements in the sequence
   */
  var uniqueElements: [Iterator.Element] {
    return reduce([]){ self.uniqueElements.contains($1) ? $0 : $0 + [$1] }
  }
}
