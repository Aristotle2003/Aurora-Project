//
//  SelfProvileView.swift
//  Synx
//
//  Created by Shawn on 11/26/24.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct SelfProfileView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    let chatUser: ChatUser
    @State var currentUser: ChatUser
    let isCurrentUser: Bool
    let showTemporaryImg: Bool
    @State var errorMessage = ""
    @State var isFriend: Bool = false
    @State var friendRequestSent: Bool = false
    @State var basicInfo: BasicInfo? = nil // For current user
    @State var otherUserInfo: BasicInfo? = nil // For other users
    @State private var showReportSheet = false
    @State private var reportContent = ""
    @State private var showDeleteConfirmation = false
    @State private var navigateToMainMessagesView = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var showConfirmationDialog = false
    @State private var savingImageUrl = ""
    @State private var showTemporaryImage = false
    @State private var shouldShowLogOutOptions = false
    @State private var isUserCurrentlyLoggedOut = false
    @State private var showPrivacyPage = false
    @State private var isLoading = false
    
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    @StateObject private var messagesViewModel = MessagesViewModel()
    @Environment(\.presentationMode) var presentationMode
    
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
    
    private func handleSignOut() {
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
            self.isUserCurrentlyLoggedOut.toggle()
            try? FirebaseManager.shared.auth.signOut()
        }
    }
    
    var body: some View {
        NavigationStack{
            ZStack{
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack {
                    let topbarheight = UIScreen.main.bounds.height * 0.055
                    HStack {
                        Spacer()
                        NavigationLink(destination: EditProfileView(currentUser: currentUser, chatLogViewModel: chatLogViewModel)){
                            Image("writedailyaurorabutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.trailing, 20)
                        }
                    }
                    .frame(height: topbarheight)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    ScrollView{
                        if !showTemporaryImage{
                            WebImage(url: URL(string: self.currentUser.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if isCurrentUser {
                                        showImagePicker = true
                                    }
                                }
                        }
                        else{
                            WebImage(url: URL(string: self.savingImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .onTapGesture {
                                    if isCurrentUser {
                                        showImagePicker = true
                                    }
                                }
                        }
                            
                        Spacer()
                            .frame(height: 8)
                        if isLoading {
                            VStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .padding(.top, UIScreen.main.bounds.height * 0.3)
                                Text("Loading your info...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 16)
                                Spacer()
                            }
                        }
                        if isCurrentUser, let info = basicInfo {
                            Text("\(info.username)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 0.337, green: 0.337, blue: 0.337))
                            
                            Text("@\(info.name)")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                            VStack(alignment: .leading) {
                                Text("\(info.bio)")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                    .padding(.horizontal, 12)
                                    .lineLimit(nil) // Allow unlimited lines
                                    .fixedSize(horizontal: false, vertical: true) // Ensure wrapping for long text
                                HStack {
                                    if !info.age.isEmpty{
                                        Text("\(info.age)'ys old")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                            .padding(8)
                                            .background(Color(red: 0.898, green: 0.910, blue: 0.996))
                                            .cornerRadius(50)
                                    }
                                    if !info.pronouns.isEmpty{
                                        Text("\(info.pronouns)")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                            .padding(8)
                                            .background(Color(red: 0.898, green: 0.910, blue: 0.996))
                                            .cornerRadius(50)
                                    }
                                    if !info.location.isEmpty{
                                        Text("\(info.location)")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                            .padding(8)
                                            .background(Color(red: 0.898, green: 0.910, blue: 0.996))
                                            .cornerRadius(50)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.leading, 12)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(8)
                        }
                        
                        Spacer()
                        
                        HStack{
                            Text("General")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(.gray))
                                .padding(.leading, 16)
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                            Spacer()
                        }
                    
                        // New Rectangle Buttons
                        VStack(spacing: 0){
                            /*NavigationLink(destination: EditProfileView(currentUser: currentUser, chatLogViewModel: chatLogViewModel)) {
                             Text("Change Basic Info")
                             .font(.headline)
                             .frame(maxWidth: .infinity, minHeight: 50)
                             .background(Color.green)
                             .foregroundColor(.white)
                             .cornerRadius(8)
                             .padding(.horizontal)
                             }*/
                            
                            Button(action: {
                                showPrivacyPage.toggle()
                                generateHapticFeedbackMedium()
                            }) {
                                Image("privacybuttonforselfprofileview")
                            }
                            // Navigate to Change Email View
                            NavigationLink(destination: SecurityView()) {
                                Image("securitybuttonforselfprofileview")
                            }
                            Button(action: {
                                showReportSheet = true
                                generateHapticFeedbackMedium()
                            }) {
                                Image("reportbuttonforselfprofileview")
                            }
                            HStack{
                                Text("Account Actions")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(.gray))
                                    .padding(.leading, 16)
                                    .padding(.top, 20)
                                    .padding(.bottom, 8)
                                Spacer()
                            }
                            Button(action: {
                                shouldShowLogOutOptions.toggle()
                                generateHapticFeedbackMedium()
                            }) {
                                Image("switchaccountbuttonforselfprofileview")
                            }
                            
                            // Logout Button
                            Button(action: {
                                shouldShowLogOutOptions.toggle()
                                generateHapticFeedbackMedium()
                            }) {
                                Image("logoutbuttonforselfprofileview")
                            }
                        }
                    }
                    .padding()
                    .actionSheet(isPresented: $shouldShowLogOutOptions) {
                        ActionSheet(
                            title: Text("Settings"),
                            message: Text("What do you want to do?"),
                            buttons: [
                                .destructive(Text("Sign Out"), action: {
                                    isLoggedIn = false
                                    handleSignOut()
                                }),
                                .cancel()
                            ]
                        )
                    }
                    .fullScreenCover(isPresented: $isUserCurrentlyLoggedOut) {
                        LoginView()
                    }
                    .fullScreenCover(isPresented: $showPrivacyPage){
                        PrivacyView()
                    }
                    
                    Spacer()
                }
                .onAppear {
                    fetchCurrentUser()
                    checkIfFriend()
                    if isCurrentUser {
                        fetchBasicInfo(for: currentUser.uid) { info in
                            self.basicInfo = info
                        }
                    } else {
                        fetchBasicInfo(for: chatUser.uid) { info in
                            self.otherUserInfo = info
                        }
                    }
                }
                .onDisappear{
                    self.showTemporaryImage = false
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: $selectedImage)
                        .onDisappear {
                            if selectedImage != nil {
                                updateProfilePhoto()
                                print("Image selected successfully!")
                            } else {
                                print("No image selected.")
                            }
                        }
                }
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
                                        generateHapticFeedbackMedium()
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
                                        selfReport()
                                        showReportSheet = false
                                        generateHapticFeedbackMedium()
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
                .onDisappear{
                    self.showTemporaryImage = false
                }
                
                .navigationBarBackButtonHidden(true)
            }
            
        }
        .onDisappear{
            self.showTemporaryImage = false
        }
    }
    
    private func selfReport() {
        let reportData: [String: Any] = [
            "reporterUid": currentUser.uid,
            "reporteeUid": chatUser.uid,
            "timestamp": Timestamp(),
            "content": reportContent // 用户输入的举报内容
        ]
        
        FirebaseManager.shared.firestore
            .collection("reports_for_self")
            .document()
            .setData(reportData) { error in
                if let error = error {
                    print("Failed to report friend: \(error)")
                } else {
                    print("Friend reported successfully")
                }
            }
    }
    
    private func updateProfilePhoto() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        var updatedData: [String: Any] = [:]
        
        if let selectedImage = selectedImage {
            // 上传新头像
            let ref = FirebaseManager.shared.storage.reference(withPath: uid)
            if let imageData = selectedImage.jpegData(compressionQuality: 0.5) {
                ref.putData(imageData, metadata: nil) { metadata, error in
                    if let error = error {
                        print("Failed to upload image: \(error)")
                        return
                    }
                    ref.downloadURL { url, error in
                        if let error = error {
                            print("Failed to get download URL: \(error)")
                            return
                        }
                        if let url = url {
                            updatedData["profileImageUrl"] = url.absoluteString
                            self.savingImageUrl = url.absoluteString
                            self.showTemporaryImage = true
                            self.saveProfilePhotoToCentralDb(uid: uid, data: updatedData)
                        }
                    }
                }
            }
        } else {
            print("Wrong")
        }
    }
    
    private func saveProfilePhotoToCentralDb(uid: String, data: [String: Any]) {
        let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
        userRef.updateData(data) { error in
            if let error = error {
                print("Failed to update profile: \(error)")
                return
            }
            print("Profile updated successfully")
            self.updateProfilePhotoToFriends(uid: uid, data: data)
        }
    }
    
    private func updateProfilePhotoToFriends(uid: String, data: [String: Any]) {
        let friendsRef = FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
        friendsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Failed to fetch friends: \(error)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            for document in documents {
                let friendId = document.documentID
                let friendRef = FirebaseManager.shared.firestore.collection("friends").document(friendId).collection("friend_list").document(uid)
                friendRef.updateData(data) { error in
                    if let error = error {
                        print("Failed to update friend profile: \(error)")
                    } else {
                        print("Friend profile updated successfully")
                    }
                }
            }
        }
    }
    
    private func checkIfFriend() {
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .getDocument { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to check friendship status: \(error)"
                    print("Failed to check friendship status:", error)
                    return
                }
                self.isFriend = snapshot?.exists ?? false
            }
    }
    
    private func fetchBasicInfo(for userId: String, completion: @escaping (BasicInfo?) -> Void) {
        self.isLoading = true
        FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(userId)
            .collection("information")
            .document("profile")
            .getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let info = BasicInfo(
                        age: data["age"] as? String ?? "",
                        gender: data["gender"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        bio: data["bio"] as? String ?? "",
                        location: data["location"] as? String ?? "",
                        username: data["username"] as? String ?? "",
                        birthdate: data["birthdate"] as? String ?? "",
                        pronouns: data["pronouns"] as? String ?? "",
                        name: data["name"] as? String ?? ""
                    )
                    self.isLoading = false
                    completion(info)
                } else if let error = error {
                    print("Error fetching basic information: \(error)")
                    completion(nil) // Explicitly return nil if an error occurs
                } else {
                    print("No data found for userId: \(userId)")
                    completion(nil) // Explicitly return nil if no data is found
                }
            }
    }
}
