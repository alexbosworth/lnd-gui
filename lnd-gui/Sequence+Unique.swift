//
//  Sequence+Unique.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/3/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

public extension Sequence where Iterator.Element: Hashable {
  var uniqueElements: [Iterator.Element] { return Array(Set(self)) }
}

public extension Sequence where Iterator.Element: Equatable {
  var uniqueElements: [Iterator.Element] {
    return reduce([]){ uniqueElements, element in
      return uniqueElements.contains(element) ? uniqueElements : uniqueElements + [element]
    }
  }
}
