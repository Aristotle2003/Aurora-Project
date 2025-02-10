import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

class FriendGroupViewModel: ObservableObject {
    @Published var promptText = ""
    @Published var responseText = ""
    @Published var responses = [FriendResponse]()
    @Published var showResponseInput = false
    @Published var currentUserHasPosted = true
    @Published var isLoading = true
    
    private var selectedUser: ChatUser
    private var listener: ListenerRegistration?
    
    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        fetchPrompt()
        fetchLatestResponses(for: selectedUser.uid)
        setupCurrentUserHasPostedListener()
    }
    
    deinit {
        // 移除监听器以防止内存泄漏
        listener?.remove()
    }
    
    func fetchPrompt() {
        FirebaseManager.shared.firestore.collection("prompts").document("currentPrompt")
            .getDocument { snapshot, error in
                if let data = snapshot?.data(), let prompt = data["text"] as? String {
                    DispatchQueue.main.async {
                        self.promptText = prompt
                    }
                    print("Fetched prompt: \(prompt)")
                } else {
                    print("Failed to fetch prompt: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
    }
    
    func submitResponse(for userId: String) {
        let responseRef = FirebaseManager.shared.firestore.collection("response_to_prompt").document()
        let data: [String: Any] = [
            "uid": userId,
            "text": responseText,
            "timestamp": Timestamp(),
            "likes": 0,
            "likedBy": []
        ]
        
        responseRef.setData(data) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.responseText = ""
                    self.showResponseInput = false
                }
                print("Response submitted successfully")
                // 更新 hasPosted 状态
                self.updateHasPostedStatus(for: userId)
                // 重新获取最新的响应数据
                self.fetchLatestResponses(for: userId)
                return
            } else {
                print("Failed to submit response: \(error?.localizedDescription ?? "Unknown error")")
            }
        }

        DispatchQueue.main.async {
            self.responseText = ""
            self.showResponseInput = false
        }
        print("Response submitted successfully")
        // 更新 hasPosted 状态
        self.updateHasPostedStatus(for: userId)
        // 重新获取最新的响应数据
        self.fetchLatestResponses(for: userId)
    }
    
    func fetchLatestResponses(for userId: String) {
        var allResponses: [FriendResponse] = []
        let group = DispatchGroup()
        
        group.enter()
        fetchLatestResponse(for: userId, email: self.selectedUser.email, profileImageUrl: self.selectedUser.profileImageUrl, username: self.selectedUser.username) { response in
            if let response = response {
                allResponses.append(response)
            }
            group.leave()
        }
        
        FirebaseManager.shared.firestore.collection("friends")
            .document(userId)
            .collection("friend_list")
            .getDocuments { friendSnapshot, error in
                if let error = error {
                    print("获取好友列表失败：\(error.localizedDescription)")
                    return
                }
                
                guard let friendDocs = friendSnapshot?.documents else {
                    print("没有找到好友。")
                    return
                }
                
                for friendDoc in friendDocs {
                    let friendData = friendDoc.data()
                    guard let friendId = friendData["uid"] as? String,
                          let email = friendData["email"] as? String,
                          let username = friendData["username"] as? String,
                          let profileImageUrl = friendData["profileImageUrl"] as? String else {
                        continue
                    }
                    
                    group.enter()
                    self.fetchLatestResponse(for: friendId, email: email, profileImageUrl: profileImageUrl, username:username) { response in
                        if let response = response {
                            allResponses.append(response)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.responses = allResponses.sorted { $0.timestamp > $1.timestamp }
                    self.isLoading = false // 数据加载完成
                }
            }
    }
    
    private func fetchLatestResponse(for uid: String, email: String, profileImageUrl: String, username: String, completion: @escaping (FriendResponse?) -> Void) {
        FirebaseManager.shared.firestore.collection("response_to_prompt")
            .whereField("uid", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first {
                    let data = doc.data()
                    let latestMessage = data["text"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let likes = data["likes"] as? Int ?? 0
                    let likedBy = data["likedBy"] as? [String] ?? []
                    let currentUserId = FirebaseManager.shared.auth.currentUser?.uid ?? ""
                    let likedByCurrentUser = likedBy.contains(currentUserId)
                    let response = FriendResponse(
                        uid: uid,
                        email: email,
                        profileImageUrl: profileImageUrl,
                        latestMessage: latestMessage,
                        timestamp: timestamp,
                        likes: likes,
                        likedByCurrentUser: likedByCurrentUser,
                        documentId: doc.documentID,
                        username: username
                    )
                    DispatchQueue.main.async {
                        completion(response)
                    }
                } else {
                    print("未找到 UID \(uid) 的响应")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
    }
    
    func setupCurrentUserHasPostedListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Failed to fetch current user: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                if let data = snapshot?.data() {
                    // If `hasPosted` is present, use its value; otherwise, default to false
                    self.currentUserHasPosted = data["hasPosted"] as? Bool ?? false
                } else {
                    // Explicitly set to false if document does not exist or has no data
                    self.currentUserHasPosted = false
                }
            }
        }
        
        listener = FirebaseManager.shared.firestore.collection("users").document(uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Failed to listen to current user's post status: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    if let data = snapshot?.data() {
                        self.currentUserHasPosted = data["hasPosted"] as? Bool ?? false
                    } else {
                        self.currentUserHasPosted = false
                    }
                }
            }
    }
    
    func updateHasPostedStatus(for userId: String) {
        FirebaseManager.shared.firestore.collection("users").document(userId).updateData([
            "hasPosted": true
        ]) { error in
            if let error = error {
                print("Failed to update hasPosted status: \(error.localizedDescription)")
                return
            }
            print("User's hasPosted status updated successfully.")
        }
    }
    
    func toggleLike(for response: FriendResponse) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        let responseRef = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId)
        
        let hasLiked = response.likedByCurrentUser
        
        responseRef.updateData([
            "likes": hasLiked ? FieldValue.increment(Int64(-1)) : FieldValue.increment(Int64(1)),
            "likedBy": hasLiked ? FieldValue.arrayRemove([currentUserId]) : FieldValue.arrayUnion([currentUserId]),
            "latestLikeTime": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("更新点赞状态失败：\(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                if let index = self.responses.firstIndex(where: { $0.id == response.id }) {
                    self.responses[index].likedByCurrentUser.toggle()
                    self.responses[index].likes += hasLiked ? -1 : 1
                }
            }
        }
    }
}

struct FriendResponse: Identifiable {
    let id = UUID()
    let uid: String
    let email: String
    let profileImageUrl: String
    let latestMessage: String
    let timestamp: Date
    var likes: Int
    var likedByCurrentUser: Bool
    let documentId: String
    let username: String
}

struct FriendGroupView: View {
    @StateObject var vm: FriendGroupViewModel
    @State private var topCardIndex = 0
    @State private var offset = CGSize.zero
    @State private var rotationDegrees = [Double]()
    let selectedUser: ChatUser
    @AppStorage("SeenDailyAuroraTutorial") private var SeenDailyAuroraTutorial: Bool = false
    @State private var tutorialIndex = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var SeenDailyAuroraTutorialTemp = false
    @State private var showReportSheet = false
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        _vm = StateObject(wrappedValue: FriendGroupViewModel(selectedUser: selectedUser))
        _rotationDegrees = State(initialValue: (0..<20).map { _ in Double.random(in: -15...15) })
    }
    
    var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets.top ?? 0
    }
    
    var body: some View {
        if SeenDailyAuroraTutorial{
            NavigationStack{
                ZStack {
                    // Background Color
                    Color(red: 0.976, green: 0.980, blue: 1.0)
                        .ignoresSafeArea()
                    if vm.isLoading {
                        // 显示加载指示器
                        ProgressView()
                            .scaleEffect(2.0) // 将加载指示器放大到原来的2倍
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ZStack {
                                Image("liuhaier")
                                    .resizable()
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.07 + safeAreaTopInset)
                                    .aspectRatio(nil, contentMode: .fill)
                                    .ignoresSafeArea()
                                
                                HStack {
                                    Spacer()
                                    Image("auroratext")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width * 0.1832,
                                               height: UIScreen.main.bounds.height * 0.0198)
                                    Spacer()
                                }
                            }
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.07)
                            
                            HStack{
                                Text("Today's Prompt")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(.gray))
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            
                            // Add padding to match design
                            
                            // Rounded rectangle containing the prompt text
                            ZStack(alignment: .topLeading) {
                                // Dynamic RoundedRectangle wrapping the content
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(red: 0.898, green: 0.910, blue: 0.996)) // Color equivalent to #E5E8FE
                                
                                HStack(spacing: 20) {
                                    // VStack for Date and Prompt
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Date Text
                                        Text(Date(), style: .date)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding(.top, 20) // Pinned 20 from the top
                                            .padding(.leading, 20) // Pinned 20 from the left
                                        
                                        // Prompt Text
                                        Text(vm.promptText)
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                            .fixedSize(horizontal: false, vertical: true) // Allows wrapping
                                            .padding(.bottom, 20) // Padding to the bottom of the rectangle
                                            .padding(.trailing, 20) // Ensure alignment
                                            .padding(.leading, 20) // Align with date
                                    }
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading) // Take up 3/4 of the rectangle
                                    
                                    // Write Daily Aurora Button
                                    Button(action: {
                                        vm.showResponseInput = true
                                        generateHapticFeedbackMedium()
                                    }) {
                                        Image("writedailyaurorabutton") // Icon for the reply button
                                            .resizable()
                                            .frame(width: 24, height: 24) // Icon size
                                    }
                                    .padding()
                                    .padding(.trailing, 10)
                                }
                            }
                            .padding([.leading, .trailing], 20) // Padding for the rectangle
                            .fixedSize(horizontal: false, vertical: true) // Ensure ZStack tightly wraps its content
                            .frame(maxWidth: .infinity, alignment: .top) // Pin the ZStack to the top
                            
                            HStack{
                                Text("Responses by Friends")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(.gray))
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            
                            ZStack {
                                if vm.currentUserHasPosted {
                                    ForEach(vm.responses.indices, id: \.self) { index in
                                        if index >= topCardIndex {
                                            ResponseCard(response: vm.responses[index], cardColor: getCardColor(index: index), likeAction: {
                                                vm.toggleLike(for: vm.responses[index])
                                            })
                                            .offset(x: index == topCardIndex ? offset.width : 0, y: CGFloat(index - topCardIndex) * 10)
                                            .rotationEffect(.degrees(index == topCardIndex ? Double(offset.width / 20) : rotationDegrees[index]), anchor: .center)
                                            .scaleEffect(index == topCardIndex ? 1.0 : 0.95)
                                            .animation(.spring(), value: offset)
                                            .zIndex(Double(vm.responses.count - index))
                                            .gesture(
                                                DragGesture(minimumDistance: 3)
                                                    .onChanged { gesture in
                                                        if index == topCardIndex {
                                                            offset = gesture.translation
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        if offset.width > 75 {
                                                            withAnimation {
                                                                offset = CGSize(width: offset.width > 0 ? 500 : -500, height: 0)
                                                                topCardIndex += 1
                                                                if topCardIndex >= vm.responses.count {
                                                                    topCardIndex = 0
                                                                }
                                                                offset = .zero
                                                            }
                                                        }
                                                        else if offset.width < -75 {
                                                            withAnimation {
                                                                offset = CGSize(width: offset.width > 0 ? 500 : -500, height: 0)
                                                                topCardIndex -= 1
                                                                if topCardIndex <= -1 {
                                                                    topCardIndex = vm.responses.count-1
                                                                }
                                                                offset = .zero
                                                            }
                                                        }
                                                        else {
                                                            withAnimation {
                                                                offset = .zero
                                                            }
                                                        }
                                                    }
                                            )
                                            .padding(8)
                                        }
                                    }
                                }
                                
                                
                                
                                
                                if !vm.currentUserHasPosted {
                                    ZStack {
                                        Image("blurredbackgroundfordailyaurora") // Icon for the reply button
                                            .resizable()// Icon size
                                            .scaledToFit()
                                            .scaleEffect(1.3)
                                        VStack {
                                            Spacer()
                                            
                                            Image("lockimage")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 250, height: 130)
                                            
                                            Button(action: {
                                                vm.showResponseInput = true
                                                generateHapticFeedbackMedium()
                                            }) {
                                                Image("writeyourownresponsebutton")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 180, height: 100)
                                            }
                                            
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .opacity(0.8)
                                        .zIndex(100)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 450)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .navigationBarHidden(true)
                        .fullScreenCover(isPresented: $vm.showResponseInput) {
                            FullScreenResponseInputView(vm: vm, selectedUser: selectedUser)
                        }
                    }
                }
            }
        }
        else{
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(0..<4) { index in
                            ZStack {
                                Image("dailyauroratutorialp\(index + 1)")
                                    .resizable()
                                    .scaledToFill()
                                    .edgesIgnoringSafeArea(.all)
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                                    .clipped()
                                
                                if index == 3 {
                                    VStack {
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.easeInOut) {
                                                SeenDailyAuroraTutorial = true
                                            }
                                            generateHapticFeedbackMedium()
                                        }) {
                                            Image("dailyauroratutoriallastbutton")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: UIScreen.main.bounds.width * 0.8)
                                        }
                                        .padding(.bottom, 100)
                                    }
                                }
                            }
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width * 4, height: UIScreen.main.bounds.height)
                    .offset(x: -CGFloat(tutorialIndex) * UIScreen.main.bounds.width + dragOffset)
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.5), value: dragOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let threshold = UIScreen.main.bounds.width * 0.25
                                var newIndex = tutorialIndex
                                
                                if value.predictedEndTranslation.width < -threshold && tutorialIndex < 3 {
                                    newIndex += 1
                                } else if value.predictedEndTranslation.width > threshold && tutorialIndex > 0 {
                                    newIndex -= 1
                                }
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    tutorialIndex = newIndex
                                }
                            }
                    )
                }
                .ignoresSafeArea()
            }
        }
    }
    
    func getCardColor(index: Int) -> Color {
        let colors = [Color.mint, Color.cyan, Color.pink]
        return colors[index % colors.count]
    }
    
    func calculateHeight(for text: String) -> CGFloat {
        let textWidth = UIScreen.main.bounds.width - 80 // Account for 20 padding on each side
        let font = UIFont.preferredFont(forTextStyle: .headline)
        let size = CGSize(width: textWidth, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return boundingBox.height + 80 // Add 80 for date, spacing, and padding
    }

}

struct Comment: Identifiable {
    let id = UUID()
    let docId: String
    let uid: String
    let userName: String
    let profileImageUrl: String
    let content: String
    let timestamp: Date // 添加时间戳字段
    let replyTarget: String? // 添加回复目标字段
    let replyTargetUid: String? // 添加回复目标uid
    let parentCommentId: String? // 新增，用来存父评论的文档ID
    let rootCommentId: String? // 新增，用来存根评论的文档ID
}


struct ResponseCard: View {
    var response: FriendResponse
    var cardColor: Color
    var likeAction: () -> Void
    
    @State private var isFlipped = false
    @State private var showReportSheet = false
    @State private var reportContent = ""
    @State private var comments: [Comment] = []
    @State private var newCommentText = "" // 新增用于输入评论的文本状态
    @FocusState private var isFocused: Bool
    @State private var replyComment: Comment? = nil

    @State private var expandedComments: Set<String> = [] // 新增，用于控制子评论的显示与隐藏
    @State private var showInputField = false // 新增状态变量
    @State private var showDeleteAlert = false // 新增状态变量，用于控制删除确认弹窗
    @State private var commentToDelete: Comment? // 新增状态变量，用于存储待删除的评论

    var body: some View {
        ZStack {
            if isFlipped {
                // 卡片背面（显示评论）
                cardBackView
                
            } else {
                // 卡片正面（显示帖子内容）
                cardFrontView
            }
        }
        .onTapGesture {
            isFocused = false
            // 点击时翻面
            if !isFlipped {
                // 在翻到背面时拉取评论
                fetchComments()
            }
            withAnimation {
                isFlipped.toggle()
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.692111,
               height: UIScreen.main.bounds.height * 0.42253)
        .aspectRatio(contentMode: .fit)
        .sheet(isPresented: $showReportSheet) {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    ZStack {
                        Color.white
                            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
                        
                        Text("Report")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                    }
                    .frame(height: 60)
                    
                    // Content
                    VStack(spacing: 24) {
                        // Report Input Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What would you like to report?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                .padding(.leading, 4)
                            
                            TextEditor(text: $reportContent)
                                .frame(height: 120)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.49, green: 0.52, blue: 0.75).opacity(0.2), lineWidth: 1)
                                )
                        }
                        
                        // Notice Text
                        Text("We will review your report and take appropriate action. Thank you for helping us maintain a safe environment.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Buttons
                        HStack(spacing: 16) {
                            // Cancel Button
                            Button(action: {
                                showReportSheet = false
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.49, green: 0.52, blue: 0.75).opacity(0.2), lineWidth: 1)
                                    )
                            }
                            
                            // Submit Button
                            Button(action: {
                                reportFriend()
                                showReportSheet = false
                            }) {
                                Text("Submit")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.49, green: 0.52, blue: 0.75))
                                            .shadow(color: Color(red: 0.49, green: 0.52, blue: 0.75).opacity(0.3), radius: 4, y: 2)
                                    )
                            }
                        }
                    }
                    .padding(24)
                    
                    Spacer()
                }
            }
            .presentationDetents([.height(400)])
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Comment"),
                message: Text("Are you sure you want to delete this comment?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let commentToDelete = commentToDelete {
                        deleteComment(comment: commentToDelete)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // 卡片正面视图
    private var cardFrontView: some View {
        ZStack {
            cardBackground
            
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let topPadding: CGFloat = 35
                let sidePadding: CGFloat = 20
                let bottomPadding: CGFloat = 20
                let buttonWidth: CGFloat = 24
                let profileSize: CGFloat = 45.0
                let textWidth: CGFloat = 100
                let likeButtonSize: CGFloat = 32.0
                
                let textColor: Color = {
                    if cardColor == .mint {
                        return Color(red: 0.357, green: 0.635, blue: 0.451)
                    } else if cardColor == .cyan {
                        return Color(red: 0.388, green: 0.655, blue: 0.835)
                    } else {
                        return Color(red: 0.49, green: 0.52, blue: 0.75)
                    }
                }()
                
                // 报告按钮
                Group {
                    if cardColor == .mint {
                        Image("reportbuttongreencard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: buttonWidth, height: buttonWidth)
                            .position(x: w - sidePadding - 10, y: topPadding)
                            .onTapGesture {
                                showReportSheet = true
                            }
                    } else if cardColor == .cyan {
                        Image("reportbuttonbluecard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: buttonWidth, height: buttonWidth)
                            .position(x: w - sidePadding - 10, y: topPadding)
                            .onTapGesture {
                                showReportSheet = true
                            }
                    } else if cardColor == .pink {
                        Image("reportbuttonpurplecard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: buttonWidth, height: buttonWidth)
                            .position(x: w - sidePadding - 10, y: topPadding)
                            .onTapGesture {
                                showReportSheet = true
                            }
                    }
                }
                
                // 帖子文本
                Text(response.latestMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textColor)
                    .frame(width: w * 0.7)
                    .multilineTextAlignment(.center)
                    .position(x: w / 2, y: h / 2)
                
                // 头像 //插个眼
                if response.uid != getCurrentUser().uid {
                    NavigationLink(
                        destination: ProfileView(
                            chatUser: ChatUser(data: [
                                "uid": response.uid,
                                "userName": response.username,
                                "profileImageUrl": response.profileImageUrl
                            ]),
                            currentUser: getCurrentUser(),
                            isCurrentUser: false
                        )
                    ) {
                        WebImage(url: URL(string: response.profileImageUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: profileSize, height: profileSize)
                            .clipShape(Circle())
                            .position(x: sidePadding + profileSize / 2,
                                    y: h - bottomPadding - profileSize / 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    WebImage(url: URL(string: response.profileImageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(width: profileSize, height: profileSize)
                        .clipShape(Circle())
                        .position(x: sidePadding + profileSize / 2,
                                y: h - bottomPadding - profileSize / 2)
                }
                
                // 用户名和时间
                let textLeftOffset: CGFloat = sidePadding + profileSize + 10
                Group {
                    Text(response.username)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textColor)
                        .frame(width: textWidth, alignment: .leading)
                        .position(x: textLeftOffset + textWidth / 2,
                                  y: h - bottomPadding - profileSize / 2 - 8)
                    
                    Text(response.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: textWidth, alignment: .leading)
                        .position(x: textLeftOffset + textWidth / 2,
                                  y: h - bottomPadding - profileSize / 2 + 8)
                }
                
                // 点赞按钮和点赞数
                let likeSectionX = w - sidePadding - likeButtonSize / 2
                let likeSectionY = h - bottomPadding - profileSize / 2
                Button(action: {
                    likeAction()
                }) {
                    if cardColor == .mint {
                        Image(response.likedByCurrentUser ? "likegivengreen" : "likenotgivengreen")
                            .resizable()
                            .scaledToFit()
                            .frame(width: likeButtonSize, height: likeButtonSize)
                    } else if cardColor == .cyan {
                        Image(response.likedByCurrentUser ? "likegivenblue" : "likenotgivenblue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: likeButtonSize, height: likeButtonSize)
                    } else if cardColor == .pink {
                        Image(response.likedByCurrentUser ? "likegivenpurple" : "likenotgivenpurple")
                            .resizable()
                            .scaledToFit()
                            .frame(width: likeButtonSize, height: likeButtonSize)
                    }
                }
                .position(x: likeSectionX, y: likeSectionY)
                
                Text("\(response.likes)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
                    .position(x: likeSectionX - 30, y: likeSectionY)
            }
        }
    }
    
    private var cardBackView: some View {
        ZStack {
            cardBackground
                .scaleEffect(1.25)
            
            VStack {
                ScrollView {
                    // 先筛出顶层评论(parentCommentId为空)
                    let topLevelComments = comments.filter { $0.parentCommentId?.isEmpty ?? true }
                    
                    VStack(spacing: 10) {
                        ForEach(topLevelComments) { topComment in
                            VStack(alignment: .leading, spacing: 3) {
                                // 顶层评论UI
                                HStack(alignment: .top, spacing: 5) {
                                    if topComment.uid != getCurrentUser().uid {
                                        NavigationLink(
                                            destination: ProfileView(
                                                chatUser: ChatUser(data: [
                                                    "uid": topComment.uid,
                                                    "userName": topComment.userName,
                                                    "profileImageUrl": topComment.profileImageUrl
                                                ]),
                                                currentUser: getCurrentUser(),
                                                isCurrentUser: false)
                                        ) {
                                            WebImage(url: URL(string: topComment.profileImageUrl))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        }
                                    } else {
                                        WebImage(url: URL(string: topComment.profileImageUrl))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                    }
                                    
                      
                                    HStack {
                                        if cardColor == .mint {
                                            VStack(alignment: .leading) {
                                                HStack {
                                                    Text(topComment.userName)
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(Color(red: 0.357, green: 0.635, blue: 0.451))
                                                }
                                                HStack {
                                                    if let replyTarget = topComment.replyTarget, !replyTarget.isEmpty {
                                                        Text("(To: \(replyTarget)) \(topComment.content)")
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.leading)
                                                    } else {
                                                        Text(topComment.content)
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                }
                                            }
                                            .onTapGesture {
                                                replyComment = topComment
                                                showInputField = true
                                                isFocused = true
                                            }
                                            .onLongPressGesture {
                                                if topComment.uid == getCurrentUser().uid {
                                                    commentToDelete = topComment
                                                    showDeleteAlert = true
                                                }
                                            }
                                        } else if cardColor == .cyan {
                                            VStack(alignment: .leading) {
                                                HStack {
                                                    Text(topComment.userName)
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(Color(red: 0.388, green: 0.655, blue: 0.835))
                                                }
                                                HStack {
                                                    if let replyTarget = topComment.replyTarget, !replyTarget.isEmpty {
                                                        Text("(To: \(replyTarget)) \(topComment.content)")
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.leading)
                                                    } else {
                                                        Text(topComment.content)
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                }
                                            }
                                            .onTapGesture {
                                                replyComment = topComment
                                                showInputField = true
                                                isFocused = true
                                            }
                                            .onLongPressGesture {
                                                if topComment.uid == getCurrentUser().uid {
                                                    commentToDelete = topComment
                                                    showDeleteAlert = true
                                                }
                                            }
                                        } else {
                                            VStack(alignment: .leading) {
                                                HStack {
                                                    Text(topComment.userName)
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                                }
                                                HStack {
                                                    if let replyTarget = topComment.replyTarget, !replyTarget.isEmpty {
                                                        Text("(To: \(replyTarget)) \(topComment.content)")
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.leading)
                                                    } else {
                                                        Text(topComment.content)
                                                            .font(.subheadline)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.gray)
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                }
                                            }
                                            .onTapGesture {
                                                replyComment = topComment
                                                showInputField = true
                                                isFocused = true
                                            }
                                            .onLongPressGesture {
                                                if topComment.uid == getCurrentUser().uid {
                                                    commentToDelete = topComment
                                                    showDeleteAlert = true
                                                }
                                            }
                                        }
                                        Spacer()
                                        Text(topComment.timestamp, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.top, 2.5)
                                    }
                                    
                                }
                                // .padding(.horizontal, 1)
                                
                                // 子评论(只一层)
                                let subComments = comments
                                    .filter { $0.rootCommentId == topComment.docId && $0.docId != topComment.docId } // 防止自己的评论成为子评论
                                    .sorted { $0.timestamp < $1.timestamp }

                                if expandedComments.contains(topComment.docId) || subComments.count <= 2 {
                                    ForEach(subComments) { subComment in
                                        HStack(alignment: .top, spacing: 10) {
                                        // 缩进
                                        Spacer().frame(width: 20)
                                        
                                        if subComment.uid != getCurrentUser().uid {
                                            NavigationLink(
                                                destination: ProfileView(
                                                    chatUser: ChatUser(data: [
                                                        "uid": subComment.uid,
                                                        "userName": subComment.userName,
                                                        "profileImageUrl": subComment.profileImageUrl
                                                    ]),
                                                    currentUser: getCurrentUser(),
                                                    isCurrentUser: false
                                                )
                                            ) {
                                                WebImage(url: URL(string: subComment.profileImageUrl))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 32, height: 32)
                                                    .clipShape(Circle())
                                            }
                                        } else {
                                            WebImage(url: URL(string: subComment.profileImageUrl))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        }
                                        

                                        HStack {
                                            if cardColor == .mint {
                                                VStack(alignment: .leading) {
                                                    HStack {
                                                        Text(subComment.userName)
                                                            .font(.subheadline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(Color(red: 0.357, green: 0.635, blue: 0.451))
                                                    }
                                                    HStack {
                                                        if let replyTarget = subComment.replyTarget, !replyTarget.isEmpty {
                                                            Text("(To: \(replyTarget)) \(subComment.content)")
                                                                .font(.subheadline)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.gray)
                                                                .multilineTextAlignment(.leading)
                                                        } else {
                                                            Text(subComment.content)
                                                                .font(.subheadline)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.gray)
                                                                .multilineTextAlignment(.leading)
                                                        }
                                                    }
                                                }
                                                .onTapGesture {
                                                    replyComment = subComment
                                                    showInputField = true
                                                    isFocused = true
                                                }
                                                .onLongPressGesture {
                                                    if subComment.uid == getCurrentUser().uid {
                                                        commentToDelete = subComment
                                                        showDeleteAlert = true
                                                    }
                                                }
                                            } else if cardColor == .cyan {
                                                VStack(alignment: .leading) {
                                                    HStack {
                                                        Text(subComment.userName)
                                                            .font(.subheadline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(Color(red: 0.388, green: 0.655, blue: 0.835))
                                                    }
                                                    HStack {
                                                        if let replyTarget = subComment.replyTarget, !replyTarget.isEmpty {
                                                            Text("(To: \(replyTarget)) \(subComment.content)")
                                                                .font(.subheadline)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.gray)
                                                                .multilineTextAlignment(.leading)
                                                        } else {
                                                            Text(subComment.content)
                                                                .font(.subheadline)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.gray)
                                                                .multilineTextAlignment(.leading)
                                                        }
                                                    }
                                                }
                                                .onTapGesture {
                                                    replyComment = subComment
                                                    showInputField = true
                                                    isFocused = true
                                                }
                                                .onLongPressGesture {
                                                    if subComment.uid == getCurrentUser().uid {
                                                        commentToDelete = subComment
                                                        showDeleteAlert = true
                                                    }
                                                }
                                            } else {
                                                VStack(alignment: .leading) {
                                                    HStack {
                                                        Text(subComment.userName)
                                                            .font(.subheadline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                                    }
                                                    HStack {
                                                        if let replyTarget = subComment.replyTarget, !replyTarget.isEmpty {
                                                            Text("(To: \(replyTarget)) \(subComment.content)")
                                                                .font(.subheadline)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.gray)
                                                                .multilineTextAlignment(.leading)
                                                        } else {
                                                            Text(subComment.content)
                                                                .font(.subheadline)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.gray)
                                                                .multilineTextAlignment(.leading)
                                                        }
                                                    }
                                                }
                                                .onTapGesture {
                                                    replyComment = subComment
                                                    showInputField = true
                                                    isFocused = true
                                                }
                                                .onLongPressGesture {
                                                    if subComment.uid == getCurrentUser().uid {
                                                        commentToDelete = subComment
                                                        showDeleteAlert = true
                                                    }
                                                }
                                            }
                                            Spacer()
                                            Text(subComment.timestamp, style: .time)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(.top, 2.5)
                                        }
                                    }
                                    .padding(.horizontal)
                                    }

                                } else {
                                    ForEach(subComments.prefix(2)) { subComment in
                                        HStack(alignment: .top, spacing: 10) {
                                            
                                        }
                                        .padding(.horizontal)
                                    }
                                }

                                if subComments.count > 2 {
                                // 在顶层评论区域添加切换按钮（示例）：
                                    Button(action: {
                                        if expandedComments.contains(topComment.docId) {
                                            expandedComments.remove(topComment.docId)
                                        } else {
                                            expandedComments.insert(topComment.docId)
                                        }
                                    }) {
                                        Text(expandedComments.contains(topComment.docId) ? "—— fold" : "—— expand \(subComments.count) \(subComments.count > 1 ? "replies" : "reply")")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.leading, 20)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 35)
                
                Spacer()
                
                if showInputField {
                    HStack {
                        // 向下按钮，用于隐藏输入框
                        Button(action: {
                            showInputField = false
                            isFocused = false
                        }) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(getButtonColor())
                        }
                        .padding(.leading)

                        TextField(replyComment == nil ? "Add a comment..." : "Reply to \(replyComment!.userName)...", text: $newCommentText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            // .padding(.horizontal)
                            .focused($isFocused)
                            .onAppear {
                                isFocused = true // 聚焦输入框
                            }
                            .cornerRadius(20)


                        if !newCommentText.isEmpty {
                            Button(action: {
                                submitNewComment()
                                isFocused = false
                                showInputField = false // 隐藏输入框
                            }) {

                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(getButtonColor())
                            }
                            .padding(.trailing)
                        } else {
                            Button(action: {
                                print("Say somthing before sending ~") // 插个眼
                            }) {

                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(Color.gray)
                            }
                            .padding(.trailing)
                        }

                        
                    }
                    .background(Color.white.opacity(0.5))
                    .overlay(
                            Capsule() // 使用 Capsule 形状
                                .stroke(getButtonColor().opacity(0.5), lineWidth: 3)
                                .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3) // 添加阴影 // 添加边框
                        )
                    .cornerRadius(15)
                    .padding(.bottom, 100)
                    .animation(.easeOut(duration: 0.25), value: 100)
                } else {
                    Button(action: {
                        replyComment = nil // 清除回复目标
                        showInputField = true // 显示输入框
                        isFocused = true // 聚焦输入框
                    }) {
                        HStack {
                            Image(systemName: "pencil.and.outline") // 使用系统图标
                                .foregroundColor(.white)
                            
                            Text("Add a comment...")
                                .foregroundColor(.white)
                                .padding(.leading, 5) // 添加一些间距
                        }
                        .padding()
                        .background(
                            Capsule() // 使用 Capsule 形状
                                .fill(
                                    LinearGradient(gradient: Gradient(colors: [getButtonColor(), getButtonColor().opacity(0.7)]), startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3) // 添加阴影
                        )
                        .overlay(
                            Capsule() // 使用 Capsule 形状
                                .stroke(Color.white.opacity(0.5), lineWidth: 1) // 添加边框
                        )
                    }
                    .padding(.horizontal)
                }
 
            }
        }
    }

    private func getButtonColor() -> Color {
            switch cardColor {
            case .mint:
                return Color(red: 0.357, green: 0.635, blue: 0.451)
            case .cyan:
                return Color(red: 0.388, green: 0.655, blue: 0.835)
            case .pink:
                return Color(red: 0.49, green: 0.52, blue: 0.75)
            default:
                return .blue
            }
        }

        // 为正反面提供相同的卡片背景
    private var cardBackground: some View {
        ZStack {
            if cardColor == .mint {
                Image("greencard")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(25)
            } else if cardColor == .cyan {
                Image("bluecard")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(25)
            } else if cardColor == .pink {
                Image("purplecard")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(25)
            } else {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white)
            }
        }
    }
    
    private func submitNewComment() {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else { return }
        guard !newCommentText.isEmpty else { return }
        let commentRef = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId)
            .collection("comments")
            .document()

        let userId = currentUser.uid
        FirebaseManager.shared.firestore.collection("users").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                print("Failed to fetch user data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let userName = data["username"] as? String ?? "Unknown"
            let profileImageUrl = data["profileImageUrl"] as? String ?? ""
            let rootId = replyComment?.rootCommentId ?? commentRef.documentID // 若无上级，则自己是根
            
            let commentData: [String: Any] = [
                "docId": commentRef.documentID,
                "uid": userId,
                "userName": userName,
                "profileImageUrl": profileImageUrl,
                "content": newCommentText,
                "timestamp": FieldValue.serverTimestamp(), // 添加时间戳字段
                "replyTarget": replyComment?.userName ?? "", // 如果存在被回复的comment，存它的userName
                "parentCommentId": replyComment?.docId ?? "", // 使用父评论的文档ID
                "replyTargetUid": replyComment?.uid ?? "",
                "rootCommentId": rootId // 新增，存根评论的文档ID
            ]

            newCommentText = ""
        
            commentRef.setData(commentData) { error in
                if let error = error {
                    print("Failed to submit comment:", error.localizedDescription)
                    return
                }
                DispatchQueue.main.async {
                    self.newCommentText = ""
                    self.fetchComments()
                }
            }
        }
    }
    
    private func getCurrentUser() -> ChatUser {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            return ChatUser(data: ["uid": "", "email": "", "profileImageUrl": ""])
        }
        return ChatUser(data: [
            "uid": currentUser.uid,
            "email": currentUser.email ?? "",
            "profileImageUrl": currentUser.photoURL?.absoluteString ?? ""
        ])
    }

    // 拉取评论方法
    private func fetchComments() {
        FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId)
            .collection("comments")
            .order(by: "timestamp", descending: true) // 根据时间戳排序
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else { return }
                DispatchQueue.main.async {
                    self.comments = docs.map { doc in
                        let data = doc.data()
                        return Comment(
                            docId: doc.documentID,
                            uid: data["uid"] as? String ?? "Unknown",
                            userName: data["userName"] as? String ?? "Unknown",
                            profileImageUrl: data["profileImageUrl"] as? String ?? "",
                            content: data["content"] as? String ?? "",
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(), // 获取时间戳
                            replyTarget: data["replyTarget"] as? String ?? "", // 获取被回复的comment的userName
                            replyTargetUid: data["replyTargetUid"] as? String ?? "",
                            parentCommentId: data["parentCommentId"] as? String ?? "",
                            rootCommentId: data["rootCommentId"] as? String ?? ""
                        )
                    }
                }
            }
    }
    
    private func reportFriend() {
        let reportData: [String: Any] = [
            "uid": response.uid,
            "timestamp": FieldValue.serverTimestamp(),
            "content": response.latestMessage,
            "why": reportContent
        ]
        
        FirebaseManager.shared.firestore
            .collection("reports_for_friends_in_dailyaurora")
            .document()
            .setData(reportData) { error in
                if let error = error {
                    print("Failed to report friend: \(error)")
                } else {
                    print("Friend reported successfully")
                }
            }
    }
    
    private func deleteComment(comment: Comment) {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else { return }
        let commentRef = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId) // 使用 response.documentId 而不是 comment.rootCommentId
            .collection("comments")
            .document(comment.docId)

        print("Deleting comment with ID: \(comment.docId) in response \(response.documentId)")

        commentRef.delete { error in
            if let error = error {
                print("Failed to delete comment:", error.localizedDescription)
                return
            }
            DispatchQueue.main.async {
                self.fetchComments()
            }
        }
    }
}



struct FullScreenResponseInputView: View {
    @StateObject var vm: FriendGroupViewModel
    let selectedUser: ChatUser
    
    @FocusState private var isResponseTextFocused: Bool // For focusing the TextEditor
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color(red: 0.976, green: 0.980, blue: 1.0)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isResponseTextFocused = false // 点击空白收回键盘
                        }
                    
                    VStack {
                        let topbarheight = UIScreen.main.bounds.height * 0.055
                        HStack {
                            Button(action: {
                                vm.showResponseInput = false
                            }) {
                                Image("chatlogviewbackbutton")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.leading, 20)
                            }
                            
                            Spacer()
                            
                            Image("auroratext")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width * 0.1832, height: UIScreen.main.bounds.height * 0.0198)
                            
                            Spacer()
                            
                            Button(action: {
                                vm.submitResponse(for: selectedUser.uid)
                            }) {
                                Image("postbutton")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 20)
                            }
                        }
                        .frame(height: topbarheight)
                        
                        HStack {
                            Text("Today's Prompt:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 85/255, green: 85/255, blue: 85/255))
                                .padding(.leading, 25)
                                .padding(.top, 20)
                            Spacer()
                        }
                        
                        HStack {
                            Text(vm.promptText)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 85/255, green: 85/255, blue: 85/255))
                                .padding(.leading, 25)
                                .padding(.trailing, 25)
                                .padding(.top, 10)
                                .fixedSize(horizontal: false, vertical: true) // Allow multiline
                            Spacer()
                        }
                        
                        // Multiline TextEditor for response input
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $vm.responseText)
                                .foregroundColor(Color(red: 85/255, green: 85/255, blue: 85/255)) // Color #555555
                                .font(.system(size: 14))
                                .padding(.horizontal, 25)
                                .scrollContentBackground(.hidden)// Clear background
                                .frame(height: UIScreen.main.bounds.height * 0.3) // 30% of the screen height
                                .focused($isResponseTextFocused) // Manage focus state
                                .tint(Color.gray)
                                .onAppear {
                                    // Automatically focus when view appears
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.isResponseTextFocused = true
                                    }
                                }
                                .onChange(of: vm.responseText) { newValue in
                                    if newValue.count > 300 {
                                        vm.responseText = String(newValue.prefix(300)) // Limit to 300 characters
                                    }
                                }
                            if vm.responseText.isEmpty {
                                Text("  Type your answer here...")
                                    .foregroundColor(Color.gray.opacity(0.7)) // Placeholder text color
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 25)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // HStack for character count and date
                        HStack {
                            // Character Count at Bottom-Left
                            Text("\(vm.responseText.count)/300")
                                .foregroundColor(Color.gray)
                                .font(.system(size: 12))
                                .padding(.leading, 25)
                            
                            Spacer()
                            
                            // Today's Date at Bottom-Right
                            Text(Date(), style: .date)
                                .foregroundColor(Color.gray)
                                .font(.system(size: 12))
                                .padding(.trailing, 25)
                        }
                        .padding(.bottom, 16)
                        Spacer()
                    }
                }
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}
