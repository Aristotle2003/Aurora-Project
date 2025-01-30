import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Lottie

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let seen = "seen"
    static let sender = "sender"
    static let timestamp = "timestamp"
}

struct ChatMessage: Identifiable {
    var id: String { documentId }
    let documentId: String
    let fromId, toId, text: String
    let timeStamp: Timestamp
    var seen: Bool
    let sender: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
        self.timeStamp = data["timeStamp"] as? Timestamp ?? Timestamp()
        self.seen = data[FirebaseConstants.seen] as? Bool ?? false
        self.sender = data[FirebaseConstants.sender] as? String ?? "Unknown"
    }
}

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var latestSenderMessage: ChatMessage?
    @Published var latestRecipientMessage: ChatMessage?
    @Published var chatUser: ChatUser?
    @Published var showSavedMessagesWindow = false
    @Published var savedMessages = [ChatMessage]()
    @Published var isChatUserActive: Bool = false
    @Published var chatUserLastSeen: Timestamp? = nil
    @Published var savingTrigger: Bool = true
    @Published var showImagePicker = false
    @Published var selectedImage: UIImage?
    @Published var receivedImages: [String] = []
    @Published var hasUnseenImages = false
    private var imageListener: ListenerRegistration?
    private var listener: ListenerRegistration?
    private var listenerForSavingTrigger: ListenerRegistration?
    
    
    @Published var statusMessage = ""
    
    // Update the handleImageSelection function in ChatLogViewModel
    func handleImageSelection(image: UIImage) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid,
              let toId = chatUser?.uid else { return }
        
        let imageName = UUID().uuidString
        // Use a more specific storage path
        let ref = FirebaseManager.shared.storage.reference().child("chat_images").child(fromId).child(toId).child("\(imageName).jpg")
        
        // Convert image to lower quality JPEG and process in background
        DispatchQueue.global(qos: .userInitiated).async {
            // First convert to PNG to handle any HDR image issues
            if let pngData = image.pngData(),
               let normalizedImage = UIImage(data: pngData),
               let compressedData = normalizedImage.jpegData(compressionQuality: 0.3) {
                
                // Switch back to main thread for UI updates
                DispatchQueue.main.async {
                    // Upload the compressed image data
                    let metadata = StorageMetadata()
                    metadata.contentType = "image/jpeg"
                    
                    // Upload with metadata
                    ref.putData(compressedData, metadata: metadata) { [weak self] metadata, err in
                        guard let self = self else { return }
                        
                        if let err = err {
                            print("Failed to upload image: \(err)")
                            self.statusMessage = "Failed to upload image: \(err.localizedDescription)"
                            return
                        }
                        
                        ref.downloadURL { url, err in
                            if let err = err {
                                print("Failed to get download URL: \(err)")
                                self.statusMessage = "Failed to process image: \(err.localizedDescription)"
                                return
                            }
                            
                            guard let url = url else {
                                print("Failed to get URL")
                                return
                            }
                            print("Successfully uploaded image, URL: \(url.absoluteString)")
                            self.storeImageUrlInFirestore(imageUrl: url)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("Failed to process image data")
                    self.statusMessage = "Failed to process image"
                }
            }
        }
    }

    private func storeImageUrlInFirestore(imageUrl: URL) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid,
              let toId = chatUser?.uid else { return }
        
        let docRef = FirebaseManager.shared.firestore
            .collection("Images_in_message")
            .document(toId)
            .collection("image_list")
            .document(fromId)
        
        // First try to fetch existing document
        docRef.getDocument { [weak self] snapshot, err in
            guard let self = self else { return }
            
            if let err = err {
                print("Failed to fetch document: \(err)")
                self.statusMessage = "Failed to fetch document: \(err.localizedDescription)"
                return
            }
            
            // Get existing images array or create new one
            var imageUrls = (snapshot?.data()?["images"] as? [String]) ?? []
            imageUrls.append(imageUrl.absoluteString)
            
            // Update or create document
            docRef.setData(["images": imageUrls], merge: true) { err in
                if let err = err {
                    print("Failed to save image URL: \(err)")
                    self.statusMessage = "Failed to save image URL: \(err.localizedDescription)"
                    return
                }
                print("Successfully stored image URL in Firestore")
                self.statusMessage = "Successfully stored image"
            }
        }
    }
    
    func startListeningForImages() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let chatUserId = chatUser?.uid else { return }
        
        let docRef = FirebaseManager.shared.firestore
            .collection("Images_in_message")
            .document(currentUserId)
            .collection("image_list")
            .document(chatUserId)
        
        imageListener = docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                self.statusMessage = "Failed to listen for images: \(error.localizedDescription)"
                return
            }
            
            if let imageUrls = snapshot?.data()?["images"] as? [String] {
                self.receivedImages = imageUrls
                self.hasUnseenImages = !imageUrls.isEmpty
            } else {
                self.receivedImages = []
                self.hasUnseenImages = false
            }
        }
    }
    
    func deleteImage(at index: Int) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let chatUserId = chatUser?.uid,
              index < receivedImages.count else { return }
        
        var updatedImages = receivedImages
        updatedImages.remove(at: index)
        
        let docRef = FirebaseManager.shared.firestore
            .collection("Images_in_message")
            .document(currentUserId)
            .collection("image_list")
            .document(chatUserId)
        
        docRef.setData(["images": updatedImages]) { err in
            if let err = err {
                self.statusMessage = "Failed to update images: \(err.localizedDescription)"
                return
            }
        }
    }
    
    func stopListeningForImages() {
        imageListener?.remove()
        imageListener = nil
    }
    
    var timer: Timer?
    var seenCheckTimer: Timer?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
    }
    
    func reset(withNewUser chatUser: ChatUser?) {
        // Stop all existing listeners
        stopListening()
        stopListeningForActiveStatus()
        stopListeningForSavingTrigger()
        stopListeningForImages()
        stopAutoSend()
        self.showImagePicker = false
        self.receivedImages = []
        // Reset all properties
        self.chatText = ""
        self.errorMessage = ""
        self.latestSenderMessage = nil
        self.latestRecipientMessage = nil
        self.hasUnseenImages = false
        self.chatUser = chatUser
        self.showSavedMessagesWindow = false
        self.savedMessages = []
        self.isChatUserActive = false
        self.chatUserLastSeen = nil
        self.savingTrigger = true
        self.lastState = false
        
        // Initialize with new user
        if chatUser != nil {
            initializeMessages()
            startListeningForActiveStatus()
            startListeningForSavingTrigger()
            startListeningForImages()
            fetchLatestMessages()
        }
    }
    
    func reset() {
        // Reset all state variables
        chatText = ""
        errorMessage = ""
        latestSenderMessage = nil
        latestRecipientMessage = nil
        savingTrigger = true
        isChatUserActive = false
        chatUserLastSeen = nil
        
        // Stop all listeners
        stopListening()
        stopListeningForActiveStatus()
        stopListeningForSavingTrigger()
        stopAutoSend()
        
        // Clear timers
        timer?.invalidate()
        timer = nil
        seenCheckTimer?.invalidate()
        seenCheckTimer = nil
    }
    
    func startListeningForSavingTrigger() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let chatUserId = chatUser?.uid else { return }
        
        let savingTriggerRef = FirebaseManager.shared.firestore
            .collection("saving_trigger")
            .document(currentUserId)
            .collection("trigger_list")
            .document(chatUserId)
        
        listenerForSavingTrigger = savingTriggerRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Failed to listen for saving triggers: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else { return }
            self.savingTrigger = data["triggering"] as? Bool ?? false
            
        }
    }
    
    func stopListeningForSavingTrigger() {
        listenerForSavingTrigger?.remove()
        listenerForSavingTrigger = nil
    }
    
    func setTriggerToFalse(){
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let chatUserId = chatUser?.uid else { return }
        
        let savingTriggerRef = FirebaseManager.shared.firestore
            .collection("saving_trigger")
            .document(currentUserId)
            .collection("trigger_list")
            .document(chatUserId)
        
        savingTriggerRef.setData(["triggering": false], merge: true) { error in
            if let error = error {
                print("Failed to reset trigger \(error)")
            } else {
                print("Trigger to false")
            }
        }
    }
    
    func startListeningForActiveStatus() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let chatUserId = chatUser?.uid else { return }
        
        let activeStatusRef = FirebaseManager.shared.firestore
            .collection("activeStatus")
            .document(chatUserId)
            .collection("activeList")
            .document(currentUserId)
        
        listener = activeStatusRef.addSnapshotListener { snapshot, error in
            if let error = error {
                print("Failed to listen for active status: \(error)")
                return
            }
            
            guard let data = snapshot?.data() else { return }
            self.isChatUserActive = data["isActive"] as? Bool ?? false
            self.chatUserLastSeen = data["lastSeen"] as? Timestamp
        }
    }
    
    func stopListeningForActiveStatus() {
        listener?.remove()
        listener = nil
    }
    
    
    
    // Fetch the saved messages between the current user and the chat user
    func fetchSavedMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch saved messages: \(error)"
                    return
                }
                self.savedMessages = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    return ChatMessage(documentId: doc.documentID, data: data)
                } ?? []
            }
    }
    
    func initializeMessages() {
        
        reset()
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        // Fetch the latest message sent by the current user
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch sender's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestSenderMessage = ChatMessage(documentId: document.documentID, data: data)
                    self.chatText = self.latestSenderMessage?.text ?? ""
                } else {
                    // No document found, set default empty message
                    self.latestSenderMessage = ChatMessage(documentId: "", data: ["text": ""])
                    self.chatText = ""
                }
            }
        
        // Fetch the latest message sent by the recipient
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(toId)
            .collection(fromId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch recipient's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestRecipientMessage = ChatMessage(documentId: document.documentID, data: data)
                } else {
                    // No document found, set default empty message
                    self.latestRecipientMessage = ChatMessage(documentId: "", data: ["text": ""])
                }
            }
    }
    
    func startAutoSend() {
        timer?.invalidate()
        timer = nil
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            print(self.chatText)
            self.handleSend()
        }
    }
    
    func stopAutoSend() {
        timer?.invalidate()
        timer = nil
    }
    
    func markLatestMessageAsSeen() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let chatUserId = chatUser?.uid else { return }
        
        // Fetch only the latest message from the recipient
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(chatUserId)
            .collection(currentUserId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1) // Limit to the latest message
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Failed to fetch recipient's latest message: \(error)")
                    return
                }
                
                guard let document = querySnapshot?.documents.first else {
                    print("No messages found")
                    return
                }
                
                let data = document.data()
                if let seen = data["seen"] as? Bool, !seen {
                    // Mark the latest message as seen
                    document.reference.updateData(["seen": true]) { error in
                        if let error = error {
                            print("Failed to update the latest message as seen: \(error)")
                        } else {
                            print("Successfully marked the latest message as seen")
                        }
                    }
                } else {
                    print("The latest message is already marked as seen")
                }
            }
    }
    
    
    /// Set active status to `true` for the current user to a specific chatUser
    func setActiveStatusToTrue() {
        
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let chatUserId = chatUser?.uid else { return }
        
        let activeStatusRef = FirebaseManager.shared.firestore
            .collection("activeStatus")
            .document(currentUserId)
            .collection("activeList")
            .document(chatUserId)
        
        activeStatusRef.setData(["isActive": true, "lastSeen": Timestamp()], merge: true) { error in
            if let error = error {
                print("Failed to set active status to true: \(error)")
            } else {
                print("Active status set to true for \(chatUserId)")
            }
        }
    }
    
    /// Set active status to `false` for the current user to a specific chatUser
    func setActiveStatusToFalse() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let chatUserId = chatUser?.uid else { return }
        
        let activeStatusRef = FirebaseManager.shared.firestore
            .collection("activeStatus")
            .document(currentUserId)
            .collection("activeList")
            .document(chatUserId)
        
        activeStatusRef.setData(["isActive": false, "lastSeen": Timestamp()], merge: true) { error in
            if let error = error {
                print("Failed to set active status to false: \(error)")
            } else {
                print("Active status set to false for \(chatUserId)")
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
    
    private var senderMessageListener: ListenerRegistration?
    private var recipientMessageListener: ListenerRegistration?
    
    func fetchLatestMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        senderMessageListener?.remove()
        recipientMessageListener?.remove()
        
        recipientMessageListener = FirebaseManager.shared.firestore
            .collection("messages")
            .document(toId)
            .collection(fromId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for recipient's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestRecipientMessage = ChatMessage(documentId: document.documentID, data: data)
                }
            }
    }
    
    func stopListening(){
        senderMessageListener?.remove()
        senderMessageListener = nil
        recipientMessageListener?.remove()
        recipientMessageListener = nil
    }
    
    @Published var lastState = false
    
    func handleSend() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let recipientActiveStatusRef = FirebaseManager.shared.firestore
            .collection("activeStatus")
            .document(toId)
            .collection("activeList")
            .document(fromId)
        
        recipientActiveStatusRef.getDocument { snapshot, error in
            if let error = error {
                print("Failed to fetch recipient active status: \(error)")
                return
            }
            
            let isRecipientActiveToMe = snapshot?.data()?["isActive"] as? Bool ?? false
            
            
            let messageData: [String: Any] = [
                "fromId": fromId,
                "toId": toId,
                "text": self.chatText,
                "timeStamp": Timestamp(),
                "seen": isRecipientActiveToMe, // Mark as seen if the recipient is active
                "sender": "Me"
            ]
            
            if self.chatText == self.latestSenderMessage?.text && (self.lastState == isRecipientActiveToMe || (self.lastState == true && isRecipientActiveToMe == false)){
                return  // Skip sending
            }
            
            self.lastState = isRecipientActiveToMe
            
            let messageRef = FirebaseManager.shared.firestore
                .collection("messages")
                .document(fromId)
                .collection(toId)
                .document() // Generate a new document ID
            
            messageRef.setData(messageData) { error in
                if let error = error {
                    self.errorMessage = "Failed to send message: \(error)"
                    return
                }
                
                // Update the latest sender message
                self.latestSenderMessage = ChatMessage(
                    documentId: messageRef.documentID,
                    data: messageData
                )
                
                // Update friend list timestamps
                self.updateFriendLatestMessageTimestampForRecipient(friendId: toId)
                self.updateFriendLatestMessageTimestampForSelf(friendId: toId)
            }
        }
    }
    
    // 更新当前用户好友列表中的好友的 latestMessageTimestamp
    private func updateFriendLatestMessageTimestampForSelf(friendId: String) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let timestamp = Timestamp()
        
        let friendRef = FirebaseManager.shared.firestore
            .collection("friends")
            .document(uid)
            .collection("friend_list")
            .document(friendId)
        
        friendRef.updateData(["latestMessageTimestamp": timestamp]) { error in
            if let error = error {
                print("Failed to update latestMessageTimestamp for friend: \(error)")
                return
            }
            print("Successfully updated latestMessageTimestamp for friend")
        }
    }
    
    private func updateFriendLatestMessageTimestampForRecipient(friendId: String) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let timestamp = Timestamp()
        
        let friendRef = FirebaseManager.shared.firestore
            .collection("friends")
            .document(friendId)
            .collection("friend_list")
            .document(uid)
        
        friendRef.updateData(["latestMessageTimestamp": timestamp]) { error in
            if let error = error {
                print("Failed to update latestMessageTimestamp for friend: \(error)")
                return
            }
            print("Successfully updated latestMessageTimestamp for friend")
        }
    }
    // Save the message to Firebase
    func saveMessage(sender: String, messageText: String, timestamp: Timestamp) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let saveData: [String: Any] = [
            FirebaseConstants.sender: sender,
            FirebaseConstants.text: messageText,
            "timestamp": timestamp,
            "fromId": fromId,
            "toId": toId
        ]
        
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .addDocument(data: saveData) { error in
                if let error = error {
                    self.errorMessage = "Failed to save message: \(error)"
                    return
                }
                print("Message saved successfully.")
            }
        
        FirebaseManager.shared.firestore
            .collection("saving_trigger")
            .document(toId)
            .collection("trigger_list")
            .document(fromId)
            .setData(["triggering": true], merge: true) { error in
                if let error = error {
                    print("Failed to trigger \(error)")
                } else {
                    print("Trigger Successfully")
                }
            }
        
    }
    
    func saveMessageForSelf(sender: String, messageText: String, timestamp: Timestamp) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let saveData: [String: Any] = [
            FirebaseConstants.sender: sender,
            FirebaseConstants.text: messageText,
            "timestamp": timestamp,
            "fromId": fromId,
            "toId": toId
        ]
        
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .addDocument(data: saveData) { error in
                if let error = error {
                    self.errorMessage = "Failed to save message: \(error)"
                    return
                }
                print("Message saved successfully.")
            }
    }
    
    deinit {
        stopAutoSend()
        stopListening()
        stopListeningForActiveStatus()
        stopListeningForSavingTrigger()
        stopListeningForImages()
    }
    
}

struct ChatLogView: View {
    @ObservedObject var vm: ChatLogViewModel
    @State private var navigateToMainMessageView = false
    @FocusState private var isInputFocused: Bool
    @State private var isAppInBackground = false
    @Environment(\.presentationMode) var presentationMode
    @State private var currentTime = Date()
    @State private var showImageViewer = false
    @State private var currentImageIndex = 0
    @State private var showCameraPicker = false
    
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
            ZStack{
                Image("chatlogviewbackground")
                    .resizable()
                    .ignoresSafeArea(.all, edges: .all)
                VStack{
                    let topbarheight = UIScreen.main.bounds.height * 0.07
                    HStack{
                        Button(action: {
                            navigateToMainMessageView = true
                            presentationMode.wrappedValue.dismiss()
                            vm.stopAutoSend()
                            vm.stopListening()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.leading, 20)
                            //.padding(8)
                        }
                        
                        Spacer()
                        Image("auroratext")
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width * 0.1832, height: UIScreen.main.bounds.height * 0.0198)
                        //.padding(12)
                        
                        Spacer()
                        if let chatUser=vm.chatUser{
                            NavigationLink(destination: ProfileView(
                                chatUser: chatUser,
                                currentUser: getCurrentUser(),
                                isCurrentUser: false
                            )) {
                                Image("chatlogviewthreedotsbutton")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 20)
                                //.padding(8)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                generateHapticFeedbackMedium()
                            })
                        }
                    }
                    //.background(Color.white)
                    .frame(height: topbarheight)
                    
                    let geoheight = UIScreen.main.bounds.height - topbarheight - UIScreen.main.bounds.height * 0.455 //不许动
                    GeometryReader { geometry in
                        let width = geometry.size.width * 0.895 // 90% of screen width
                        let height = width * 0.549
                        VStack(spacing: 16){
                            ZStack {
                                // Background Image
                                Image("chatlogviewwhitebox")
                                    .resizable()
                                    .frame(width: width, height: height)
                                
                                // Content
                                VStack(spacing: 12) { // 12 points of spacing between sections
                                    // HStack for Profile Photo
                                    HStack {
                                        if let chatUser = vm.chatUser {
                                            NavigationLink(destination: ProfileView(
                                                chatUser: chatUser,
                                                currentUser: getCurrentUser(),
                                                isCurrentUser: false
                                            )) {
                                                WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 42, height: 42)
                                                    .clipShape(Circle())
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let username = vm.chatUser?.username {
                                                Text(username)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75)) // Set text color
                                            } else {
                                                Text("Unknown User") // Fallback text
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            if vm.isChatUserActive {
                                                Text("Active now")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.gray)
                                            } else if let lastSeen = vm.chatUserLastSeen {
                                                let timeInterval = currentTime.timeIntervalSince(lastSeen.dateValue())
                                                let lastSeenText = formatTimeInterval(timeInterval)
                                                Text("Active \(lastSeenText) ago")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.gray)
                                            } else {
                                                Text("Offline")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color.gray)
                                            }
                                        }
                                        .padding(.leading, 7)
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)
                                    
                                    // Scrollable Text Section
                                    GeometryReader { geometry in
                                        ScrollViewReader{ scrollProxy in
                                            VStack {
                                                Spacer(minLength: 0) // Top Spacer
                                                
                                                if let recipientMessage = vm.latestRecipientMessage {
                                                    ScrollView {
                                                        VStack {
                                                            // Calculate dynamic spacing based on the number of lines
                                                            Spacer(minLength: {
                                                                let maxWidth = geometry.size.width - 40
                                                                let fontHeight = UIFont.systemFont(ofSize: 18).lineHeight
                                                                let lineCount = recipientMessage.text.boundingRect(
                                                                    with: CGSize(width: maxWidth, height: .infinity),
                                                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                    attributes: [.font: UIFont.systemFont(ofSize: 18)],
                                                                    context: nil
                                                                ).height / fontHeight
                                                                
                                                                if lineCount <= 1 {
                                                                    return max((geometry.size.height - 20) / 2, 0)
                                                                } else if lineCount == 2 {
                                                                    return max((geometry.size.height - 45) / 1.7, 0)
                                                                } else {
                                                                    return 0 // For 3+ lines, no additional spacer
                                                                }
                                                            }())
                                                            
                                                            Text(recipientMessage.text)
                                                                .font(Font.system(size: 18))
                                                                .multilineTextAlignment(.center)
                                                                .foregroundColor(Color(red: 0.553, green: 0.525, blue: 0.525))
                                                                .frame(maxWidth: geometry.size.width - 40)
                                                                .padding(.horizontal, 20)
                                                        }
                                                    }
                                                    .onChange(of: recipientMessage.text) { _ in
                                                        // Scroll to the latest message when the text changes
                                                        withAnimation {
                                                            scrollProxy.scrollTo("recipientMessage", anchor: .bottom)
                                                        }
                                                    }
                                                }
                                                
                                                Spacer(minLength: 0) // Bottom Spacer
                                            }
                                        }
                                    }
                                    
                                    // HStack for Save Button
                                    HStack {
                                        if vm.hasUnseenImages {
                                            Button(action: {
                                                showImageViewer = true
                                                currentImageIndex = 0
                                            }) {
                                                Image(systemName: "photo.stack")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 24, height: 24)
                                                    .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                                    .padding(.leading, 30)
                                            }
                                            .sheet(isPresented: $showImageViewer) {
                                                ImageViewerView(images: vm.receivedImages, currentIndex: $currentImageIndex) { index in
                                                    vm.deleteImage(at: index)
                                                    if vm.receivedImages.isEmpty {
                                                        showImageViewer = false
                                                    }
                                                }
                                            }
                                        }
                                        Spacer()
                                        // Camera button
                                        
                                        
                                        if let recipientMessage = vm.latestRecipientMessage, !recipientMessage.text.isEmpty {
                                            Button(action: {
                                                vm.saveMessage(sender: vm.chatUser?.username ?? "", messageText: recipientMessage.text, timestamp: recipientMessage.timeStamp)
                                                generateHapticFeedbackHeavy()
                                            }) {
                                                if #available(iOS 18.0, *) {
                                                    // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: false)
                                                        .frame(width: 24, height: 24)
                                                } else {
                                                    // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: true)
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                            .padding(.trailing, 20)
                                        }
                                    }
                                    .padding(.bottom, 24)
                                }
                            }
                            //.background(Color.blue) // ZStack background color
                            .frame(width: width, height: height)
                            
                            
                            ZStack {
                                // Background Image
                                Image("chatlogviewpurplebox")
                                    .resizable()
                                    .frame(width: width, height: height)
                                
                                // Top-left Seen/Unseen Button
                                VStack {
                                    HStack {
                                        if let senderMessage = vm.latestSenderMessage {
                                            if senderMessage.seen {
                                                Image("Seen")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 44, height: 20)
                                            } else {
                                                Image("Unseen")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 44, height: 20)
                                            }
                                        }
                                        if vm.savingTrigger{
                                            Image("savedbutton")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 44, height: 20)
                                                .onAppear{
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0){
                                                        vm.setTriggerToFalse()
                                                    }
                                                }
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)
                                    
                                    Spacer() // Push everything else below
                                }
                                
                                // Centered Text Input
                                VStack {
                                    Spacer() // Push TextEditor down
                                    
                                    ZStack(alignment: .center) {
                                        GeometryReader { geometry in
                                            ScrollViewReader { scrollProxy in
                                                ScrollView {
                                                    VStack {
                                                        // Dynamic vertical spacer
                                                        Spacer(minLength: {
                                                            let maxWidth = geometry.size.width - 40
                                                            let fontHeight = UIFont.systemFont(ofSize: 18).lineHeight
                                                            let lineCount = vm.chatText.boundingRect(
                                                                with: CGSize(width: maxWidth, height: .infinity),
                                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                attributes: [.font: UIFont.systemFont(ofSize: 18)],
                                                                context: nil
                                                            ).height / fontHeight
                                                            
                                                            if lineCount <= 1 {
                                                                return max((geometry.size.height - 20) / 2, 0)
                                                            } else if lineCount == 2 {
                                                                return max((geometry.size.height - 45) / 1.7, 0)
                                                            } else {
                                                                return 0 // No additional spacer for 3+ lines
                                                            }
                                                        }())
                                                        
                                                        // Centered TextEditor
                                                        TextEditor(text: $vm.chatText)
                                                            .font(Font.system(size: 18))
                                                            .foregroundColor(Color(red: 0.553, green: 0.525, blue: 0.525))
                                                            .focused($isInputFocused)
                                                            .multilineTextAlignment(.center)
                                                            .background(Color.clear)
                                                            .scrollContentBackground(.hidden)
                                                            .frame(maxWidth: .infinity, minHeight: 50)
                                                            .padding(.horizontal, 20)
                                                            .tint(Color.gray)
                                                            .id("TextEditor") // Assign an ID for scrolling
                                                    }
                                                    .onChange(of: vm.chatText) { _ in
                                                        // Automatically scroll to the cursor
                                                        withAnimation {
                                                            scrollProxy.scrollTo("TextEditor", anchor: .bottom)
                                                        }
                                                    }
                                                }
                                                .onTapGesture {
                                                    isInputFocused = false // Dismiss keyboard when tapping outside
                                                }
                                            }
                                        }
                                        // Placeholder Text
                                        if vm.chatText.isEmpty {
                                            Text("Type a message...")
                                                .foregroundColor(Color.gray.opacity(0.5))
                                                .font(Font.system(size: 18))
                                                .padding(.horizontal, 4)
                                        }
                                        
                                    }
                                    .frame(height: 60)
                                    .padding(.top, 5)
                                    .padding(.horizontal, 20)
                                    
                                    Spacer()
                                }
                                .onAppear {
                                    isInputFocused = true // Auto-focus the TextEditor
                                }
                                
                                // Bottom Save and Clear Buttons
                                VStack {
                                    Spacer() // Push buttons to the bottom
                                    HStack(spacing: 16) { // 20-point spacing between buttons
                                        Spacer()

                                        // 直接拍照
                                        Button(action: {
                                            showCameraPicker = true
                                            generateHapticFeedbackMedium()
                                        }) {
                                            Image(systemName: "camera.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                        }
                                        .sheet(isPresented: $showCameraPicker) {
                                            ImagePicker(image: $vm.selectedImage, sourceType: .camera)
                                                .onChange(of: vm.selectedImage) { newImage in
                                                    if let image = newImage {
                                                        vm.handleImageSelection(image: image)
                                                        vm.selectedImage = nil
                                                    }
                                                }
                                        }

                                        // Camera button
                                        Button(action: {
                                            vm.showImagePicker = true
                                            generateHapticFeedbackMedium()
                                        }) {
                                            Image(systemName: "photo.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 24, height: 24)
                                                .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                        }
                                        // Add these modifiers to your view
                                        .sheet(isPresented: $vm.showImagePicker) {
                                            ImagePicker(image: $vm.selectedImage)
                                                .onChange(of: vm.selectedImage) { newImage in
                                                    if let image = newImage {
                                                        vm.handleImageSelection(image: image)
                                                        vm.selectedImage = nil
                                                    }
                                                }
                                        }
                                        if !vm.chatText.isEmpty {
                                            Button(action: {
                                                vm.saveMessageForSelf(sender: "Me", messageText: vm.chatText, timestamp: Timestamp())
                                                generateHapticFeedbackHeavy()
                                            }) {
                                                if #available(iOS 18.0, *) {
                                                    // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: false)
                                                        .frame(width: 24, height: 24)
                                                } else {
                                                    // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: true)
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                        }
                                        
                                        Button(action: {
                                            generateHapticFeedbackHeavy()
                                            vm.chatText = ""
                                        }) {
                                            if #available(iOS 18.0, *) {
                                                // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                LottieAnimationViewContainer(filename: "Clear Button", isInteractive: false)
                                                    .frame(width: 24, height: 24)
                                            } else {
                                                // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                LottieAnimationViewContainer(filename: "Clear Button", isInteractive: true)
                                                    .frame(width: 24, height: 24)
                                            }
                                        }
                                    }
                                    .padding(.trailing, 20) // Align to the right
                                    .padding(.bottom, 24)  // Spacing from bottom edge
                                }
                            }
                            //.background(Color.blue)
                            .frame(width: width, height: height)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    //.background(Color.blue)
                    .frame(height: geoheight)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            vm.initializeMessages()
            vm.startAutoSend()
            vm.setActiveStatusToTrue()
            vm.markLatestMessageAsSeen()
            addAppLifecycleObservers()
            vm.startListeningForActiveStatus()
            vm.startListeningForSavingTrigger()
            vm.fetchLatestMessages()
            vm.startListeningForImages()
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            vm.stopAutoSend()
            vm.markMessageAsSeen(for: vm.chatUser?.uid ?? "")
            vm.setActiveStatusToFalse()
            removeAppLifecycleObservers()
            vm.stopListeningForActiveStatus()
            vm.stopListeningForSavingTrigger()
            vm.stopListening()
            vm.stopListeningForImages()
        }
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width > 100 {
                        presentationMode.wrappedValue.dismiss()
                        navigateToMainMessageView = true
                    }
                }
        )
        .navigationBarBackButtonHidden(true)
    }
    
    @State private var backgroundObserver: NSObjectProtocol?
    @State private var foregroundObserver: NSObjectProtocol?
    
    private func addAppLifecycleObservers() {
        // Save references to the observers
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            isAppInBackground = true
            appWentToBackground()
        }
        
        self.foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            isAppInBackground = false
            appCameToForeground()
        }
    }
    
    private func removeAppLifecycleObservers() {
        if let backgroundObserver = backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        
        if let foregroundObserver = foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }
    
    private func appWentToBackground() {
        print("App went to background")
        vm.stopAutoSend()
        vm.stopListening()
        vm.setActiveStatusToFalse()
    }
    
    private func appCameToForeground() {
        print("App came to foreground")
        vm.startAutoSend()
        vm.fetchLatestMessages()
        vm.setActiveStatusToTrue()
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
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return "\(days) day\(days > 1 ? "s" : "")"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes > 1 ? "s" : "")"
        } else if seconds > 0 {
            return "\(seconds) second\(seconds > 1 ? "s" : "")"
        } else {
            return "just"
        }
    }
    
}

struct LottieAnimationViewContainer: UIViewRepresentable {
    var filename: String
    var isInteractive: Bool
    
    class Coordinator: NSObject {
        var animationView: LottieAnimationView?
        
        @objc func handleTap() {
            animationView?.play()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: filename)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.isUserInteractionEnabled = false // Disable direct interaction
        
        containerView.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])
        
        context.coordinator.animationView = animationView
        
        if isInteractive {
            // Add tap gesture recognizer to the containerView
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
            containerView.addGestureRecognizer(tapGesture)
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let animationView = context.coordinator.animationView {
            if !isInteractive {
                animationView.currentFrame = 0
            }
        }
    }
}

struct ImageViewerView: View {
    let images: [String]
    @Binding var currentIndex: Int
    let onDelete: (Int) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var progress: CGFloat = 0
    @State private var isPaused = false
    @State private var opacity: Double = 1.0
    @State private var timer: Timer?
    @State private var offset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var isTransitioning = false
    @State private var startTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @GestureState private var dragState = CGSize.zero
    @GestureState private var isPressed = false
    
    private let duration: TimeInterval = 5.0
    private let updateInterval: TimeInterval = 0.01
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if !images.isEmpty {
                    GeometryReader { geometry in
                        WebImage(url: URL(string: images[currentIndex]))
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(x: offset.width + dragState.width, y: offset.height + dragState.height)
                            .opacity(opacity)
                            .animation(.interactiveSpring(), value: dragState)
                            .animation(.easeInOut(duration: 0.3), value: opacity)
                            .gesture(
                                DragGesture()
                                    .updating($dragState) { value, state, _ in
                                        if !isTransitioning {
                                            state = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        guard !isTransitioning else { return }
                                        handleDragGesture(value)
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        if !isTransitioning {
                                            scale = value.magnitude
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                        }
                                    }
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress, height: 2)
                            .animation(.linear(duration: updateInterval), value: progress)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($isPressed) { _, state, _ in
                                state = true
                            }
                    )
                
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            if !isTransitioning {
                                handleNextAndDelete()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if currentIndex >= images.count - 1 {
                                    Text("Cancel")
                                        .font(.system(size: 16, weight: .regular))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .medium))
                                } else {
                                    Text("Next")
                                        .font(.system(size: 16, weight: .regular))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            .onChange(of: isPressed) { newValue in
                isPaused = newValue
            }
            .onAppear {
                startTimer()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    private func handleNextAndDelete() {
        guard !isTransitioning else { return }
        isTransitioning = true
        timer?.invalidate()
        
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let isLastImage = currentIndex >= images.count - 1
            onDelete(currentIndex)
            
            if isLastImage {
                // If it was the last image, dismiss the viewer
                presentationMode.wrappedValue.dismiss()
            } else {
                // Stay at the same index since the array has shifted
                progress = 0
                elapsedTime = 0
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1
                }
                isTransitioning = false
                startTimer()
            }
        }
    }
    
    private func handleDragGesture(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        if value.translation.width > threshold {
            deleteCurrentImage()
        } else if abs(value.translation.height) > threshold {
            dismissViewer()
        } else {
            withAnimation(.interactiveSpring()) {
                offset = .zero
            }
        }
    }
    
    private func deleteCurrentImage() {
        guard !isTransitioning else { return }
        isTransitioning = true
        timer?.invalidate()
        
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDelete(currentIndex)
            if currentIndex >= images.count - 1 {
                currentIndex = max(0, images.count - 2)
            }
            progress = 0
            elapsedTime = 0
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
            isTransitioning = false
            startTimer()
        }
    }
    
    private func dismissViewer() {
        guard !isTransitioning else { return }
        isTransitioning = true
        timer?.invalidate()
        
        withAnimation(.easeOut(duration: 0.3)) {
            offset = dragState
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        startTime = Date()
        elapsedTime = 0
        progress = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            guard !isPaused else {
                startTime = Date().addingTimeInterval(-elapsedTime)
                return
            }
            
            elapsedTime = Date().timeIntervalSince(startTime ?? Date())
            progress = min(CGFloat(elapsedTime / duration), 1.0)
            
            if elapsedTime >= duration {
                handleNextAndDelete()
            }
        }
    }
}
