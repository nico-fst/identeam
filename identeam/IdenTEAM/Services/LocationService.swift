import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied or restricted. GPS metadata will not be added.")
        @unknown default:
            print("Unknown location authorization status. GPS metadata will not be added.")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            currentLocation = nil
            print("Location access denied or restricted. GPS metadata will not be added.")
        case .notDetermined:
            break
        @unknown default:
            currentLocation = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .denied {
            manager.stopUpdatingLocation()
            currentLocation = nil
            return
        }
        
        print("ERROR updating location: \(error.localizedDescription)")
    }
}
