import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseMessaging
import FirebaseAuth

struct RecentMessage: Identifiable{
    var id: String{documentId}
    let text, fromId, toId: String
    let timestamp: Timestamp
    let documentId: String
    let email, profileImageUrl: String
    
    init(documentId: String, data:[String: Any]){
        
        self.documentId = documentId
        self.text = data["text"] as? String ?? ""
        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
        self.fromId = data["fromId"] as? String ?? ""
        self.toId = data["toId"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
    }
}

class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    @Published var users = [ChatUser]()

    var messageListener: ListenerRegistration?
    var friendRequestListener: ListenerRegistration? // 新增好友申请监听器变量
    var friendGroupListener: ListenerRegistration?

    @Published var recentMessages = [RecentMessage]()
    @Published var hasNewFriendRequest = false // 用于跟踪是否有新的好友申请
    @Published var hasNewFriendGroup = false // 用于跟踪是否有新的朋友圈消息
    @AppStorage("lastCheckedTimestamp") var lastCheckedTimestamp: Double = 0
    @AppStorage("lastLikesCount") var lastLikesCount: Int = 0

    init() {
        
        DispatchQueue.main.async{
            self.isUserCurrentlyLoggedOut =
            FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        setupFriendListListener()
        setupFriendRequestListener()  // 设置好友申请监听器
    }

//    func setupFriendGroupListener() {
//        guard let currentUserUid = FirebaseManager.shared.auth.currentUser?.uid else {
//            self.errorMessage = "Could not find firebase uid"
//            return
//        }
//
//        // 如果已有监听器，先移除
//        friendGroupListener?.remove()
//        friendGroupListener = nil
//
//        // double to int64
//        let lastCheckedTimestampInt64 = Int64(lastCheckedTimestamp)
//
//        friendGroupListener = FirebaseManager.shared.firestore
//            .collection("response_to_prompt")
//            .whereField("timestamp", isGreaterThan: Timestamp(seconds: lastCheckedTimestampInt64, nanoseconds: 0))
//            .addSnapshotListener { [weak self] snapshot, error in
//                if let error = error {
//                    print("Failed to listen for friend group messages and likes: \(error)")
//                    return
//                }
//                
//                guard let documents = snapshot?.documents else { return }
//                var hasNewLikes = false
//                var hasNewFriendGroupUpdates = false
//
//                // Fetch friend list
//                self?.fetchFriendList { friendUIDs in
//                    for document in documents {
//                        let data = document.data()
//                        let authorUid = data["uid"] as? String ?? ""
//                        let documentId = document.documentID
//                        let likes = data["likes"] as? Int ?? 0
//
//                        // 检查朋友圈更新
//                        if friendUIDs.contains(authorUid) && authorUid != currentUserUid {
//                            hasNewFriendGroupUpdates = true
//                        }
//
//                        // 检查点赞更新
//                        if authorUid == currentUserUid {
//                            if likes > self?.lastLikesCount ?? 0 {
//                                hasNewLikes = true
//                                self?.lastLikesCount = likes
//                            }
//                            self?.lastLikesCount = likes
//                        }
//                    }
//
//                    DispatchQueue.main.async {
//                        self?.hasNewFriendGroup = (hasNewFriendGroupUpdates || hasNewLikes)
//                    }
//                }
//            }
//    }

    func fetchAndStoreFCMToken() {
        guard let userID = FirebaseManager.shared.auth.currentUser?.uid else {
                print("User not signed in.")
                return
            }
            
            Messaging.messaging().token { token, error in
                if let token = token {
                    self.storeFCMTokenToFirestore(token, userID: userID)
                    print("Fetched and stored FCM Token: \(token)")
                } else if let error = error {
                    print("Error fetching FCM token: \(error)")
                }
            }
        }
        
    private func storeFCMTokenToFirestore(_ token: String, userID: String) {
        let userRef = Firestore.firestore().collection("users").document(userID)
        userRef.setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("Error updating FCM token in Firestore: \(error)")
            } else {
                print("FCM token updated successfully in Firestore.")
            }
        }
    }

    func setupFriendListListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }

        messageListener?.remove()
        messageListener = nil

        messageListener = FirebaseManager.shared.firestore
            .collection("friends")
            .document(uid)
            .collection("friend_list")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for friend list changes: \(error)"
                    print("Failed to listen for friend list changes: \(error)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    self.errorMessage = "No friend list documents found"
                    return
                }

                DispatchQueue.global(qos: .background).async {
                    var users: [ChatUser] = []

                    for document in documents {
                        let data = document.data()
                        let user = ChatUser(data: data)
                        if user.uid != uid {
                            users.append(user)
                        }
                    }

                    // 分组并排序
                    let pinnedUsers = users.filter { $0.isPinned }.sorted {
                        ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }

                    let unpinnedUsers = users.filter { !$0.isPinned }.sorted {
                        ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }

                    DispatchQueue.main.async {
                        self.users = pinnedUsers + unpinnedUsers
                    }
                }
            }
    }

    func setupFriendRequestListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }

        friendRequestListener?.remove()
        friendRequestListener = nil

        friendRequestListener = FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(uid)
            .collection("request_list")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Failed to listen for friend requests: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    // 如果有未处理的好友申请，设置 hasNewFriendRequest 为 true
                    self?.hasNewFriendRequest = !documents.isEmpty
                }
            }
    }

    func fetchFriendList(completion: @escaping ([String]) -> Void) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }

        FirebaseManager.shared.firestore
            .collection("friends")
            .document(uid)
            .collection("friend_list")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Failed to fetch friend list: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No friend list documents found")
                    return
                }

                let friendUIDs = documents.map { $0.documentID }
                completion(friendUIDs)
            }
    }

    func stopListening() {
        
        messageListener?.remove()
        messageListener = nil
        friendRequestListener?.remove()
        friendRequestListener = nil
    }

    private func fetchCurrentUser() {
        
        
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
                self.chatUser = ChatUser(data: data)
            }
        }
    }
    
    func markMessageAsSeen(for userId: String) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        // Reference to the user's friend list
        let friendRef = FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUserId)
            .collection("friend_list")
            .document(userId)
        
        // Update `hasUnseenLatestMessage` to false
        friendRef.updateData(["hasUnseenLatestMessage": false]) { error in
            if let error = error {
                print("Failed to update hasUnseenLatestMessage: \(error)")
                return
            }
            print("Successfully updated hasUnseenLatestMessage to false")
        }
    }
    
    func handleSignOut() {
        guard let currentUserID = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        // Reference to the user's FCM token in Firestore
        let userRef = FirebaseManager.shared.firestore.collection("users").document(currentUserID)
        
        // Update the FCM token to an empty string
        userRef.updateData(["fcmToken": ""]) { error in
            if let error = error {
                print("Failed to update FCM token: \(error)")
                return
            }
            
            // Proceed to sign out if the FCM token update is successful
            DispatchQueue.main.async {
                self.isUserCurrentlyLoggedOut.toggle()
                try? FirebaseManager.shared.auth.signOut()
            }
        }
    }
}



struct MainMessagesView: View {
    @State private var shouldShowLogOutOptions = false
    @State private var shouldNavigateToChatLogView = false
    @State private var shouldNavigateToAddFriendView = false
    @State private var shouldShowFriendRequests = false
    @State private var shouldShowProfileView = false
    @State private var selectedUser: ChatUser? = nil //自己
    @State private var chatUser: ChatUser? = nil //别人
    @State private var isCurrentUser = false
    @State var errorMessage = ""
    @State var latestSenderMessage: ChatMessage?
    @State private var shouldShowFriendGroupView = false
    
    @ObservedObject private var vm = MainMessagesViewModel()
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    @State private var showFriendRequestsView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Section
                    ZStack {
                        // Header Background Image
                        Image("liuhaier")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea()

                        // Header Title
                        
                           
                            HStack {
                                Image("spacerformainmessageviewtopleft")
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                    .padding(.leading, 28)
                                Spacer()
                                Image("auroratext")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: UIScreen.main.bounds.width * 0.1832,
                                           height: UIScreen.main.bounds.height * 0.0198)
                                Spacer()
                                
                                HStack{
                                    Button(action: {
                                        if let chatUser = vm.chatUser{
                                            self.selectedUser = chatUser
                                            shouldShowFriendRequests.toggle()
                                        }
                                    }) {
                                        ZStack{
                                            Image("notificationbutton")
                                                .resizable()
                                                .frame(width: 36, height: 36)
                                                .padding(.trailing, 28)
                                            if vm.hasNewFriendRequest {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 12, height: 12)
                                                    .offset(x: 10, y: -10)
                                            }
                                            //.padding(8)
                                        }
                                    }
                                }
                            }
                            
                        
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.07) // Set header height
                    
                    ZStack{
                        
                        /*ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(0..<50, id: \.self) { index in
                                    Image("pinnedperson")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(.top, index == 0 ? 8 : 0)
                                }
                            }
                            .padding(.horizontal, 20) // Add horizontal padding for nicer layout
                            .padding(.bottom, 0) // Ensure no extra padding at the bottom
                        }*/
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(vm.users) { user in
                                    Button {
                                        if let chatUser = vm.chatUser {
                                            self.selectedUser = chatUser
                                            self.chatUser = user
                                            self.shouldNavigateToChatLogView.toggle()
                                            vm.markMessageAsSeen(for: user.uid)
                                        }
                                    } label: {
                                        ZStack {
                                            if user.isPinned {
                                                Image("pinnedperson")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .cornerRadius(16)
                                            }
                                            else {
                                                Image("notpinnedperson")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .cornerRadius(16)
                                            }

                                            // Overlay Content
                                            HStack(spacing: 16) {
                                                // User Profile Image
                                                WebImage(url: URL(string: user.profileImageUrl))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 45, height: 45)
                                                    .clipShape(Circle())

                                                VStack(alignment: .leading, spacing: 4) {
                                                    // User Name
                                                    Text(user.username)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))

                                                    // Latest Message Timestamp or Placeholder
                                                    if let timestamp = user.latestMessageTimestamp {
                                                        Text(formatTimestamp(timestamp))
                                                            .font(.system(size: 14))
                                                            .foregroundColor(Color.gray)
                                                    } else {
                                                        Text("")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(Color.gray)
                                                    }
                                                }

                                                Spacer()

                                                // Unseen Message Indicator
                                                if user.hasUnseenLatestMessage {
                                                    Circle()
                                                        .fill(Color.red)
                                                        .frame(width: 12, height: 12)
                                                }
                                            }
                                            .padding(.leading, 16)
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.bottom, 0)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }

                        /*VStack{
                            Spacer()
                         
                            Image("navigationbar")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .ignoresSafeArea(edges: .bottom) // Touch bottom edge
                        }*/
//                        VStack {
//                            Spacer()
//
//                            // Navigation Bar with Buttons
//                            ZStack {
//                                // Navigation Bar Image
//                                Image("navigationbar")
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(maxWidth: .infinity)
//                                    .ignoresSafeArea(edges: .bottom) // Touch bottom edge
//
//                                // Buttons on Navigation Bar
//                                HStack(spacing: 60) { // Adjust spacing as needed
//                                    Button(action: {
//                                        if let chatUser = vm.chatUser {
//                                            self.selectedUser = chatUser
//                                            shouldShowFriendGroupView.toggle()
//                                            // 重置朋友圈更新状态
//                                            vm.hasNewFriendGroup = false
//                                            
//                                            // 更新 lastCheckedTimestamp
//                                            let currentDate = Date()
//                                            vm.lastCheckedTimestamp = currentDate.timeIntervalSince1970
//                                            // vm.friendGroupListener?.remove()
//                                            // vm.friendGroupListener = nil
//                                            // vm.setupFriendGroupListener()
//
//                                        }
//                                    }) {
//                                        Image("dailyaurorabutton")
//                                            .resizable()
//                                            .scaledToFit()
//                                            .frame(width: 36, height: 36) // Set button size
//
//                                        if vm.hasNewFriendGroup {
//                                            Circle()
//                                                .fill(Color.red)
//                                                .frame(width: 12, height: 12)
//                                                .offset(x: 30, y: -10)
//                                        }
//                                    }
//
//                                    Button(action: {
//                                        print("Button 2 tapped")
//                                    }) {
//                                        Image("messagesbutton")
//                                            .resizable()
//                                            .scaledToFit()
//                                            .frame(width: 36, height: 36)
//                                    }
//
//                                    Button(action: {
//                                        shouldNavigateToAddFriendView.toggle()
//                                    }) {
//                                        Image("contactsbutton")
//                                            .resizable()
//                                            .scaledToFit()
//                                            .frame(width: 36, height: 36)
//                                    }
//
//                                    Button(action: {
//                                        if let chatUser = vm.chatUser {
//                                            self.selectedUser = chatUser
//                                            self.chatUser = chatUser
//                                            self.isCurrentUser = true
//                                            shouldShowProfileView.toggle()
//                                        }
//                                    }) {
//                                        Image("profilebutton")
//                                            .resizable()
//                                            .scaledToFit()
//                                            .frame(width: 36, height: 36)
//                                    }
//                                }
//                                .padding(.bottom, 20) // Adjust to align buttons vertically over the navigation bar
//                            }
//                        }

                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationDestination(isPresented: $shouldNavigateToAddFriendView) {
                CreateNewMessageView()
            }
            .fullScreenCover(isPresented: $shouldShowFriendRequests) {
                if let user = self.selectedUser {
                    FriendRequestsView(currentUser: user)
                }
            }
            //.overlay(newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $shouldShowProfileView) {
                if let chatUser = self.chatUser, let selectedUser = self.selectedUser {
                    ProfileView(
                        chatUser: chatUser,
                        currentUser: selectedUser,
                        isCurrentUser: self.isCurrentUser,
                        chatLogViewModel: chatLogViewModel
                    )
                }
            }
            
            .fullScreenCover(isPresented: $shouldNavigateToChatLogView) {
                ChatLogView(vm: chatLogViewModel)
                    .onAppear {
                        chatLogViewModel.chatUser = self.chatUser
                        chatLogViewModel.initializeMessages()
                    }
            }
            .navigationDestination(isPresented: $shouldShowFriendGroupView) {
                if let user = self.selectedUser {
                    FriendGroupView(selectedUser: user)
                }
            }
        }
        .onAppear{
            vm.setupFriendListListener()
            vm.setupFriendRequestListener()
            vm.fetchAndStoreFCMToken()
        }
        .onDisappear{
            vm.stopListening()
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            // Profile Image Button - Navigates to ProfileView with chatUser and selectedUser
            Button(action: {
                if let chatUser = vm.chatUser {
                    self.selectedUser = chatUser
                    self.chatUser = chatUser
                    self.isCurrentUser = true
                    shouldShowProfileView.toggle()
                }
            }) {
                WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(50)
                    .overlay(RoundedRectangle(cornerRadius: 44).stroke(Color(.label), lineWidth: 1))
                    .shadow(radius: 5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.chatUser?.username ?? "")
                    .font(.system(size: 24, weight: .bold))
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
            }
            Spacer()
            
            Button(action: {
                if let chatUser = vm.chatUser {
                    self.selectedUser = chatUser
                    shouldShowFriendGroupView.toggle()
                }
            }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }

            // Mail Button - Navigates to FriendRequestsView
            Button(action: {
                if let chatUser = vm.chatUser{
                    self.selectedUser = chatUser
                    shouldShowFriendRequests.toggle()
                }
            }) {
                Image(systemName: "envelope")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
            
            // Gear Button - Shows Sign-Out Options
            Button(action: {
                shouldShowLogOutOptions.toggle()
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
            .actionSheet(isPresented: $shouldShowLogOutOptions) {
                ActionSheet(
                    title: Text("Settings"),
                    message: Text("What do you want to do?"),
                    buttons: [
                        .destructive(Text("Sign Out"), action: {
                            vm.handleSignOut()
                        }),
                        .cancel()
                    ]
                )
            }
            .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut) {
                LoginView()
            }
        }
        .padding()
    }
    
    private var usersListView: some View {
        ScrollView {
            ForEach(vm.users) { user in
                VStack {
                    Button {
                        if let chatUser = vm.chatUser {
                            self.selectedUser = chatUser
                            self.chatUser = user
                            self.shouldNavigateToChatLogView.toggle()
                            vm.markMessageAsSeen(for: user.uid)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.black, lineWidth: 1))
                                .shadow(radius: 5)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(.label))
                                
                                // 显示最新聊天时间
                                if let timestamp = user.latestMessageTimestamp {
                                    Text(formatTimestamp(timestamp))
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.gray)
                                } else {
                                    Text("暂无消息")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.gray)
                                }
                            }
                            Spacer()
                            if user.hasUnseenLatestMessage {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .padding()
                        .background(user.isPinned ? Color.gray.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                    Divider().padding(.vertical, 8)
                }
                .padding(.horizontal)
            }
        }
    }
    
//    private var newMessageButton: some View {
//        Button {
//            shouldNavigateToAddFriendView.toggle()
//        } label: {
//            HStack {
//                Spacer()
//                Text("Contacts")
//                    .font(.system(size: 16, weight: .bold))
//                Spacer()
//            }
//            .foregroundColor(.white)
//            .padding(.vertical)
//            .background(Color.blue)
//            .cornerRadius(32)
//            .padding(.horizontal)
//            .shadow(radius: 15)
//        }
//        .fullScreenCover(isPresented: $shouldNavigateToAddFriendView) {
//            CreateNewMessageView()
//        }
//    }

    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            // 如果是今天，显示时间，例如 "14:23"
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // 如果是昨天，显示 "昨天"
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            // 如果在本周内，显示星期几
            let weekdaySymbols = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let weekday = calendar.component(.weekday, from: date)
            print(weekday)
            if weekday == 1 {
                formatter.dateFormat = "yyyy/MM/dd"
                return formatter.string(from: date)
            } else {
                return weekdaySymbols[(weekday + 5) % 7]
            }// 注意：周日对应索引 0
        } else {
            // 否则，显示日期，例如 "2023/10/07"
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}
