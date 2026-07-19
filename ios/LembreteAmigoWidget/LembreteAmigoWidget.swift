import WidgetKit
import SwiftUI
import HomeWidget

struct LembreteAmigoWidgetEntry: TimelineEntry {
    let date: Date
    let reminders: [ReminderData]
    let role: String
    let updatedAt: Date?
}

struct ReminderData: Codable {
    let id: String
    let title: String
    let hour: Int
    let minute: Int
    let category: String
    let priority: String?
    let status: String?

    var timeString: String { String(format: "%02d:%02d", hour, minute) }

    var icon: String {
        switch category {
        case "medicacao": return "\u{1F48A}"
        case "refeicao", "refeicoes": return "\u{1F37D}"
        case "exercicio": return "\u{1F3C3}"
        case "agua", "hidratacao": return "\u{1F4A7}"
        case "bem_estar": return "\u{1F60A}"
        default: return "\u{23F0}"
        }
    }

    var effectiveStatus: String {
        if status == "adiado" { return "adiado" }
        let calendar = Calendar.current
        let now = Date()
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let difference = hour * 60 + minute - nowMinutes
        if difference < -4 { return "atrasado" }
        if difference <= 1 { return "agora" }
        return "proximo"
    }

    var statusLabel: String {
        switch effectiveStatus {
        case "agora": return "AGORA"
        case "atrasado": return "ATRASADO"
        case "adiado": return "ADIADO"
        default: return ""
        }
    }

    var statusColor: Color {
        switch effectiveStatus {
        case "agora": return .yellow
        case "atrasado": return Color(red: 1, green: 0.8, blue: 0.82)
        case "adiado": return Color(red: 1, green: 0.88, blue: 0.7)
        default: return .white
        }
    }
}

struct LembreteAmigoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LembreteAmigoWidgetEntry {
        LembreteAmigoWidgetEntry(
            date: Date(),
            reminders: [
                ReminderData(id: "1", title: "Tomar remédio", hour: 8, minute: 0, category: "medicacao", priority: "alta", status: "agora"),
                ReminderData(id: "2", title: "Café da manhã", hour: 8, minute: 30, category: "refeicoes", priority: "normal", status: "proximo")
            ],
            role: "elderly",
            updatedAt: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LembreteAmigoWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LembreteAmigoWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> LembreteAmigoWidgetEntry {
        let role: String = HomeWidget.getWidgetData(key: "widget_role") ?? "elderly"
        let updatedText: String? = HomeWidget.getWidgetData(key: "widget_updated_at")
        let updatedAt = updatedText.flatMap { ISO8601DateFormatter().date(from: $0) }
        let data: String? = HomeWidget.getWidgetData(key: "reminders")
        let reminders = data
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([ReminderData].self, from: $0) } ?? []
        return LembreteAmigoWidgetEntry(date: Date(), reminders: reminders, role: role, updatedAt: updatedAt)
    }
}

struct LembreteAmigoWidgetEntryView: View {
    var entry: LembreteAmigoWidgetEntry

    private var genericURL: URL? {
        URL(string: "lembreteamigo://widget?role=\(entry.role)")
    }

    private func reminderURL(_ reminder: ReminderData) -> URL? {
        var components = URLComponents()
        components.scheme = "lembreteamigo"
        components.host = "widget"
        components.queryItems = [
            URLQueryItem(name: "id", value: reminder.id),
            URLQueryItem(name: "role", value: entry.role)
        ]
        return components.url
    }

    private var updatedLabel: String {
        guard let updatedAt = entry.updatedAt else { return "Últimos dados disponíveis" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Atualizado às \(formatter.string(from: updatedAt))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Próximos lembretes")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            if entry.reminders.isEmpty {
                Spacer()
                Text("Nenhum lembrete pendente")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(Array(entry.reminders.prefix(3)), id: \.id) { reminder in
                    Link(destination: reminderURL(reminder) ?? genericURL!) {
                        HStack(spacing: 6) {
                            Text(reminder.timeString)
                                .font(.system(size: 13, weight: .bold))
                                .frame(minWidth: 42, alignment: .leading)
                            Text(reminder.icon).font(.system(size: 13))
                            Text(reminder.statusLabel.isEmpty ? reminder.title : "\(reminder.statusLabel) • \(reminder.title)")
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundColor(reminder.statusColor)
                        .padding(.vertical, 2)
                    }
                }
            }

            Text(updatedLabel)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .widgetURL(genericURL)
        .containerBackground(for: .widget) {
            Color(red: 21/255, green: 101/255, blue: 192/255)
        }
    }
}

struct LembreteAmigoWidget: Widget {
    let kind = "LembreteAmigoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LembreteAmigoWidgetProvider()) { entry in
            LembreteAmigoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Lembrete Amigo")
        .description("Mostra seus próximos lembretes pendentes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct LembreteAmigoWidgetBundle: WidgetBundle {
    var body: some Widget { LembreteAmigoWidget() }
}
