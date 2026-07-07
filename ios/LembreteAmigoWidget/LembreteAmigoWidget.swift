import WidgetKit
import SwiftUI
import HomeWidget

struct LembreteAmigoWidgetEntry: TimelineEntry {
    let date: Date
    let reminders: [ReminderData]
}

struct ReminderData: Codable {
    let id: String
    let title: String
    let hour: Int
    let minute: Int
    let category: String
    let priority: String

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var icon: String {
        switch category {
        case "medicacao": return "💊"
        case "refeicao": return "🍽"
        case "exercicio": return "🏃"
        case "agua": return "💧"
        case "bem_estar": return "😊"
        default: return "⏰"
        }
    }
}

struct LembreteAmigoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LembreteAmigoWidgetEntry {
        LembreteAmigoWidgetEntry(
            date: Date(),
            reminders: [
                ReminderData(id: "1", title: "Tomar remédio", hour: 8, minute: 0, category: "medicacao", priority: "alta"),
                ReminderData(id: "2", title: "Café da manhã", hour: 8, minute: 30, category: "refeicao", priority: "normal")
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LembreteAmigoWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LembreteAmigoWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> LembreteAmigoWidgetEntry {
        guard let data = HomeWidget.getWidgetData(key: "reminders") else {
            return LembreteAmigoWidgetEntry(date: Date(), reminders: [])
        }

        if let jsonData = data.data(using: .utf8),
           let reminders = try? JSONDecoder().decode([ReminderData].self, from: jsonData) {
            return LembreteAmigoWidgetEntry(date: Date(), reminders: reminders)
        }

        return LembreteAmigoWidgetEntry(date: Date(), reminders: [])
    }
}

struct LembreteAmigoWidgetEntryView: View {
    var entry: LembreteAmigoWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Próximos Lembretes")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 4)

            if entry.reminders.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Nenhum lembrete pendente")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(entry.reminders.prefix(3).enumerated()), id: \.element.id) { index, reminder in
                    HStack(spacing: 6) {
                        Text(reminder.timeString)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 42, alignment: .leading)

                        Text(reminder.icon)
                            .font(.system(size: 13))

                        Text(reminder.title)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if reminder.priority == "alta" {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(red: 21/255, green: 101/255, blue: 192/255)
        }
    }
}

struct LembreteAmigoWidget: Widget {
    let kind: String = "LembreteAmigoWidget"

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
    var body: some Widget {
        LembreteAmigoWidget()
    }
}
