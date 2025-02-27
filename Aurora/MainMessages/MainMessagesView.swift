import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseMessaging
import FirebaseAuth

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
    
    private var combinedChats: [(id: String, isPinned: Bool, latestTimestamp: Date, isGroup: Bool, user: ChatUser?, group: GroupChat?)] {
        // Map users to tuples.
        let userChats: [(id: String, isPinned: Bool, latestTimestamp: Date, isGroup: Bool, user: ChatUser?, group: GroupChat?)] = vm.users.map { user in
            return (
                id: "user_\(user.uid)",
                isPinned: user.isPinned,
                latestTimestamp: user.latestMessageTimestamp?.dateValue() ?? Date.distantPast,
                isGroup: false,
                user: user,
                group: nil as GroupChat?
            )
        }
        // Map groups to tuples.
        let groupChats: [(id: String, isPinned: Bool, latestTimestamp: Date, isGroup: Bool, user: ChatUser?, group: GroupChat?)] = vm.groups.map { group in
            return (
                id: "group_\(group.uid)",
                isPinned: group.isPinned,
                latestTimestamp: group.latestMessageTimestamp?.dateValue() ?? group.createdAt?.dateValue() ?? Date.distantPast,
                isGroup: true,
                user: nil as ChatUser?,
                group: group
            )
        }
        let combined = userChats + groupChats
        let pinned = combined.filter { $0.isPinned }.sorted { $0.latestTimestamp > $1.latestTimestamp }
        let unpinned = combined.filter { !$0.isPinned }.sorted { $0.latestTimestamp > $1.latestTimestamp }
        return pinned + unpinned
    }
    
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
                        Text("Loading chats...")
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        Spacer()
                    }
                } else if vm.users.isEmpty{
                    Image("lonelyimageformainmessageview")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(combinedChats, id: \.id) { chat in
                                Button {
                                    generateHapticFeedbackMedium()
                                    if chat.isGroup, let group = chat.group {
                                        chatLogViewModel.reset(withNewGroup: group)
                                    } else if let user = chat.user {
                                        self.selectedUser = user
                                        self.chatUser = user
                                        chatLogViewModel.reset(withNewUser: user)
                                        vm.markMessageAsSeen(for: user.uid)
                                    }
                                    self.shouldNavigateToChatLogView.toggle()
                                } label: {
                                    HStack(spacing: 16) {
                                        if chat.isGroup, let group = chat.group {
                                            // For group chats, use a placeholder image or the group photo.
                                            Image("group.photo")
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 45, height: 45)
                                                .clipShape(Circle())
                                        } else if let user = chat.user {
                                            // For single chats, load the user profile image.
                                            WebImage(url: URL(string: user.profileImageUrl))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 45, height: 45)
                                                .clipShape(Circle())
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            if chat.isGroup, let group = chat.group {
                                                Text(group.groupName)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                            } else if let user = chat.user {
                                                Text(user.username)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                            }
                                            
                                            Text(formatTimestamp(Timestamp(date: chat.latestTimestamp)))
                                                .font(.system(size: 14))
                                                .foregroundColor(Color.gray)
                                        }
                                        Spacer()
                                        // Unseen message indicator.
                                        if (chat.isGroup && (chat.group?.hasUnseenLatestMessage ?? false)) ||
                                           (!chat.isGroup && (chat.user?.hasUnseenLatestMessage ?? false)) {
                                            Image("reddot")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    // Background image depending on pin status.
                                    .background(
                                        Image(chat.isPinned ? "pinnedperson" : "notpinnedperson")
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(16)
                                    )
                                }
                            }
                        }
                        .padding(.top, UIScreen.main.bounds.height * 0.07 + 171) // Start 8 points below the header
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
