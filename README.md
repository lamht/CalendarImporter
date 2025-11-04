# Calendar Importer

## Overview
The Calendar Importer app allows users to import events from an ICS file and add them to their device's calendar. The app provides a user-friendly interface for selecting calendars and viewing event details.

## Features
- Load and parse ICS files to extract event data.
- Display a list of available calendars for selection.
- Show event details and allow users to add events to their calendar.

## Project Structure
```
CalendarImporter
├── CalendarImporter
│   ├── App
│   │   ├── AppDelegate.swift
│   │   └── SceneDelegate.swift
│   ├── Models
│   │   ├── CalendarEvent.swift
│   │   └── ICSParser.swift
│   ├── Views
│   │   ├── CalendarListView.swift
│   │   ├── EventDetailView.swift
│   │   └── ImportView.swift
│   ├── ViewModels
│   │   └── CalendarViewModel.swift
│   ├── Services
│   │   └── CalendarService.swift
│   └── Utilities
│       └── Constants.swift
├── CalendarImporterTests
│   └── CalendarImporterTests.swift
├── Info.plist
└── project.xcodeproj
```

## Setup Instructions
1. Clone the repository.
2. Open the `project.xcodeproj` file in Xcode.
3. Ensure you have the necessary permissions set in `Info.plist` for calendar access.
4. Build and run the app on a simulator or device.

## Usage
- Import an ICS file using the ImportView.
- Select a calendar from the list displayed in CalendarListView.
- View event details in EventDetailView and add events to your calendar.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any enhancements or bug fixes.