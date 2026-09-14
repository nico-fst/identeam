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
