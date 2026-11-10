import Foundation
import NotchCore

@MainActor final class PlannerConnection: ObservableObject {
    @Published var models: [String] = []
    @Published var status = "Start Ollama, then check the connection."
    @Published var checking = false
    func check(_ configuration: PlannerConfiguration) {
        guard !checking else { return }
        checking = true; models = []; status = "Connecting…"
        Task {
            defer { checking = false }
            do {
                let chat = try LocalPlanner.endpoint(configuration)
                var parts = URLComponents(url: chat, resolvingAgainstBaseURL: false)!
                parts.path = configuration.openAICompatible ? "/v1/models" : "/api/tags"
                var request = URLRequest(url: parts.url!); request.timeoutInterval = 5
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count < 1_000_000 else { throw PlanError.invalidResponse }
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let rows = object?[configuration.openAICompatible ? "data" : "models"] as? [[String: Any]] ?? []
                models = rows.compactMap { $0[configuration.openAICompatible ? "id" : "name"] as? String }.sorted()
                status = models.isEmpty ? "Connected, but no installed models were found." : "Connected · \(models.count) models available"
            } catch { status = "Cannot connect. Keep Ollama running, or start it with ollama serve. Check the address and try again." }
        }
    }
}
