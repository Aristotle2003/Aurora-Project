import SwiftUI
import Firebase
import SDWebImageSwiftUI

struct FriendRequestsView: View {
    
    @State var currentUser: ChatUser
    @State private var friendRequests = [FriendRequest]()
    @State private var errorMessage = ""
    @State private var navigateToMainMessage = false
    @Environment(\.presentationMode) var presentationMode
    @Binding var currentView: String
    
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
        NavigationStack{
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack {
                    
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        Text("Friend Requests")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        Spacer()
                        Image("spacerformainmessageviewtopleft")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    if friendRequests.isEmpty {
                        Text("No friend requests")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    } else {
                        ScrollView{
                            VStack(spacing: 12) {
                                ForEach(friendRequests) { request in
                                    HStack(spacing: 16) {
                                        // Profile Picture
                                        WebImage(url: URL(string: request.profileImageUrl))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                        
                                        // Friend Request Message
                                        Text("\(request.username) has sent you a friend request.")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(.gray))
                                        
                                        Spacer()
                                        
                                        // Accept Button with Custom Image
                                        Button(action: {
                                            acceptFriendRequest(request)
                                            generateHapticFeedbackMedium()
                                        }) {
                                            Image("acceptbuttonforfriendrequestview")
                                                .resizable()
                                                .frame(width: 63, height: 24)
                                        }
                                        
                                        // Reject Button with Custom Image
                                        Button(action: {
                                            rejectFriendRequest(request)
                                            generateHapticFeedbackMedium()
                                        }) {
                                            Image("crossbuttonforfriendrequestview")
                                                .resizable()
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    Spacer()

                }
            }
            .onAppear{
                fetchFriendRequests()
            }
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.width > 100 {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
            )
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToMainMessage) {
                MainMessagesView(currentView: $currentView)
            }
        }
    }

    // Fetch friend requests
    private func fetchFriendRequests() {
        print("Fetching friend requests for user ID: \(currentUser.uid)")

        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(currentUser.uid)
            .collection("request_list")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch friend requests: \(error)"
                    print("Error fetching friend requests:", error)
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.errorMessage = "No friend requests found"
                    print("No friend requests found for user \(currentUser.uid)")
                    return
                }

                self.friendRequests = documents.map { document in
                    let data = document.data()
                    return FriendRequest(documentId: document.documentID, data: data)
                }

                // Fetch detailed user info for each friend request
                self.fetchFriendRequestDetails()
            }
    }

private func fetchFriendRequestDetails() {
    for (index, request) in friendRequests.enumerated() {
        FirebaseManager.shared.firestore
            .collection("users")
            .document(request.fromId)
            .getDocument { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch user info: \(error)"
                    print("Error fetching user info:", error)
                    return
                }

                guard let data = snapshot?.data() else {
                    self.errorMessage = "No user data found"
                    print("No user data found for UID \(request.fromId)")
                    return
                }

                let username = data["username"] as? String ?? ""
                let fromEmail = data["email"] as? String ?? ""
                let profileImageUrl = data["profileImageUrl"] as? String ?? ""

                self.friendRequests[index].username = username
                self.friendRequests[index].fromEmail = fromEmail
                self.friendRequests[index].profileImageUrl = profileImageUrl
            }
    }
}

    // Accept friend request
    private func acceptFriendRequest(_ request: FriendRequest) {
        // Delete the friend request document
        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(currentUser.uid)
            .collection("request_list")
            .document(request.documentId)
            .delete { error in
                if let error = error {
                    self.errorMessage = "Failed to delete friend request: \(error)"
                    return
                }

                // Save sender's data in current user's Friends collection
                let senderData: [String: Any] = [
                    "uid": request.fromId,
                    "email": request.fromEmail,
                    "profileImageUrl": request.profileImageUrl,
                    "username": request.username
                ]

                FirebaseManager.shared.firestore
                    .collection("friends")
                    .document(currentUser.uid)
                    .collection("friend_list")
                    .document(request.fromId)
                    .setData(senderData) { error in
                        if let error = error {
                            self.errorMessage = "Failed to save sender as friend: \(error)"
                            return
                        }

                        // Save current user's data in sender's Friends collection
                        let currentUserData: [String: Any] = [
                            "uid": currentUser.uid,
                            "email": currentUser.email,
                            "profileImageUrl": currentUser.profileImageUrl,
                            "username": currentUser.username
                        ]

                        FirebaseManager.shared.firestore
                            .collection("friends")
                            .document(request.fromId)
                            .collection("friend_list")
                            .document(currentUser.uid)
                            .setData(currentUserData) { error in
                                if let error = error {
                                    self.errorMessage = "Failed to save current user as friend: \(error)"
                                    return
                                }

                                // Remove from friendRequests list
                                self.friendRequests.removeAll { $0.documentId == request.documentId }
                            }
                        
                    }
            }
    }

    // Reject friend request
    private func rejectFriendRequest(_ request: FriendRequest) {
        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(currentUser.uid)
            .collection("request_list")
            .document(request.documentId)
            .delete { error in
                if let error = error {
                    self.errorMessage = "Failed to delete friend request: \(error)"
                    return
                }

                // Remove from friendRequests list
                self.friendRequests.removeAll { $0.documentId == request.documentId }
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

            self.currentUser = ChatUser(data: data)
        }
    }
}

// Model for Friend Request
struct FriendRequest: Identifiable {
    let id = UUID()
    let documentId: String
    let fromId: String
    var fromEmail: String = ""
    var profileImageUrl: String = ""
    var username: String = ""
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data["fromUid"] as? String ?? ""
    }
}

