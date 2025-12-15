//
//  AppConfig.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation

enum AppConfig {
    // access via 'AppConfig.apiBaseURL.appendingPathComponent("/auth/check")'
    static let apiBaseURL: URL = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: value)
        else {
            fatalError("API_BASE_URL missing or invalid in Info.plist")
        }
        return url
    }()
}
