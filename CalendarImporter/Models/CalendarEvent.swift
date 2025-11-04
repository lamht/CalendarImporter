class CalendarEvent {
    var title: String
    var date: Date
    var location: String?

    init(title: String, date: Date, location: String? = nil) {
        self.title = title
        self.date = date
        self.location = location
    }
}