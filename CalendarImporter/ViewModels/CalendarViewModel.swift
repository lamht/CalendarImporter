class CalendarViewModel: ObservableObject {
    @Published var calendars: [String] = []
    @Published var events: [CalendarEvent] = []
    
    func loadCalendars() {
        // Logic to load calendars from the device
    }
    
    func loadEvents(from icsFile: String) {
        // Logic to parse ICS file and load events
    }
    
    func addEventToCalendar(event: CalendarEvent) {
        // Logic to add event to the selected calendar
    }
}