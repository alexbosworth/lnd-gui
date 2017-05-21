//
//  Date+formatted.swift
//  lnd-gui
//
//  Created by Alex Bosworth on 5/20/17.
//  Copyright © 2017 Adylitica. All rights reserved.
//

import Foundation

extension Date {
  /** Get formatted date string
   */
  func formatted(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
    let formatter = DateFormatter()

    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle

    return formatter.string(from: self)
  }
}
