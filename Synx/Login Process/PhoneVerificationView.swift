//
//  PhoneVerificationView.swift
//  Synx
//
//  Created by Zifan Deng on 11/3/24.
//

import SwiftUI
import Firebase
import FirebaseAuth




struct PhoneVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("SeenTutorial") private var SeenTutorial: Bool = false
    @Binding var isLogin: Bool
    @Binding var hasSeenTutorial: Bool
    let isPreEmailVerification: Bool
    
    let oldPhone: String?
    let email: String?
    @State private var countryCode: String = "1"
    @State private var newPhone: String = ""
    
    @State private var verificationID: String = ""
    @State private var verificationCode: String = ""
    @State private var showVerificationField: Bool = false
    
    @State private var showingPrompt: Bool = false
    @State private var promptMessage: String = ""
    @State private var promptCompletionBlock: ((Bool, String) -> Void)?
    
    @State private var showProfileSetup: Bool = false
    @State private var previousUser: User? = nil
    @State private var errorMessage: String = ""
    
    private var countryCodes: [(numericCode: String, isoCode: String, name: String)] {
        Formatter.getAllCountryCodes()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if !showVerificationField {
                        if isPreEmailVerification {
                            oldPhoneView
                        } else {
                            newPhoneInputView
                        }
                        
                        // Friendly reminder
                        Text("You will receive an SMS verification code.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        sendCodeButton
                    } else {
                        // Verification code input
                        TextField("Enter verification code", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .multilineTextAlignment(.center)
                        
                        verifyCodeButton
                        
                        Button("Change Phone Number") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle(isPreEmailVerification ? "One-step Sign In" : "Phone Verification")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $showProfileSetup) {
            if let user = FirebaseManager.shared.auth.currentUser {
                ProfileSetupView(
                    isLogin: $isLogin,
                    uid: user.uid,
                    phone: isPreEmailVerification ? oldPhone ?? "" : newPhone,
                    email: isPreEmailVerification ? "" : email ?? ""
                )
            }
        }
    }
    
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isPreEmailVerification
                 ? "Send code to your phone number"
                 : "Let's register your phone number to find friends!")
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var oldPhoneView: some View {
        HStack(spacing: 8) {
            // Display the `oldPhone` as text
            Text(oldPhone?.isEmpty == false ? oldPhone! : "No phone number provided")
                .font(.title2)
                .padding(12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
    }
    
    private var newPhoneInputView: some View {
        // Input field for entering a new phone number
        HStack(spacing: 4) {
            // Country Code Dropdown
            Menu {
                ForEach(countryCodes, id: \.numericCode) { code in
                    Button(action: { countryCode = code.numericCode }) {
                        Text("+\(code.numericCode) (\(code.name))") // Show country code and name in the menu
                    }
                }
            } label: {
                HStack {
                    Text("+\(countryCode)") // Only show the number in the button
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down") // Add a dropdown arrow icon
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: 100)
            .padding(.leading, -6)
            
            
            // Phone Number Input Field
            TextField("Phone Number", text: $newPhone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    
    private var sendCodeButton: some View {
        // Button for sending code
        Button {
            requestVerificationCode()
        } label: {
            Text("Send Code")
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
        }
        .disabled(newPhone.isEmpty && !isPreEmailVerification)
        .opacity((newPhone.isEmpty && !isPreEmailVerification) ? 0.6 : 1)
    }
    
    private var verifyCodeButton: some View {
        Button {
            verifyCode()
        } label: {
            Text("Verify")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
    
    
    
    
    
    
    
    
    // MARK: Functions Start Here
    private func showTextInputPrompt(withMessage message: String, completionBlock: @escaping (Bool, String) -> Void) {
        self.promptMessage = message
        self.promptCompletionBlock = completionBlock
        self.showingPrompt = true
    }
    
    private func requestVerificationCode() {
        errorMessage = ""
        let formattedPhone = isPreEmailVerification
        ? oldPhone
        : Formatter.formatPhoneNumber(newPhone, numericCode: countryCode)
        
        guard let formattedPhone = formattedPhone else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        self.newPhone = formattedPhone
        
        // Only check if phone number exists when not in pre-email verification
        if !isPreEmailVerification {
            checkIfPhoneNumberExists(phoneNumber: newPhone) { exists in
                if exists {
                    self.errorMessage = "This phone number is already in use."
                    print("[Error]: \(self.errorMessage)")
                } else {
                    self.sendVerificationCode(to: newPhone)
                }
            }
        } else {
            self.sendVerificationCode(to: newPhone)
        }
    }
    
    
    
    private func sendVerificationCode(to phoneNumber: String) {
        // Phone verification flow
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            if let verificationID = verificationID {
                self.verificationID = verificationID
                UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                self.showVerificationField = true
            } else {
                self.errorMessage = "Failed to receive verification code. Please try again."
            }
        }
    }
    
    
    
    private func verifyCode() {
        errorMessage = ""
        
        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
            errorMessage = "Verification ID not found"
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        // Google or Apple already logged in, connect to Phone
        if !isPreEmailVerification, let currentUser = FirebaseManager.shared.auth.currentUser {
            Linker.linkAccounts(currentUser: currentUser, credential: credential) { success, error in
                if success {
                    dismiss()
                } else {
                    errorMessage = error ?? "Unknown error occurred."
                }
            }
        } else {
            // Regular phone sign-in flow
            regularPhoneSignIn(credential: credential)
        }
    }
    
    
    
    // Check if Phone is in the database
    private func checkIfPhoneNumberExists(phoneNumber: String?, completion: @escaping (Bool) -> Void) {
        guard let phoneNumber = phoneNumber else {
            completion(false)
            return
        }
        
        let usersRef = FirebaseManager.shared.firestore.collection("users")
        usersRef.whereField("phoneNumber", isEqualTo: phoneNumber).getDocuments { snapshot, error in
            if let error = error {
                print("[Error]: Failed to query Firestore for phone number: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("[Log]: Phone number not found in Firestore.")
                completion(false) // No matching phone number found
                return
            }
            
            print("[Log]: Phone number already exists in Firestore.")
            completion(true) // Phone number already exists
        }
    }

    
    
    // Regular Phone verify
    private func regularPhoneSignIn(credential: AuthCredential) {
        FirebaseManager.shared.auth.signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    // Handle MFA if required
                    if error.code == AuthErrorCode.secondFactorRequired.rawValue {
                        self.handleMultiFactorAuthentication(error: error)
                    } else {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    return
                }
                
                // Handle successful sign in
                self.handleSuccessfulSignIn(authResult?.user)
            }
        }
    }
    
    
    
    // MFA given by Firebase
    private func handleMultiFactorAuthentication(error: NSError) {
        if let resolver = error.userInfo[AuthErrorUserInfoMultiFactorResolverKey] as? MultiFactorResolver {
            // Build display string of factors
            var displayNameString = ""
            for tmpFactorInfo in resolver.hints {
                displayNameString += tmpFactorInfo.displayName ?? ""
                displayNameString += " "
            }
            
            // Show MFA prompt
            self.showTextInputPrompt(
                withMessage: "Select factor to sign in\n\(displayNameString)",
                completionBlock: { userPressedOK, displayName in
                    var selectedHint: PhoneMultiFactorInfo?
                    for tmpFactorInfo in resolver.hints {
                        if displayName == tmpFactorInfo.displayName {
                            selectedHint = tmpFactorInfo as? PhoneMultiFactorInfo
                        }
                    }
                    
                    // Verify the phone number for MFA
                    PhoneAuthProvider.provider().verifyPhoneNumber(with: selectedHint!, uiDelegate: nil, multiFactorSession: resolver.session) { verificationID, error in
                        if error != nil {
                            self.errorMessage = "Multi factor start sign in failed."
                        } else {
                            // Get verification code for MFA
                            self.showTextInputPrompt(
                                withMessage: "Verification code for \(selectedHint?.displayName ?? "")",
                                completionBlock: { userPressedOK, verificationCode in
                                    let credential = PhoneAuthProvider.provider()
                                        .credential(withVerificationID: verificationID!,
                                                    verificationCode: verificationCode)
                                    let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
                                    
                                    // Complete MFA sign in
                                    resolver.resolveSignIn(with: assertion) { authResult, error in
                                        if let error = error {
                                            self.errorMessage = error.localizedDescription
                                        } else {
                                            // Successfully signed in with MFA
                                            self.handleSuccessfulSignIn(authResult?.user)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            )
        }
    }
    
    
    
    // Link two accounts (current user link to the new login credential)
    private func linkAccounts(currentUser: User, credential: AuthCredential) {
        currentUser.link(with: credential) { authResult, error in
            if let error = error as NSError? {
                switch error.code {
                case AuthErrorCode.credentialAlreadyInUse.rawValue:
                    print("[Log]: Unexpected credentialAlreadyInUse error. This shouldn't happen as phone number existence is pre-checked.")
                    self.errorMessage = "Unexpected error. Please retry or contact support."
                    
                case AuthErrorCode.secondFactorRequired.rawValue:
                    print("[Log]: Multi-factor authentication required.")
                    self.handleMultiFactorAuthentication(error: error)
                    
                default:
                    self.errorMessage = "Linking failed: \(error.localizedDescription)"
                    print("[Error]: \(self.errorMessage)")
                }
                return
            }
            
            // Successfully linked accounts
            print("[Log]: Successfully linked credential to user \(currentUser.uid)")
            self.handleSuccessfulSignIn(authResult?.user)
        }
    }
    
    
    
    // Handle successful sign in
    private func handleSuccessfulSignIn(_ user: User?) {
        guard let user = user else {
            self.errorMessage = "Failed to get user information"
            return
        }
        
        // Check for existing user
        FirebaseManager.shared.firestore
            .collection("users")
            .document(user.uid)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Firestore error: \(error)")
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                // User exists
                if snapshot?.exists == true {
                    checkTutorialStatus()
                    isLogin = true
                    self.isLoggedIn = true
                    self.dismiss()
                } else {
                    // User doesn't exist, choose profile
                    self.showProfileSetup = true
                }
            }
    }
    
    private func checkTutorialStatus() {
            guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }

            FirebaseManager.shared.firestore
                .collection("users")
                .document(uid)
                .getDocument { snapshot, error in
                    if let error = error {
                        print("Failed to fetch tutorial status: \(error)")
                        hasSeenTutorial = false
                        SeenTutorial = false
                    } else if let data = snapshot?.data(), let seen = data["seen_tutorial"] as? Bool {
                        hasSeenTutorial = seen
                        SeenTutorial = seen
                    } else {
                        hasSeenTutorial = false
                        SeenTutorial = false
                    }
                }
        }
    
    
    
    
}

