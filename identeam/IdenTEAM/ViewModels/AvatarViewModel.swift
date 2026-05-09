//
//  AvatarViewModel.swift
//  identeam
//
//  Created by Nico Stern on 09.05.26.
//

import Combine
import Foundation
import SwiftData

@MainActor
class AvatarViewModel: ObservableObject {
    @Published var isUploadingAvatar = false
    @Published var uploadError: String?

    private let api: AvatarAPI

    init(api: AvatarAPI) {
        self.api = api
    }

    convenience init() {
        self.init(api: .shared)
    }

    func refreshAvatarIfNeeded(avatars: [Avatar], ctx: ModelContext) async throws {
        guard let localAvatar = avatars.first,
              !localAvatar.isExpired
        else {
            try await refreshAvatar(avatars: avatars, ctx: ctx)
            return
        }
        
        let remoteAvatar = try await api.fetchMe().avatar
        guard let remoteAvatar else {
            try await refreshAvatar(avatars: avatars, ctx: ctx)
            return
        }
        
        guard remoteAvatar.key != localAvatar.key else {
            return
        }
        
        try await refreshAvatar(avatars: avatars, ctx: ctx)
    }
    
    func refreshAvatar(avatars: [Avatar], ctx: ModelContext) async throws {
        let resp = try await api.fetchMe()
        
        for avatar in avatars {
            ctx.delete(avatar)
        }
        
        if let remoteAvatarDTO = resp.avatar {
            let remoteAvatar = Avatar(dto: remoteAvatarDTO)
            ctx.insert(remoteAvatar)
        }
        
        try ctx.save()
    }
    
    func propagateAvatarUpdate(
        _ item: IdentifiableImage,
        avatars: [Avatar],
        ctx: ModelContext
    ) async -> Bool {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        uploadError = nil
        
        do {
            try await api.uploadAvatar(
                imageData: item.imageData,
                contentType: "image/jpeg"
            )
            try await refreshAvatar(avatars: avatars, ctx: ctx)
            return true
        } catch {
            uploadError = error.localizedDescription
            return false
        }
    }
}
