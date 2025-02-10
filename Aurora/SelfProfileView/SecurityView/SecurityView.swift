import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct SecurityView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var currentUser: User? = FirebaseManager.shared.auth.currentUser
    @State private var hasEmail: Bool = false
    @State private var hasPhone: Bool = false
    
    @State private var nonce: String? // Apple Sign-In nonce
    
    @State private var errorMessage: String = ""
    
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    
    @State private var showConfirmationAlert = false
    @State private var isDeleting = false
    @State private var deletionError: String?
    @State private var isUserCurrentlyLoggedOut = false
    @State private var confirmationInput = ""
    @State private var showManageAccount = false
    
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
            ZStack{
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack {
                    // Custom Navigation Header
                    HStack {
                        Button(action: {
                            dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton") // Replace with your back button image
                                .resizable()
                                .frame(width: 24, height: 24) // Customize this color
                        }
                        Spacer()
                        Text("Security")
                            .font(.system(size: 20, weight: .bold)) // Customize font style
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255)) // Customize text color
                        Spacer()
                        Image("spacerformainmessageviewtopleft") // Replace with your back button image
                            .resizable()
                            .frame(width: 24, height: 24) // To balance the back button
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Form {
                        Section(header:
                                    HStack {
                                        Text("Linked Accounts")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(.gray))
                                        Spacer()
                                    }
                        ) {
                            HStack {
                                Text("Phone Number:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                
                                Spacer()
                                
                                Text(phoneNumber.isEmpty ? "Not Linked" : phoneNumber)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            .frame(height: 54)
                            
                            HStack {
                                Text("Email:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                
                                Spacer()
                                
                                Text(email.isEmpty ? "Not Linked" : email)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            .frame(height: 54)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.976, green: 0.980, blue: 1.0))
                    .cornerRadius(32)
                    
                    
                    // Second Section: Buttons
                    
                    
                    Form {
                        Section(header:
                                    HStack {
                                        Text("Manage Linked Accounts")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(.gray))
                                        Spacer()
                                    }
                        ) {
                            Button(action: {
                                showManageAccount = true
                                generateHapticFeedbackMedium()
                            }) {
                                HStack {
                                    Text("Manage linked accounts")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                        }

                        Section(header:
                                    HStack {
                                        Text("Account Actions")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(.gray))
                                        Spacer()
                                    }
                        ) {
                            Button(action: {
                                showConfirmationAlert = true
                                generateHapticFeedbackMedium()
                            }) {
                                HStack {
                                    Text("Delete Account")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.976, green: 0.980, blue: 1.0))
                    .cornerRadius(32)
                    .fullScreenCover(isPresented: $showManageAccount) {
                        ChangeEmailView()
                    }
                    .fullScreenCover(isPresented: $isUserCurrentlyLoggedOut) {
                        LoginView()
                    }
                    
                    Spacer()
                        .frame(height:200)
                    
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top)
                    }
                }
                .sheet(isPresented: $showConfirmationAlert) {
                    ConfirmationDialog(
                        confirmationInput: $confirmationInput,
                        onConfirm: {
                            if confirmationInput == "I want to permanently delete the account" {
                                deleteAccount()
                            } else {
                                deletionError = "You must type the exact confirmation message to delete the account."
                            }
                            showConfirmationAlert = false
                        },
                        onCancel: {
                            showConfirmationAlert = false
                        }
                    )
                }
                .onAppear {
                    checkUserProviders()
                    fetchPhoneNumberAndEmail()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width > 100 {
                        dismiss()
                    }
                }
        )
        .navigationBarBackButtonHidden(true)
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
    
    /// Function to delete the account
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            deletionError = "User not authenticated."
            return
        }
        
        isDeleting = true
        deletionError = nil
        
        let userId = user.uid
        let db = Firestore.firestore()
        
        // Delete user data from Firestore
        db.collection("users").document(userId).delete { error in
            if let error = error {
                self.deletionError = "Failed to delete user data: \(error.localizedDescription)"
                self.isDeleting = false
                return
            }
            
            // Delete the user authentication
            user.delete { authError in
                if let authError = authError {
                    self.deletionError = "Failed to delete user authentication: \(authError.localizedDescription)"
                    self.isDeleting = false
                    return
                }
                
                // Optional: Perform cleanup of any other user-related data
                cleanupUserData(userId: userId) { cleanupError in
                    if let cleanupError = cleanupError {
                        self.deletionError = "Failed to clean up related data: \(cleanupError.localizedDescription)"
                    }
                    self.isDeleting = false
                }
            }
        }
    }
    
    /// Cleanup other user-related data in Firestore (e.g., messages, posts)
    func cleanupUserData(userId: String, completion: @escaping (Error?) -> Void) {
        let db = Firestore.firestore()
        
        // Example: Remove user-related messages
        let messagesCollection = db.collection("messages")
        messagesCollection.whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(nil)
                return
            }
            
            let batch = db.batch()
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            batch.commit { batchError in
                completion(batchError)
            }
        }
    }
    
    private func fetchPhoneNumberAndEmail(){
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
            self.phoneNumber = data["phoneNumber"] as? String ?? ""
            self.email = data["email"] as? String ?? ""
            
        }
    }
    
    // Google Sign-In Button
    private var googleSignInButton: some View {
        Button {
            handleGoogleSignIn()
            generateHapticFeedbackMedium()
        } label: {
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Image("googleicon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    
                    Text("Continue with Google")
                        .font(.system(size: 16.5, weight: .medium))
                        .foregroundColor(Color(red: 0.231, green: 0.231, blue: 0.231))
                }
                
                Spacer()
            }
            .frame(height: 44)
            .background(Color.white)
            .cornerRadius(23)
            .padding(.horizontal, 20)
        }
    }
    
    // Apple Sign-In Button
    private var appleSignInButton: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = randomNonceString()
            self.nonce = nonce
            request.requestedScopes = [.email, .fullName]
            request.nonce = sha256(nonce)
            generateHapticFeedbackMedium()
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                handleAppleSignIn(authorization)
            case .failure(let error):
                errorMessage = "Error signing in with Apple: \(error.localizedDescription)"
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .cornerRadius(12)
    }
    
    
    
    
    
    
    // MARK: Functions start here
    // Google Sign-In Handler
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseManager.shared.auth.app?.options.clientID else {
            errorMessage = "Error getting client ID"
            return
        }
        
        // Create Google Sign-In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Error getting root view controller"
            return
        }
        
        // Start the sign-in flow.
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                errorMessage = "Error signing in with Google: \(error.localizedDescription)"
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                errorMessage = "Error getting user data"
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            // Handle linking logic based on the current account state
            handleLinking(with: credential, providerID: "google.com")
        }
    }
    
    
    
    
    
    
    
    // Apple Sign-In Handler
    private func handleAppleSignIn(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = nonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                errorMessage = "Unable to fetch identity token"
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to serialize token string from data: \(appleIDToken.debugDescription)"
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            // Handle linking logic based on the current account state
            handleLinking(with: credential, providerID: "apple.com")
        }
    }
    
    
    
    
    
    
    // Main function to handle linking and unlinking logic
    private func handleLinking(with credential: AuthCredential, providerID: String) {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            self.errorMessage = "No current user found"
            return
        }
        
        // Check existing linked providers
        let emailProviders = currentUser.providerData.filter { $0.providerID != PhoneAuthProviderID }
        
        if emailProviders.isEmpty {
            // If signed in with only phone, link the provided credential
            linkCredentialAndUpdateDatabase(credential: credential)
        } else {
            // If signed in with both phone and email, unlink all email providers first
            unlinkAllEmailProviders { success in
                if success {
                    // After unlinking, link the provided credential
                    linkCredentialAndUpdateDatabase(credential: credential)
                } else {
                    self.errorMessage = "Error unlinking existing email providers"
                }
            }
        }
    }
    
    
    
    
    // Method to unlink all email-based providers (Google, Apple) and invoke a completion handler
    private func unlinkAllEmailProviders(completion: @escaping (Bool) -> Void) {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            self.errorMessage = "No current user found"
            completion(false)
            return
        }
        
        // Identify email-based providers
        let emailProviders = currentUser.providerData.filter { $0.providerID != PhoneAuthProviderID }
        let group = DispatchGroup()
        var unlinkingError: Error?
        
        // Unlink each provider
        for provider in emailProviders {
            group.enter()
            currentUser.unlink(fromProvider: provider.providerID) { _, error in
                if let error = error {
                    unlinkingError = error
                    print("Error unlinking provider \(provider.providerID): \(error.localizedDescription)")
                } else {
                    print("Successfully unlinked provider: \(provider.providerID)")
                }
                group.leave()
            }
        }
        
        // Call completion handler after all unlinking is complete
        group.notify(queue: .main) {
            if let error = unlinkingError {
                self.errorMessage = "Error unlinking providers: \(error.localizedDescription)"
                completion(false)
            } else {
                print("All email providers unlinked successfully.")
                completion(true)
            }
        }
    }
    
    
    
    
    
    
    
    
    // Combined helper function to link credential, update Firebase email, and update database
    private func linkCredentialAndUpdateDatabase(credential: AuthCredential) {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            self.errorMessage = "No current user found"
            return
        }
        
        // Link the provided credential
        currentUser.link(with: credential) { authResult, error in
            if let error = error {
                self.errorMessage = "Error linking account: \(error.localizedDescription)"
                return
            }
            
            // Fetch the linked email
            guard let linkedEmail = authResult?.user.providerData.first(where: { $0.providerID != PhoneAuthProviderID })?.email else {
                self.errorMessage = "Error fetching linked email."
                return
            }
            // Update the user's email in Firebase Authentication
            currentUser.updateEmail(to: linkedEmail) { error in
                if let error = error {
                    self.errorMessage = "Error updating email in Firebase Auth: \(error.localizedDescription)"
                    print("Error updating email in Firebase Auth: \(error.localizedDescription)")
                    return
                }
                
                print("Successfully updated email in Firebase Auth to \(linkedEmail)")
                
                // Update Firestore
                let db = Firestore.firestore()
                let userId = currentUser.uid
                
                db.collection("users").document(userId).updateData([
                    "email": linkedEmail
                ]) { error in
                    if let error = error {
                        self.errorMessage = "Error updating email in Firestore: \(error.localizedDescription)"
                        print("Error updating email in Firestore: \(error.localizedDescription)")
                    } else {
                        print("Successfully updated email in Firestore to \(linkedEmail)")
                    }
                }
            }
        }
    }
    // MARK: Helper Functions
    // Checking if the user has phone or email or both
    private func checkUserProviders() {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else { return }
        
        // Check providers
        for userInfo in currentUser.providerData {
            switch userInfo.providerID {
            case "phone":
                hasPhone = true
            case "google.com", "apple.com", "password":
                hasEmail = true
            default:
                break
            }
        }
    }
    
    
    // Helper: Generate Random Nonce
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    // Helper: SHA256 Hashing
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
    
    
    
}
/// Custom confirmation dialog
struct ConfirmationDialog: View {
    @Binding var confirmationInput: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Confirm Account Deletion")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            Text("To confirm deletion, type:")
                .font(.body)
            Text("\"I want to permanently delete the account\"")
                .font(.headline)
                .foregroundColor(.red)
            
            TextField("Type the message here", text: $confirmationInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Button("Delete") {
                    onConfirm()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

