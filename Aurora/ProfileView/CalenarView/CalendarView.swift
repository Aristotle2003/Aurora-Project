import SwiftUI
import Firebase

// MARK: - Message Model
struct Message: Hashable {
    let id: String // Unique message ID
    let sender: String
    let text: String
    let timestamp: Date
    let fromId: String
    let toId: String
}

// Date formatter for displaying timestamps
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - MessagesViewModel
class MessagesViewModel: ObservableObject {
    @Published var messagesByDate: [Date: [Message]] = [:]
    @Published var errorMessage: String?

    func searchSavedMessages(fromId: String, toId: String) {
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .getDocuments { (snapshot, error) in
                if let error = error {
                    self.errorMessage = "Failed to fetch messages: \(error)"
                    return
                }

                var messagesByDate: [Date: [Message]] = [:]
                snapshot?.documents.forEach { document in
                    let data = document.data()
                    let id = document.documentID
                    let sender = data["sender"] as? String ?? ""
                    let text = data["text"] as? String ?? ""
                    let timestamp = data["timestamp"] as? Timestamp ?? Timestamp()
                    let fromId = data["fromId"] as? String ?? ""
                    let toId = data["toId"] as? String ?? ""
                    let date = timestamp.dateValue()

                    let message = Message(id: id, sender: sender, text: text, timestamp: date, fromId: fromId, toId: toId)

                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    if let messageDate = calendar.date(from: components) {
                        if messagesByDate[messageDate] == nil {
                            messagesByDate[messageDate] = []
                        }
                        messagesByDate[messageDate]?.append(message)
                    }
                }

                self.messagesByDate = messagesByDate
            }
    }
}

// MARK: - CalendarMessagesView
struct CalendarMessagesView: View {
    @ObservedObject var messagesViewModel: MessagesViewModel
    @State private var selectedDate: Date? = nil
    @State private var isEditing: Bool = false
    @State private var selectedMessages: Set<Message> = []
    @Environment(\.dismiss) var dismiss
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    var body: some View {
        ZStack{
            Color(red: 0.976, green: 0.980, blue: 1.0)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("chatlogviewbackbutton") // Replace with your back button image
                            .resizable()
                            .frame(width: 24, height: 24) // Customize this color
                    }
                    Spacer()
                    Text("Chat History Calendar")
                        .font(.system(size: 20, weight: .bold)) // Customize font style
                        .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255)) // Customize text color
                    Spacer()
                    Image("spacerformainmessageviewtopleft") // Replace with your back button image
                        .resizable()
                        .frame(width: 24, height: 24) // To balance the back button
                }
                .padding()
                .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                // Calendar UI
                Spacer()
                    .frame(height: 30)
                
                CalendarView(selectedDate: $selectedDate,
                             savedDates: Set(messagesViewModel.messagesByDate.keys))
    
                
                // Edit Button
                HStack {
                    if isEditing {
                        Button("Delete") {
                            deleteSelectedMessages()
                            generateHapticFeedbackMedium()
                        }
                        .disabled(selectedMessages.isEmpty)
                        .foregroundColor(selectedMessages.isEmpty ? .gray : Color(red: 125/255, green: 133/255, blue: 191/255)) // Button color
                        .padding()
                    }
                    
                    Spacer()
                    
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                        if !isEditing {
                            selectedMessages.removeAll()
                        }
                        generateHapticFeedbackMedium()
                    }
                    .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255)) // Button color
                    .padding()
                }

                
                // Display messages for the selected date
                if let selectedDate = selectedDate {
                    if let messages = messagesViewModel.messagesByDate[selectedDate] {
                        List(messages.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { message in
                            HStack {
                                if isEditing {
                                    Button(action: {
                                        toggleMessageSelection(message)
                                        generateHapticFeedbackMedium()
                                    }) {
                                        Image(systemName: selectedMessages.contains(message) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                                    }
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(message.sender)
                                        .font(.headline)
                                        .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                                    Text(message.text)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text("\(message.timestamp, formatter: dateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    } else {
                        Text("No messages were saved this day")
                            .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                            .padding()
                    }
                } else {
                    Text("Select a date to see messages")
                        .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                        .padding()
                }
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // Toggle message selection in edit mode
    private func toggleMessageSelection(_ message: Message) {
        if selectedMessages.contains(message) {
            selectedMessages.remove(message)
        } else {
            selectedMessages.insert(message)
        }
    }

    // Delete selected messages
    private func deleteSelectedMessages() {
        guard let selectedDate = selectedDate else { return }
        guard let messagesToDelete = messagesViewModel.messagesByDate[selectedDate]?.filter({ selectedMessages.contains($0) }) else { return }

        // Delete messages from Firestore
        for message in messagesToDelete {
            deleteMessageFromFirestore(message)
        }

        // Remove messages locally
        messagesViewModel.messagesByDate[selectedDate]?.removeAll(where: { selectedMessages.contains($0) })
        selectedMessages.removeAll()
    }

    // Firestore deletion logic
    private func deleteMessageFromFirestore(_ message: Message) {
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(message.fromId)
            .collection(message.toId)
            .document(message.id)
            .delete { error in
                if let error = error {
                    print("Error deleting message: \(error)")
                } else {
                    print("Message deleted successfully")
                }
            }
    }
}


struct CalendarView: View {
    @Binding public var selectedDate: Date?
    let savedDates: Set<Date>
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public init(selectedDate: Binding<Date?>, savedDates: Set<Date>) {
        self._selectedDate = selectedDate
        self.savedDates = savedDates
    }
    
    @State private var currentMonth: Date = {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }()
    
    private var calendar = Calendar.current
    
    // Maximum date: current month start
    private var maxDate: Date {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }
    
    // Minimum date: three years ago from the maxDate (also month start)
    private var minDate: Date {
        calendar.date(byAdding: .year, value: -3, to: maxDate)!
    }
    
    var body: some View {
        VStack {
            // Month navigation bar
            HStack {
                Spacer()
                    .frame(width: 80)
                Button(action: {
                    moveToPreviousMonth()
                    generateHapticFeedbackMedium()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                }
                .disabled(!canMoveToPreviousMonth())
                
                Spacer()
                
                Text("\(currentMonth, formatter: yearMonthFormatter)")
                    .font(.headline)
                    .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                    
                
                Spacer()
                
                Button(action: {
                    moveToNextMonth()
                    generateHapticFeedbackMedium()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                }
                .disabled(!canMoveToNextMonth())
                
                Spacer()
                    .frame(width: 80)
            }
            .padding(.horizontal)
            
            Spacer()
                .frame(height: 20)
            
            // Days of the Week Header
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                }
            }
            
            let days = generateDaysInMonth(for: currentMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(days, id: \.self) { day in
                    if let day = day {
                        Button(action: {
                            selectedDate = day
                            generateHapticFeedbackMedium()
                        }) {
                            let dayNumber = calendar.component(.day, from: day)
                            let backgroundColor: Color = {
                                if let selected = selectedDate, calendar.isDate(selected, inSameDayAs: day) {
                                    return Color(red: 229/255, green: 232/255, blue: 254/255)
                                } else if savedDates.contains(day) {
                                    return Color.yellow.opacity(0.3)
                                } else {
                                    return Color.clear
                                }
                            }()
                            Text("\(dayNumber)")
                                .foregroundColor(Color(red: 125 / 255, green: 133 / 255, blue: 191 / 255))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(backgroundColor)
                                .cornerRadius(10)
                        }
                    } else {
                        Text("") // Empty placeholder for padding days
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
            .padding()
        }
    }
    
    // Formatter for displaying year-month (e.g. "Dec 2024")
    private let yearMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL yyyy"
        return formatter
    }()
    
    // Days of the week
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        var days: [Date?] = []
        let range = calendar.range(of: .day, in: .month, for: date)!
        
        // Get the first day of the month
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let weekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        
        // Add padding for days before the first day of the month
        days.append(contentsOf: Array(repeating: nil, count: weekday))
        
        // Add all days in the current month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }
    
    private func moveToPreviousMonth() {
        guard canMoveToPreviousMonth() else { return }
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func moveToNextMonth() {
        guard canMoveToNextMonth() else { return }
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func canMoveToPreviousMonth() -> Bool {
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            return previousMonth >= minDate
        }
        return false
    }
    
    private func canMoveToNextMonth() -> Bool {
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            return nextMonth <= maxDate
        }
        return false
    }
}
