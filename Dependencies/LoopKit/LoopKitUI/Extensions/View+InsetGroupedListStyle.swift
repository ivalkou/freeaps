//
//  View+InsetGroupedListStyle.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


extension View {

    public func insetGroupedListStyle() -> some View {
        modifier(CustomInsetGroupedListStyle())
    }
}

fileprivate struct CustomInsetGroupedListStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .listStyle(InsetGroupedListStyle())
    }
}
