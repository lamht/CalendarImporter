import SwiftUI

struct CalendarListView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        NavigationView {
            List(viewModel.calendars, id: \.self) { calendar in
                NavigationLink(destination: EventDetailView(calendar: calendar)) {
                    Text(calendar)
                }
            }
            .navigationTitle("Select a Calendar")
        }
        .onAppear {
            viewModel.loadCalendars()
        }
    }
}

struct CalendarListView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarListView(viewModel: CalendarViewModel())
    }
}