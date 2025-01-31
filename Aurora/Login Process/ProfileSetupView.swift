import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn


// Profile picture selection view
struct ProfileSetupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLogin: Bool
    let uid: String
    let phone: String
    let email: String
    
    @State private var showImagePicker = false
    @State private var statusMessage = ""
    @State private var image: UIImage?
    @State private var username: String = ""
    @AppStorage("SeenTutorial") private var SeenTutorial: Bool = false
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @FocusState private var focusItem: Bool
    
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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                        .frame(height: 49)
                    
                    Text("")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                    Text("Complete Your Profile")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    
                    Text("Add a profile picture and select a username to continue.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                        .padding(.bottom, 4)
                }
                .padding()
                
                VStack{
                    
                    Button {
                        showImagePicker.toggle()
                        generateHapticFeedbackMedium()
                    } label: {
                        VStack {
                            if let image = self.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 128, height: 128)
                                    .cornerRadius(64)
                            } else {
                                Image("imagepickerpicture")
                                    .frame(width: 132, height: 132)
                                    .padding()
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter your username", text: $username)
                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                        .padding(.horizontal, 16)
                        .focused($focusItem)
                        .toolbar {
                            if focusItem {  // Only show when keyboard is visible
                                ToolbarItemGroup(placement: .confirmationAction) {
                                    Spacer()
                                    Button {
                                        focusItem = false
                                    } label: {
                                        Text("Done")
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                                            .font(.system(size: 17))
                                    }
                                }
                            }
                        }
                        .frame(height: 48)
                        .background(Color.white)
                        .cornerRadius(100)
                    
                    Button {
                        // Cover
                        LoadingManager.shared.show()
                        validateAndPersistUserProfile()
                    } label: {
                        HStack {
                            Spacer()
                            Image(image == nil || username.isEmpty ? "continuebuttonunpressed" : "continuebutton")
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width - 80)
                            Spacer()
                        }
                    }
                    .disabled(image == nil || username.isEmpty)
                    .opacity((image == nil || username.isEmpty) ? 0.6 : 1)
                }
                .padding()
            }
            .navigationBarItems(leading:
                                    Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .fontWeight(.bold)  // Changed from .bold since it's a cancel button
                    .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                    .font(.system(size: 17))
            })
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(image: $image)
        }
    }
    
    
    private func validateAndPersistUserProfile() {
        guard !username.isEmpty else {
            // Cover
            LoadingManager.shared.hide()
            statusMessage = "Username cannot be empty"
            return
        }
        handleImage()
    }
    
    
    private func handleImage() {
        guard let image = self.image else {
            // Cover
            LoadingManager.shared.hide()
            statusMessage = "Please select a profile picture"
            return
        }
        
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                // Cover
                LoadingManager.shared.hide()
                self.statusMessage = "We couldn't upload your profile picture. Please check your internet connection and try again."
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    // Cover
                    LoadingManager.shared.hide()
                    self.statusMessage = "We couldn't process your profile picture. Please try again or choose a different image."
                    return
                }
                guard let url = url else { return }
                self.storeUserInformation(imageProfileUrl: url)
            }
        }
    }
    
    
    private func storeUserInformation(imageProfileUrl: URL) {
        let userData: [String: Any] = [
            "uid": uid,
            "phoneNumber": phone,
            "email": email,
            "profileImageUrl": imageProfileUrl.absoluteString,
            "username": username
        ]
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { err in
                if let err = err {
                    LoadingManager.shared.hide()
                    self.statusMessage = "We couldn't save your profile information. Please check your internet connection."
                    return
                }
                
                saveUsernameToBasicInfo()
                
                self.isLogin = true
                isLoggedIn = true
                LoadingManager.shared.show()
                dismiss()
            }
    }
    
    private func saveUsernameToBasicInfo() {
        let userRef = FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(uid)
            .collection("information")
            .document("profile")
        
        userRef.setData(["username": username], merge: true) { error in
            if let error = error {
                LoadingManager.shared.hide()
                self.statusMessage = "We couldn't save your profile information. Please check your internet connection."
            } else {
                print("Saving username to basic information successfully")
            }
        }
    }
}



