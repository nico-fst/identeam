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
    case backend(String)
    
    var errorDescription: String? {
        switch self {
        case .backend(let message):
            return message
        }
    }
}

class TeamService {
    @AppStorage("sessionToken") private var sessionToken: String = ""

    static let shared = TeamService()

    struct GetMyTeamsResponse: Decodable {
        let teams: [TeamDTO]
    }

    func fetchMyTeams() async throws -> [Team] {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/me"
        )

        let response: BackendResponse<GetMyTeamsResponse> =
            try await RequestService.shared
            .getToBackend(url: url)

        switch response.statusCode {
        case 200:
            let teams = Team.fromDTOs(response.data?.teams ?? [])
            return teams
        default:
            throw NSError(
                domain: "TeamService",
                code: response.statusCode,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
    }

    struct UserAndTeamResponse: Decodable {
        let user: UserDTO
        let team: TeamDTO
    }

    func joinTeam(slug: String) async throws -> UserAndTeamResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/join/\(slug)"
        )

        let response: BackendResponse<UserAndTeamResponse> =
            try await RequestService.shared.postToBackend(url: url)

        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw NSError(
                domain: "",
                code: response.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: response.message
                ]
            )
        }
    }

    func leaveTeam(slug: String) async throws -> UserAndTeamResponse {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/leave/\(slug)"
        )

        let response: BackendResponse<UserAndTeamResponse> =
            try await RequestService.shared.postToBackend(url: url)

        switch response.statusCode {
        case 200:
            return response.data!
        default:
            throw NSError(
                domain: "",
                code: response.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: response.message
                ]
            )
        }
    }
    
    func createTeam(name: String, details: String) async throws -> TeamDTO {
        let url = AppConfig.apiBaseURL.appendingPathComponent("teams/create")
        let payload: [String: Any] = [
            "name": name,
            "details": details
        ]
        
        let response: BackendResponse<TeamDTO> = try await RequestService.shared.postToBackend(
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
        let base = AppConfig.apiBaseURL.appendingPathComponent("teams/\(slug)/week")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        
        let formatter = ISO8601DateFormatter()
        components.queryItems = [
            URLQueryItem(name: "date", value: formatter.string(from: date))
        ]
        
        let url = components.url!

        let response: BackendResponse<TeamWeekDTO> =
            try await RequestService.shared.getToBackend(url: url)

        print(response)
        switch response.statusCode {
        case 200:
            let teamWeek = TeamWeek(dto: response.data!)
            return teamWeek
        default:
            throw TeamError.backend(response.message)
        }
    }

    func NotifyTeam(slug: String) async throws {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "notify/team/\(slug)"
        )

        let response: BackendResponse<Empty> =
            try await RequestService.shared.postToBackend(url: url)

        print(response)
        switch response.statusCode {
        case 200:
            return
        default:
            throw NSError(
                domain: "",
                code: response.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: response.message
                ]
            )
        }
    }
}
