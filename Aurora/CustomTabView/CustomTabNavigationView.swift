import SwiftUI
import Firebase

class CustomTabNavigationViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var currentUser: ChatUser?
    var newPostListener: ListenerRegistration?
    var likesListener: ListenerRegistration?
    @AppStorage("lastCheckedTimestamp") var lastCheckedTimestamp: Double = 0
    @AppStorage("lastLikesCount") var lastLikesCount: Int = 0
    
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @Published var hasNewPost = false
    @Published var hasNewLike = false
    @Published var navigateToLoginView = false
    
    init() {
        fetchCurrentUser()
        setupNewPostListener() // 设置新帖监听器
        setupLikesListener() // 设置点赞监听器
    }
    
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
                self.currentUser = ChatUser(data: data)
            }
        }
    }
    
    // 新帖监听器：监听好友的新帖子
    func setupNewPostListener() {
        guard let currentUserUid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        // 如果已有监听器，先移除
        newPostListener?.remove()
        newPostListener = nil
        
        // double to int64
        let lastCheckedTimestampInt64 = Int64(lastCheckedTimestamp)
        
        newPostListener = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .whereField("timestamp", isGreaterThan: Timestamp(seconds: lastCheckedTimestampInt64, nanoseconds: 0))
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Failed to listen for new friend group messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                var hasNewFriendGroupUpdates = false
                
                // Fetch friend list
                self?.fetchFriendList { friendUIDs in
                    for document in documents {
                        let data = document.data()
                        let authorUid = data["uid"] as? String ?? ""
                        
                        // 检查是否有好友的新帖子
                        if friendUIDs.contains(authorUid) && authorUid != currentUserUid {
                            hasNewFriendGroupUpdates = true
                            break
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self?.hasNewPost = hasNewFriendGroupUpdates
                    }
                }
            }
    }
    
    // 点赞监听器：监听当前用户发布内容的点赞数变化
    func setupLikesListener() {
        guard let currentUserUid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        // 如果已有监听器，先移除
        likesListener?.remove()
        likesListener = nil
        
        // double to int64
        let lastCheckedTimestampInt64 = Int64(lastCheckedTimestamp)
        
        likesListener = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .whereField("latestLikeTime", isGreaterThan: Timestamp(seconds: lastCheckedTimestampInt64, nanoseconds: 0))
            .order(by: "latestLikeTime", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Failed to listen for likes updates: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                var hasNewLikes = false
                
                for document in documents {
                    let data = document.data()
                    let authorUid = data["uid"] as? String ?? ""
                    
                    // 检查是自己的帖子
                    if authorUid == currentUserUid {
                        hasNewLikes = true
                        break
                    }
                }
                
                DispatchQueue.main.async {
                    self?.hasNewLike = hasNewLikes
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
}


struct CustomTabNavigationView: View {
    @State private var currentView: String = "Home"
    @AppStorage("SeenMainTutorial") private var SeenMainTutorial: Bool = false
    @State private var seentutorial = false
    @StateObject private var vm = CustomTabNavigationViewModel()
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    @State private var currentUser: ChatUser? = nil
    @State private var showSplash = true  // Add this line
    @State private var currentTutorialPage = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    
    var body: some View {
        ZStack{
            VStack {
                switch currentView {
                case "MainMessages":
                    MainMessagesView(currentView: $currentView)
                case "Profile":
                    if let user = vm.currentUser{
                        SelfProfileView(
                            chatUser: user,
                            currentUser: user,
                            isCurrentUser: true,
                            showTemporaryImg: false,
                            chatLogViewModel: chatLogViewModel
                        )
                    }
                case "Contacts":
                    CreateNewMessageView()
                case "DailyAurora":
                    if let user = vm.currentUser{
                        FriendGroupView(selectedUser: user)
                    }
                default:
                    MainMessagesView(currentView: $currentView)
                }
            }
            VStack{
                Spacer()
                CustomNavBar(currentView: $currentView)
            }
            // Splash overlay
            if showSplash {
                Image("splashscreen") // Replace with your image name
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .zIndex(1) // Ensure it's above other content
            }
            
            if !showSplash && !SeenMainTutorial {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ZStack {
                        Image("tutorialpage\(currentTutorialPage + 1)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: UIScreen.main.bounds.width * 0.8)
                            .onTapGesture {
                                if currentTutorialPage == 7 {
                                    withAnimation(.easeInOut) {
                                        SeenMainTutorial = true
                                    }
                                }
                            }
                    }
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                if value.translation.width < -threshold && currentTutorialPage < 7 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTutorialPage += 1
                                    }
                                } else if value.translation.width > threshold && currentTutorialPage > 0 {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTutorialPage -= 1
                                    }
                                }
                            }
                    )
                }
            }
            
            
        }
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(isPresented: $vm.navigateToLoginView){
            LoginView()
        }
        
        .onAppear{
            vm.fetchAndStoreFCMToken()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showSplash = false
                }
            }
        }
        
    }
    
    
}

struct CustomNavBar: View {
    @Binding var currentView: String
    @StateObject private var vm = CustomTabNavigationViewModel()
    @AppStorage("SeenDailyAuroraTutorial") private var SeenDailyAuroraTutorial: Bool = false
    @State private var showNavigationView = true
    
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
        if showNavigationView {
            ZStack{
                Image("navigationbar")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                
                HStack(spacing: 60){
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "DailyAurora"
                        vm.hasNewPost = false
                        vm.hasNewLike = false
                        let currentDate = Date()
                        vm.lastCheckedTimestamp = currentDate.timeIntervalSince1970
                        if !SeenDailyAuroraTutorial{
                            self.showNavigationView = false
                        }
                    }) {
                        
                        ZStack{
                            Image(currentView == "DailyAurora" ? "dailyaurorabuttonpressed" : "dailyaurorabuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            if ((vm.hasNewPost || vm.hasNewLike)/* && currentView != "DailyAurora" */) {
                                Image("reddot")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .offset(x: 14, y: -12)
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "MainMessages"
                    }) {
                        VStack {
                            Image(currentView == "MainMessages" ? "messagesbuttonpressed" : "messagesbuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "Contacts"
                    }) {
                        VStack {
                            Image(currentView == "Contacts" ? "contactsbuttonpressed" : "contactsbuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "Profile"
                    }) {
                        VStack {
                            Image(currentView == "Profile" ? "profilebuttonpressed" : "profilebuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    .foregroundColor(currentView == "Settings" ? .blue : .gray)
                }
                .padding(.bottom, 20)
            }
        }
        else if SeenDailyAuroraTutorial && !showNavigationView{
            ZStack{
                Image("navigationbar")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                
                HStack(spacing: 60){
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "DailyAurora"
                        vm.hasNewPost = false
                        vm.hasNewLike = false
                        let currentDate = Date()
                        vm.lastCheckedTimestamp = currentDate.timeIntervalSince1970
                        if !SeenDailyAuroraTutorial{
                            self.showNavigationView = false
                        }
                    }) {
                        
                        ZStack{
                            Image(currentView == "DailyAurora" ? "dailyaurorabuttonpressed" : "dailyaurorabuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            if ((vm.hasNewPost || vm.hasNewLike)/* && currentView != "DailyAurora" */) {
                                Image("reddot")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                                    .offset(x: 14, y: -12)
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "MainMessages"
                    }) {
                        VStack {
                            Image(currentView == "MainMessages" ? "messagesbuttonpressed" : "messagesbuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "Contacts"
                    }) {
                        VStack {
                            Image(currentView == "Contacts" ? "contactsbuttonpressed" : "contactsbuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    
                    Button(action: {
                        generateHapticFeedbackHeavy()
                        currentView = "Profile"
                    }) {
                        VStack {
                            Image(currentView == "Profile" ? "profilebuttonpressed" : "profilebuttonunpressed")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                        }
                    }
                    .foregroundColor(currentView == "Settings" ? .blue : .gray)
                }
                .padding(.bottom, 20)
            }
        }
        else{
            
        }
    }
}
