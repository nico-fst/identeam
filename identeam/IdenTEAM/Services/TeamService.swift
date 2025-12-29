//
//  AuthService.swift
//  identeam
//
//  Created by Nico Stern on 15.12.25.
//

import Foundation
import SwiftData
import SwiftUI

class TeamService {
    @AppStorage("sessionToken") private var sessionToken: String = ""

    static let shared = TeamService()

    struct GetMyTeamsResponse: Decodable {
        let teams: [TeamDecodable]
    }

    func getMyTeams() async throws -> [Team] {
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
        let user: User
        let team: TeamDecodable
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
