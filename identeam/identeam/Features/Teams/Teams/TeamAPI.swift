//
//  AuthService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftData
import SwiftUI

enum TeamError: LocalizedError {
    case targetNotSet
    case backend(String)
    
    var errorDescription: String? {
        switch self {
        case .targetNotSet:
            return "Target not set"
        case .backend(let message):
            return message
        }
    }
}

class TeamAPI {
    @AppStorage("sessionToken") private var sessionToken: String = ""
    
    static let shared = TeamAPI()
    
    struct GetMyTeamsResponse: Decodable {
        let teams: [TeamDTO]
    }
    
    func fetchMyTeams() async throws -> [Team] {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/me"
        )
        
        let response: BackendResponse<GetMyTeamsResponse> =
        try await API.shared
            .getToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            let teams = Team.fromDTOs(response.data?.teams ?? [])
            return teams
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    struct UserAndTeamResponse: Decodable {
        let user: UserDTO
        let team: TeamDTO
    }
    
    func joinTeam(slug: String) async throws -> UserAndTeamResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/join"
        )
        
        let response: BackendResponse<UserAndTeamResponse> =
        try await API.shared.postToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func leaveTeam(slug: String) async throws -> UserAndTeamResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/leave"
        )
        
        let response: BackendResponse<UserAndTeamResponse> =
        try await API.shared.postToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func createTeam(name: String, details: String, notificationTemplate: String) async throws -> TeamDTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent("teams/create")
        let payload: [String: Any] = [
            "name": name,
            "details": details,
            "notificationTemplate": notificationTemplate
        ]
        
        let response: BackendResponse<TeamDTO> = try await API.shared.postToBackend(
            url: url,
            payload: payload
        )
        
        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func fetchTeamWeek(slug: String, date: Date) async throws -> TeamWeek {
        let formatDate = ReminderSchedulePlanner.dateString
        
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/week/\(formatDate(date))"
        )
        
        let response: BackendResponse<TeamWeekDTO> =
        try await API.shared.getToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            let teamWeek = TeamWeek(dto: response.data!)
            return teamWeek
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func remindTeam(slug: String) async throws {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/remind"
        )
        
        let response: BackendResponse<Empty> =
        try await API.shared.postToBackend(url: url)
        
        switch response.statusCode {
        case 200:
            return
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func setTarget(slug: String, dateStart: Date, targetDays: [Date]) async throws {
        let formatDate = ReminderSchedulePlanner.dateString
        
        let formattedDays: [String] = targetDays
            .sorted()
            .map { formatDate($0) }

        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/targets/\(formatDate(dateStart))"
        )
        let payload: [String: Any] = [
            "targetDays": formattedDays
        ]

        let response: BackendResponse<TargetDTO> =
            try await API.shared.putToBackend(
                url: url,
                payload: payload
            )

        switch response.statusCode {
        case 200:
            return
        default:
            throw TeamError.backend(response.message)
        }
    }
}
