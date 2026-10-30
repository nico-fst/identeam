import SwiftUI

struct TeamInfoView: View {
    let team: Team

    var body: some View {
        NavigationStack {
            List {
                Group {
                    TextLabeled("Slug", team.slug)
                    TextLabeled("Details", team.details)
                }
                .listRowBackground(AppColor.surface)
            }
            .appListColors()
            .navigationTitle(team.name)
        }
    }
}
