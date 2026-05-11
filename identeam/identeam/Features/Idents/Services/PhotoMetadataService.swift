//
//  PhotoMetadataService.swift
//  identeam
//
//  Created by Nico Stern on 06.05.26.
//

import SwiftUI
import CoreLocation

enum PhotoMetadataHelper {
    static func addGPSLocation(_ location: CLLocation?, to imageData: Data) -> Data? {
        guard let location,
              let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(source),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return nil
        }
        
        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outputData, type, 1, nil) else {
            return nil
        }
        
        var updatedMetadata = metadata
        updatedMetadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata(from: location)
        
        CGImageDestinationAddImageFromSource(destination, source, 0, updatedMetadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return outputData as Data
    }
    
    static func gpsMetadata(from location: CLLocation) -> [String: Any] {
        let coordinate = location.coordinate
        var metadata: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: abs(coordinate.latitude),
            kCGImagePropertyGPSLatitudeRef as String: coordinate.latitude >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(coordinate.longitude),
            kCGImagePropertyGPSLongitudeRef as String: coordinate.longitude >= 0 ? "E" : "W",
            kCGImagePropertyGPSTimeStamp as String: location.timestamp.formatted(
                .dateTime.hour().minute().second().timeZone()
            ),
            kCGImagePropertyGPSDateStamp as String: location.timestamp.formatted(
                .dateTime.year().month().day()
            )
        ]
        
        if location.horizontalAccuracy >= 0 {
            metadata[kCGImagePropertyGPSHPositioningError as String] = location.horizontalAccuracy
        }
        
        if location.verticalAccuracy >= 0 {
            metadata[kCGImagePropertyGPSAltitude as String] = abs(location.altitude)
            metadata[kCGImagePropertyGPSAltitudeRef as String] = location.altitude >= 0 ? 0 : 1
        }
        
        return metadata
    }
}
