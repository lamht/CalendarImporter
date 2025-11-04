import SwiftUI
import EventKit
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var selectedFile: URL?
    @State private var isImporting: Bool = false

    // new state
    @State private var parsedEvents: [ICSParsedEvent] = []
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendarID: String?
    @State private var isProcessing: Bool = false
    @State private var message: String?

    private let eventStore = EKEventStore()

    var body: some View {
        VStack {
            Text("Import ICS File")
                .font(.largeTitle)
                .padding()

            Button(action: {
                isImporting = true
            }) {
                Text("Select ICS File")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [UTType(filenameExtension: "ics") ?? .plainText]
            ) { result in
                switch result {
                case .success(let url):
                    selectedFile = url
                    loadAndParseICS(url: url)
                case .failure(let error):
                    message = "Error importing file: \(error.localizedDescription)"
                }
            }

            if let file = selectedFile {
                Text("Selected File: \(file.lastPathComponent)")
                    .padding(.top, 8)
            }

            if !parsedEvents.isEmpty {
                Text("Found \(parsedEvents.count) event(s)")
                    .padding(.top, 8)

                if calendars.isEmpty {
                    Button("Load Calendars") {
                        requestCalendarAccessAndLoad()
                    }
                    .padding(.top, 8)
                } else {
                    Picker("Choose Calendar", selection: $selectedCalendarID) {
                        ForEach(calendars, id: \.calendarIdentifier) { cal in
                            Text(cal.title).tag(cal.calendarIdentifier as String?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.top, 8)

                    Button(action: {
                        addParsedEventsToSelectedCalendar()
                    }) {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("Import to Calendar")
                        }
                    }
                    .disabled(selectedCalendarID == nil || isProcessing)
                    .padding(.top, 12)
                }
            }

            if let msg = message {
                Text(msg)
                    .foregroundColor(.secondary)
                    .padding(.top, 12)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            // optional: preload calendars if permission already granted
            if EKEventStore.authorizationStatus(for: .event) == .authorized {
                loadCalendars()
            }
        }
    }

    // MARK: - ICS parsing and calendar operations

    func loadAndParseICS(url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                    DispatchQueue.main.async { message = "Unable to read file contents." }
                    return
                }
                let events = ICSParser.parseEvents(from: text)
                DispatchQueue.main.async {
                    parsedEvents = events
                    message = events.isEmpty ? "No events found in ICS." : "Parsed \(events.count) event(s)."
                    // When parsed, try load calendars (requesting permission if needed)
                    requestCalendarAccessAndLoad()
                }
            } catch {
                DispatchQueue.main.async {
                    message = "Failed to load file: \(error.localizedDescription)"
                }
            }
        }
    }

    func requestCalendarAccessAndLoad() {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    loadCalendars()
                    message = "Calendar access granted."
                } else {
                    message = "Calendar access denied."
                }
            }
        }
    }

    func loadCalendars() {
        let cals = eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
        calendars = cals
        if selectedCalendarID == nil {
            selectedCalendarID = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        }
    }

    func addParsedEventsToSelectedCalendar() {
        guard let calID = selectedCalendarID,
              let calendar = calendars.first(where: { $0.calendarIdentifier == calID })
        else {
            message = "No calendar selected."
            return
        }

        isProcessing = true
        message = "Importing..."

        DispatchQueue.global(qos: .userInitiated).async {
            var added = 0
            var failed = 0

            for e in parsedEvents {
                let event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                event.title = e.title
                event.location = e.location
                event.notes = e.notes
                event.startDate = e.startDate
                event.endDate = e.endDate ?? e.startDate.addingTimeInterval(3600)

                do {
                    try eventStore.save(event, span: .thisEvent)
                    added += 1
                } catch {
                    failed += 1
                }
            }

            DispatchQueue.main.async {
                isProcessing = false
                message = "Imported: \(added). Failed: \(failed)."
            }
        }
    }
}

// MARK: - Simple ICS model + parser (keeps parser local for simplicity)

struct ICSParsedEvent {
    var title: String
    var startDate: Date
    var endDate: Date?
    var location: String?
    var notes: String?
}

enum ICSParser {
    static func parseEvents(from icsText: String) -> [ICSParsedEvent] {
        var results: [ICSParsedEvent] = []
        let lines = icsText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var currentEventLines: [String] = []
        var inEvent = false

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.uppercased().hasPrefix("BEGIN:VEVENT") {
                inEvent = true
                currentEventLines = []
                continue
            } else if line.uppercased().hasPrefix("END:VEVENT") {
                inEvent = false
                if let ev = parseEventBlock(lines: currentEventLines) {
                    results.append(ev)
                }
                currentEventLines = []
                continue
            }

            if inEvent {
                // handle folded lines (lines that start with space are continuation)
                if line.hasPrefix(" ") || line.hasPrefix("\t"), let last = currentEventLines.popLast() {
                    currentEventLines.append(last + line.trimmingCharacters(in: .whitespaces))
                } else {
                    currentEventLines.append(line)
                }
            }
        }

        return results
    }

    private static func parseEventBlock(lines: [String]) -> ICSParsedEvent? {
        var title: String = "Untitled"
        var dtstartRaw: String?
        var dtendRaw: String?
        var location: String?
        var notes: String?

        for line in lines {
            if line.uppercased().hasPrefix("SUMMARY:") {
                title = String(line.dropFirst("SUMMARY:".count))
            } else if line.uppercased().starts(with: "DTSTART") {
                if let idx = line.firstIndex(of: ":") {
                    dtstartRaw = String(line[line.index(after: idx)...])
                }
            } else if line.uppercased().starts(with: "DTEND") {
                if let idx = line.firstIndex(of: ":") {
                    dtendRaw = String(line[line.index(after: idx)...])
                }
            } else if line.uppercased().hasPrefix("LOCATION:") {
                location = String(line.dropFirst("LOCATION:".count))
            } else if line.uppercased().hasPrefix("DESCRIPTION:") {
                notes = String(line.dropFirst("DESCRIPTION:".count))
            }
        }

        guard let dtstart = dtstartRaw, let startDate = parseICSDate(dtstart) else {
            return nil
        }
        let endDate = dtendRaw.flatMap { parseICSDate($0) }

        return ICSParsedEvent(title: title, startDate: startDate, endDate: endDate, location: location, notes: notes)
    }

    private static func parseICSDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // possible formats:
        // 20251104T090000Z
        // 20251104T090000
        // 20251104

        let fmts = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd"
        ]

        for fmt in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            if fmt.hasSuffix("'Z'") {
                df.timeZone = TimeZone(secondsFromGMT: 0)
            } else {
                df.timeZone = TimeZone.current
            }
            df.dateFormat = fmt
            if let d = df.date(from: s) {
                return d
            }
        }

        return nil
    }
}