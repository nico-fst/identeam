//
//  NavigationViewModel.swift
//  identeam
//
//  Created by Nico Stern on 13.03.26.
//

import Foundation
import SwiftUI
import Combine

enum Route: Hashable {
    case team(slug: String)
}

enum AppTab: Hashable {
    case teams
    case debug
    case create
}

class NavigationViewModel: ObservableObject {
    @Published var teamPath: [Route] = []
    @Published var selectedTab: AppTab = .teams
    
    func push(_ route: Route) {
        teamPath.append(route)
    }
    
    func pop() {
        guard !teamPath.isEmpty else { return }
        teamPath.removeLast()
    }
    
    func popToRoot() {
        teamPath.removeAll()
    }
}
