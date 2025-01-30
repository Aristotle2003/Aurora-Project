import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseMessaging
import FirebaseAuth

class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    @Published var users = [ChatUser]()
    @Published var isLoading = false

    var messageListener: ListenerRegistration?
    var friendRequestListener: ListenerRegistration? // 新增好友申请监听器变量
    
    @Published var hasNewFriendRequest = false // 用于跟踪是否有新的好友申请
    @AppStorage("lastCheckedTimestamp") var lastCheckedTimestamp: Double = 0
    @AppStorage("lastLikesCount") var lastLikesCount: Int = 0
    
    

    init() {
        
        DispatchQueue.main.async{
            self.isUserCurrentlyLoggedOut =
            FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        setupFriendListListener()
        setupFriendRequestListener()
    }

    func setupFriendListListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        isLoading = true

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
                        self.isLoading = false
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
    
    func stopListening() {
        
        messageListener?.remove()
        messageListener = nil
        friendRequestListener?.remove()
        friendRequestListener = nil
    }

    func fetchCurrentUser() {
        
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        isLoading = true

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
    @State private var showCarouselView = true
    
    @StateObject private var vm = MainMessagesViewModel()
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    @State private var showFriendRequestsView = false
    @Binding var currentView: String
    @AppStorage("lastCarouselClosedTime") private var lastCarouselClosedTime: Double = 0
    
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
    
    var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets.top ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Color
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
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
                else if vm.users.isEmpty{
                    Image("lonelyimageformainmessageview")
                }
                if showCarouselView{
                    // ScrollView with users
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.users) { user in
                                Button {
                                    generateHapticFeedbackMedium()
                                    if let chatUser = vm.chatUser {
                                        self.selectedUser = chatUser
                                        self.chatUser = user
                                        chatLogViewModel.reset(withNewUser: user)
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
                                        } else {
                                            Image("notpinnedperson")
                                                .resizable()
                                                .scaledToFit()
                                                .cornerRadius(16)
                                        }
                                        
                                        // Overlay Content
                                        HStack(spacing: 16) {
                                            ZStack{
                                                WebImage(url: URL(string: user.profileImageUrl))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 45, height: 45)
                                                    .clipShape(Circle())
                                                if user.hasUnseenLatestMessage {
                                                    Image("reddot")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 12, height: 12)
                                                        .offset(x: 16, y: -16)
                                                }
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(user.username)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                                
                                                if let timestamp = user.latestMessageTimestamp {
                                                    Text(formatTimestamp(timestamp))
                                                        .font(.system(size: 14))
                                                        .foregroundColor(Color.gray)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                        }
                                        .padding(.leading, 16)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.top, UIScreen.main.bounds.height * 0.07 + 171) // Start 8 points below the header
                        Spacer(minLength: UIScreen.main.bounds.height * 0.1)
                    }
                }
                
                if !showCarouselView{
                    // ScrollView with users
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(vm.users) { user in
                                Button {
                                    generateHapticFeedbackMedium()
                                    if let chatUser = vm.chatUser {
                                        self.selectedUser = chatUser
                                        self.chatUser = user
                                        chatLogViewModel.reset(withNewUser: chatUser)
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
                                        } else {
                                            Image("notpinnedperson")
                                                .resizable()
                                                .scaledToFit()
                                                .cornerRadius(16)
                                        }
                                        
                                        // Overlay Content
                                        HStack(spacing: 16) {
                                            ZStack{
                                                WebImage(url: URL(string: user.profileImageUrl))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 45, height: 45)
                                                    .clipShape(Circle())
                                                if user.hasUnseenLatestMessage {
                                                    Image("reddot")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 12, height: 12)
                                                        .offset(x: 16, y: -16)
                                                }
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(user.username)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                                
                                                if let timestamp = user.latestMessageTimestamp {
                                                    Text(formatTimestamp(timestamp))
                                                        .font(.system(size: 14))
                                                        .foregroundColor(Color.gray)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                        }
                                        .padding(.leading, 16)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.top, UIScreen.main.bounds.height * 0.07 + 8) // Start 8 points below the header
                        Spacer(minLength: UIScreen.main.bounds.height * 0.1)
                    }
                }
                
                // Header (on top)
                VStack {
                    ZStack {
                        Image("liuhaier")
                            .resizable()
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.07 + safeAreaTopInset)
                            .aspectRatio(nil, contentMode: .fill)
                            .ignoresSafeArea()
                        
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
                            
                            Button(action: {
                                generateHapticFeedbackMedium()
                                if let chatUser = vm.chatUser {
                                    self.selectedUser = chatUser
                                    shouldShowFriendRequests.toggle()
                                }
                            }) {
                                ZStack {
                                    Image("notificationbutton")
                                        .resizable()
                                        .frame(width: 36, height: 36)
                                        .padding(.trailing, 28)
                                    if vm.hasNewFriendRequest {
                                        Image("reddot")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 12, height: 12)
                                            .offset(x: 1, y: -12)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.07)
                    
                    if showCarouselView{
                        ZStack(alignment: .topTrailing){
                            if let chatUser = vm.chatUser {
                                CarouselView(currentUser: chatUser, currentView: $currentView)
                                Button{
                                    generateHapticFeedbackMedium()
                                    showCarouselView = false
                                    lastCarouselClosedTime = Date().timeIntervalSince1970
                                    chatLogViewModel.reset(withNewUser: chatUser)
                                }label : {
                                    Image("CloseCarouselButton")
                                        .padding(.trailing, 20)
                                        .padding(.top, 20)
                                }
                            } else {
                                // Handle the case where chatUser is nil, possibly show a placeholder or an empty view
                                Text("Loading...")
                                    .frame(height: 180) // Ensure the placeholder takes up space
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 0)
                    }
                    
                    Spacer()
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $shouldNavigateToChatLogView) {
                ChatLogView(vm: chatLogViewModel)
                    .onAppear {
                        chatLogViewModel.chatUser = self.chatUser
                        chatLogViewModel.initializeMessages()
                        chatLogViewModel.startAutoSend()
                        chatLogViewModel.setActiveStatusToTrue()
                        chatLogViewModel.markLatestMessageAsSeen()
                        chatLogViewModel.startListeningForActiveStatus()
                        chatLogViewModel.startListeningForSavingTrigger()
                        chatLogViewModel.startListeningForImages()
                        chatLogViewModel.fetchLatestMessages()
                    }
                    .onDisappear{
                        chatLogViewModel.reset()
                    }
            }
            .navigationDestination(isPresented: $shouldShowFriendRequests) {
                if let user = self.selectedUser {
                    FriendRequestsView(currentUser: user, currentView: $currentView)
                }
            }
        }
        .onAppear {
            let now = Date().timeIntervalSince1970
            let elapsed = now - lastCarouselClosedTime
            
            // 100 minutes = 100 * 60 = 6000 seconds
            if elapsed > 1000 {
                showCarouselView = true
            } else {
                showCarouselView = false
            }
            vm.fetchCurrentUser()
            vm.setupFriendListListener()
            vm.setupFriendRequestListener()
            chatLogViewModel.reset(withNewUser: vm.chatUser)
        }
        .onDisappear {
            vm.stopListening()
        }
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
                            ZStack{
                                WebImage(url: URL(string: user.profileImageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .cornerRadius(64)
                                    .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.black, lineWidth: 1))
                                    .shadow(radius: 5)
                                if user.hasUnseenLatestMessage {
                                    Image("reddot")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .offset(x: 2, y: -12)
                                }
                            }
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

struct CarouselView: View {
    let items = [
        "CarouselPicture1"
    ]

    let currentUser: ChatUser  // Ensure you pass the current user if needed
    @Binding var currentView: String

    var body: some View {
         // 固定外部框架的尺寸，例如使用 VStack 或 ZStack
        ZStack {
            Image("CarouselBackground")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width - 40)

            // Internal content
            TabView {
                ForEach(0..<items.count, id: \.self) { index in
                    ZStack(alignment: .leading) {
                        if index == 0 {
                            Button(action: {
                                currentView = "DailyAurora"
                            }) {
                                Image(items[index])
                                    .offset(x: -20)
                            }
                        } else {
                            Image(items[index])
                                .offset(x: -20)
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle()) // Enables navigation dots
            .frame(width: UIScreen.main.bounds.width-40, height: 148) // Sets the height of the carousel
            .background(Color.clear) // Ensures the background is clear
        }
        .frame(width: UIScreen.main.bounds.width - 40)
    }
}
