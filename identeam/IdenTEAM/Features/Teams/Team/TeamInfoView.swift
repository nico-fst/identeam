import SwiftUI

struct TeamInfoView: View {
    let team: Team

    var body: some View {
        NavigationStack {
            List {
                TextLabeled("Slug", team.slug)
                TextLabeled("Details", team.details)
            }
            .navigationTitle(team.name)
        }
    }
}
