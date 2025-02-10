//
//  VerifyView.swift
//  Synx
//
//  Created by Zifan Deng on 11/29/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct ChangeEmailView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var currentUser: User? = FirebaseManager.shared.auth.currentUser
    @State private var hasEmail: Bool = false
    @State private var hasPhone: Bool = false
    
    @State private var nonce: String? // Apple Sign-In nonce
    
    @State private var errorMessage: String = ""
    
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
                            generateHapticFeedbackMedium()
                            dismiss() // Dismiss the view when back button is pressed
                        }) {
                            Image("chatlogviewbackbutton") // Replace with your back button image
                                .resizable()
                                .frame(width: 24, height: 24) // Customize this color
                        }
                        Spacer()
                        Text("Manage Linked Accounts")
                            .font(.system(size: 20, weight: .bold)) // Customize font style
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255)) // Customize text color
                        Spacer()
                        Image("spacerformainmessageviewtopleft") // Replace with your back button image
                            .resizable()
                            .frame(width: 24, height: 24) // To balance the back button
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    HStack{
                        Text("Link accounts so you have another way to verify just in case you lose your phone number.")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(.gray))
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                        Spacer()
                    }
        
                    
                    VStack(spacing: 20) {
                        googleSignInButton
                        appleSignInButton
                        changePhoneNavigationLink
                    }
                    .padding(.horizontal)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                            .padding(.top)
                    }
                    Spacer()
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                checkUserProviders()
            }
        }
        .navigationBarBackButtonHidden(true)
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
            .overlay(
                RoundedRectangle(cornerRadius: 23)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
            )
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
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .cornerRadius(23)
        .padding(.horizontal, 20)
    }
    
    // Change Phone Number Button
    private var changePhoneNavigationLink: some View {
        NavigationLink(destination: ChangePhoneView { message in
            self.errorMessage = message
        }) {
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundColor(Color.white)
                    
                    Text("Continue with Phone")
                        .font(.system(size: 16.5, weight: .medium))
                        .foregroundColor(Color.white)
                }
                
                Spacer()
            }
            .frame(height: 44)
            .background(Color(red: 0.49, green: 0.52, blue: 0.75))
            .cornerRadius(23)
            .padding(.horizontal, 20)
        }
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




#Preview {
    ChangeEmailView()
}
