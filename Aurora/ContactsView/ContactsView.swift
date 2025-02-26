import SwiftUI
import FirebaseCore
import SDWebImageSwiftUI

class CreateNewMessageViewModel: ObservableObject {
    
    @Published var users = [ChatUser]()          // Stores all fetched friends
    @Published var currentUser: ChatUser?
    @Published var filteredUsers = [ChatUser]()  // Stores search results
    @Published var isLoading = false
    @Published var errorMessage = ""             // Stores error messages
    @Published var searchText = "" {             // Stores current search query
        didSet {
            filterUsers()
        }
    }
    @FocusState private var isFocused: Bool
    
    init() {
        fetchAllFriends()
        fetchCurrentUser()
    }
    
    func fetchAllFriends() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        isLoading = true
        
        FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
            .getDocuments { documentsSnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch friends: \(error)"
                    return
                }
                
                self.users.removeAll()
                
                documentsSnapshot?.documents.forEach({ snapshot in
                    let data = snapshot.data()
                    let user = ChatUser(data: data)
                    self.users.append(user)
                })
                
                // Sort users by the first letter of their email
                self.users.sort { $0.username.lowercased() < $1.username.lowercased() }
                self.isLoading = false
                
                // Initialize filtered users with all users
                self.filterUsers()
            }
    }
    
    func filterUsers() {
        if searchText.isEmpty {
            filteredUsers = users // Show all friends if search text is empty
        } else {
            filteredUsers = users.filter { user in
                let username = user.username.lowercased()
                let searchQuery = searchText.lowercased()
                return username.contains(searchQuery)
            }
        }
    }
    
    // Function to refresh users after adding a new friend
    func refreshUsers() {
        fetchAllFriends()
    }
    
    // Group users by the first letter of their email
    func groupedUsers() -> [String: [ChatUser]] {
        Dictionary(grouping: filteredUsers) { user in
            let firstLetter = String(user.username.prefix(1)).uppercased()
            let regex = try! NSRegularExpression(pattern: "^[A-Z]$")
            let range = NSRange(location: 0, length: firstLetter.utf16.count)
            if regex.firstMatch(in: firstLetter, options: [], range: range) != nil {
                return firstLetter
            } else {
                return "#"
            }
        }
    }
    
    func fetchCurrentUser() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch current user: \(error)"
                print("Failed to fetch current user:", error)
                return
            }
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
            }
            
            DispatchQueue.main.async {
                self.currentUser = ChatUser(data: data)
            }
        }
    }
}

struct CreateNewMessageView: View {
    @StateObject private var vm = CreateNewMessageViewModel()
    @State private var isShowingAddFriendView = false
    @State private var isShowingCreateGroupChatView = false // New state variable
    @State private var navigateToProfile = false
    @State private var chatUser: ChatUser? = nil
    @State private var currentUser: ChatUser? = nil
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    @FocusState private var isFocused: Bool
    
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
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isFocused = false
                    }
                
                VStack {
                    topBar
                    SearchBar(text: $vm.searchText) {
                        vm.filterUsers()
                    }
                    .focused($isFocused)
                    .padding(.vertical, 4)
                    
                    content
                }
                .navigationBarHidden(true)
                
            }
            .fullScreenCover(isPresented: $isShowingAddFriendView) {
                AddFriendView()
            }
            // Full screen cover for group chat creation
            .fullScreenCover(isPresented: $isShowingCreateGroupChatView) {
                CreateGroupView()
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                if let chatUser = self.chatUser, let currentUser = self.currentUser {
                    ProfileView(
                        chatUser: chatUser,
                        currentUser: currentUser,
                        isCurrentUser: false
                    )
                } else {
                    Text("Loading Profile...") // Fallback if navigation occurs prematurely
                }
            }
            .onAppear {
                vm.fetchCurrentUser()
            }
            .navigationBarHidden(true)
        }
        .navigationBarHidden(true)
    }
    
    var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets.top ?? 0
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        ZStack {
            Image("liuhaier")
                .resizable()
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.07 + safeAreaTopInset)
                .aspectRatio(nil, contentMode: .fill)
                .ignoresSafeArea()
            HStack {
                // Left side: Group Chat Button
                Button(action: {
                    isShowingCreateGroupChatView = true
                    generateHapticFeedbackMedium()
                }) {
                    Image("creategroupbutton")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(.leading, 28)
                }
                Spacer()
                Image("contactsheadlinetext")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width * 0.1832, height: UIScreen.main.bounds.height * 0.0198)
                Spacer()
                Button(action: { isShowingAddFriendView = true
                    generateHapticFeedbackMedium()
                }) {
                    Image("addfriendbutton")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(.trailing, 28)
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.07)
    }
    
    // MARK: - Content
    private var content: some View {
        ScrollView {
            if vm.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.top, UIScreen.main.bounds.height * 0.3)
                    Text("Loading friends...")
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                    Spacer()
                }
            }
            else if !vm.errorMessage.isEmpty {
                Text(vm.errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if vm.filteredUsers.isEmpty {
                Image("lonelyimageforcontactspage")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(vm.groupedUsers().keys.sorted(), id: \.self) { key in
                        Section(header: sectionHeader(key)) {
                            ForEach(vm.groupedUsers()[key]!) { user in
                                userRow(user)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                Spacer(minLength: UIScreen.main.bounds.height * 0.1)
            }
        }
        .onTapGesture{
            isFocused = false
        }
    }
    
    // MARK: - Section Header
    private func sectionHeader(_ key: String) -> some View {
        HStack {
            Text(key)
                .font(.headline.bold())
                .foregroundColor(.gray)
                .padding(.leading, 20)
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - User Row
    private func userRow(_ user: ChatUser) -> some View {
        Button {
            self.chatUser = user
            self.currentUser = vm.currentUser
            navigateToProfile = true
            generateHapticFeedbackMedium()
        } label: {
            ZStack {
                Image("contactsbubble")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                HStack(spacing: 16) {
                    WebImage(url: URL(string: user.profileImageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 45, height: 45)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                        if let timestamp = user.latestMessageTimestamp {
                            Text(formatTimestamp(timestamp))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 0)
        }
    }
    
    // MARK: - Format Timestamp
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let weekdaySymbols = Calendar.current.weekdaySymbols
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            return weekdaySymbols[weekdayIndex]
        } else {
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void  // Callback for the search action
    // @FocusState private var isFocused: Bool
    
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
        HStack {
            Spacer()
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            // Search input field
            TextField("Search friends by username", text: $text)
                .font(.system(size: 14)) // Set font size
                .foregroundColor(.gray)
                .submitLabel(.search) // Enable "Search" key on keyboard
                .onSubmit {
                    onSearch()  // Trigger search when "Search" key is pressed
                }
            // .onTapGesture {
            //     isFocused = true
            // }
            
            
            // Clear button (conditionally shown)
            if !text.isEmpty {
                Button(action: {
                    text = ""  // Clear search text
                    onSearch()  // Trigger search after clearing
                    generateHapticFeedbackMedium()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10) // Add padding inside the search bar
        .background(
            RoundedRectangle(cornerRadius: 20) // Round corners
                .fill(Color.white) // White background
            
        )
        .frame(maxWidth: .infinity) // Centralized horizontally
        .padding(.horizontal, 20) // Add spacing from edges
    }
}


