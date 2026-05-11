//
//  ViewModel.swift
//  identeam
//
//  Created by Nico Stern on 28.12.25.
//

import Combine
import Foundation

class AppViewModel: ObservableObject {
    @Published var toastMessage: String?
    @Published var alert: AlertData?

    struct AlertData: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    func showAlert(_ title: String, _ message: String, ) {
        alert = AlertData(title: title, message: message)
    }
}
