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
            try await RequestService.shared.postToBackend(url: url)

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
            try await RequestService.shared.postToBackend(url: url)

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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/week/\(formatter.string(from: date))"
        )

        let response: BackendResponse<TeamWeekDTO> =
            try await RequestService.shared.getToBackend(url: url)

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

        switch response.statusCode {
        case 200:
            return
        default:
            throw TeamError.backend(response.message)
        }
    }
    
    func createIdent(slug: String, text: String) async throws {
        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "idents/create"
        )
        
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "time": formatter.string(from: Date()),
            "teamSlug": slug,
            "userText": text
        ]

        let response: BackendResponse<IdentDTO> =
            try await RequestService.shared.putToBackend(url: url, payload: payload)

        switch response.statusCode {
        case 200:
            return
        default:
            throw TeamError.backend(response.message)
        }
    }

    func setTarget(slug: String, dateStart: Date, count: Int) async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let url = AppConfig.apiBaseURL.appendingPathComponent(
            "teams/\(slug)/targets/\(formatter.string(from: dateStart))"
        )
        let payload: [String: Any] = [
            "targetCount": count
        ]

        let response: BackendResponse<TargetDTO> =
            try await RequestService.shared.putToBackend(
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
