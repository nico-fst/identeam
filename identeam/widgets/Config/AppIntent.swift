import AppIntents
import SwiftData
import WidgetKit

struct TeamEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Team")
    static var defaultQuery = TeamEntityQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TeamEntityQuery: EntityQuery {
    func suggestedEntities() async throws -> [TeamEntity] {
        let container = await SharedModelConfig.makeContainer(for: .widget)
        let context = ModelContext(container)

        let teams = try context.fetch(FetchDescriptor<Team>())

        return teams.map {
            TeamEntity(id: $0.slug, name: $0.name)
        }
    }

    // AppIntents need this to resolve selected teams later
    func entities(for identifiers: [TeamEntity.ID]) async throws -> [TeamEntity] {
        try await suggestedEntities()
            .filter { identifiers.contains($0.id) }
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "not displayed"
    static var description = IntentDescription("not displayed")

    @Parameter(title: "Team")
    var team: TeamEntity?
}
