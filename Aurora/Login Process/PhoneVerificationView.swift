import SwiftUI
import Firebase
import FirebaseAuth


struct PhoneVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("SeenTutorial") private var SeenTutorial: Bool = false
    @Binding var isLogin: Bool
    @Binding var hasSeenTutorial: Bool
    @State private var isLoading: Bool = false
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
    @FocusState private var focusItem: Bool
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
    
    private var countryCodes: [(numericCode: String, isoCode: String, name: String)] {
        Formatter.getAllCountryCodes()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer()
                            .frame(height: 139)
                        
                        Text("")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        if isPreEmailVerification {
                            Text("Verify Your Phone Number")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                        } else {
                            Text("One-step Sign In")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                        }
                        
                        
                        Text("You will receive an SMS verification code. Let’s register your phone number to find friends!")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            .padding(.bottom, 4)
                        
                        Spacer()
                            .frame(height: 80)
                        
                    }
                    .padding(.bottom, 10)
                    
                    if !showVerificationField {
                        if isPreEmailVerification {
                            oldPhoneView
                        } else {
                            newPhoneInputView
                        }
                        
                        sendCodeButton
                    } else {
                        // Verification code input
                        TextField("Enter verification code", text: $verificationCode)
                            .keyboardType(.numberPad)
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
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)    // Horizontal padding for spacing inside the bubble
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(100)

                        
                        verifyCodeButton
                        
                        Button("Change Phone Number") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                        
                    }
                    
                    if isLoading{
                        ProgressView()
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationBarItems(
                leading: Button(action: {
                    dismiss()
                }) {
                    Image("chatlogviewbackbutton") // Replace "YourImageName" with the name of your image asset
                        .renderingMode(.original) // Optional: Keeps the original colors of the image
                }
            )
        }
        .background(Color(red: 0.976, green: 0.980, blue: 1.0))
            .ignoresSafeArea()
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
            Text(oldPhone?.isEmpty == false ? oldPhone! : "No phone number provided")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.white)
                .cornerRadius(100)
        }
    }

    
    private var newPhoneInputView: some View {
        // Input field for entering a new phone number
        HStack(spacing: 8) {
            // Country Code Dropdown
            Menu {
                ForEach(countryCodes, id: \.numericCode) { code in
                    Button(action: {
                        countryCode = code.numericCode
                        generateHapticFeedbackMedium()
                    }) {
                        Text("+\(code.numericCode) (\(code.name))")
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("+\(countryCode)")
                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .frame(width: 98, height: 48)
                .background(Color.white)
                .cornerRadius(100)
            }

            // Phone Number Input Field
            TextField("Phone Number", text: $newPhone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
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
                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.white)
                .cornerRadius(100)
        }
    }
    
    
    
    
    private var sendCodeButton: some View {
        // Button for sending code
        Button {
            requestVerificationCode()
            generateHapticFeedbackMedium()
            focusItem = false
        } label: {
            Image(newPhone.isEmpty && !isPreEmailVerification ? "sendbuttonunpressed" : "sendbutton")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width - 80)
        }
        .disabled(newPhone.isEmpty && !isPreEmailVerification)
        .opacity((newPhone.isEmpty && !isPreEmailVerification) ? 0.6 : 1)
    }
    
    private var verifyCodeButton: some View {
        Button {
            verifyCode()
            generateHapticFeedbackMedium()
            focusItem = false
        } label: {
            Image(verificationCode.isEmpty ? "verifybuttonunpressed" : "verifybutton")
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width - 80)
        }
        .disabled(verificationCode.isEmpty)
        .opacity(verificationCode.isEmpty ? 0.6 : 1)
    }
    
    
    
    
    
    
    
    
    // MARK: Functions Start Here
    private func showTextInputPrompt(withMessage message: String, completionBlock: @escaping (Bool, String) -> Void) {
        self.promptMessage = message
        self.promptCompletionBlock = completionBlock
        self.showingPrompt = true
    }
    
    private func requestVerificationCode() {
        errorMessage = ""
        isLoading = true
        
        let formattedPhone = isPreEmailVerification
        ? oldPhone
        : Formatter.formatPhoneNumber(newPhone, numericCode: countryCode)
        
        guard let formattedPhone = formattedPhone else {
            errorMessage = "Please enter a valid phone number"
            self.isLoading = false
            return
        }
        self.newPhone = formattedPhone
        
        // Only check if phone number exists when not in pre-email verification
        if !isPreEmailVerification {
            checkIfPhoneNumberExists(phoneNumber: newPhone) { exists in
                if exists {
                    self.errorMessage = "This phone number is already in use. Log in or choose another one"
                    self.isLoading = false
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
            self.isLoading = false
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
        isLoading = true
        
        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
            errorMessage = "Verification ID not found"
            self.isLoading = false
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        // Google or Apple already logged in, connect to Phone
        if !isPreEmailVerification, let currentUser = FirebaseManager.shared.auth.currentUser {
            previousUser = currentUser
            print("[Log]: Attempting to link credential to user \(currentUser.uid)")
            
            // Link current google or apple to the phone login
            self.linkAccounts(currentUser: currentUser, credential: credential)
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
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                // Handle successful sign in
                self.handleSuccessfulSignIn(authResult?.user)
            }
        }
    }
    
    
    /*
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
    */
    
    
    // Link two accounts (current user link to the new login credential)
    private func linkAccounts(currentUser: User, credential: AuthCredential) {
        currentUser.link(with: credential) { authResult, error in
            if let error = error as NSError? {
                switch error.code {
                case AuthErrorCode.credentialAlreadyInUse.rawValue:
                    print("[Log]: Unexpected credentialAlreadyInUse error. This shouldn't happen as phone number existence is pre-checked.")
                    self.errorMessage = "This phone number is already linked to an account. Please log in or use a different phone number."
                default:
                    self.errorMessage = "Something went wrong. Please check your internet connection and try again."
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
            self.errorMessage = "Failed to log in"
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
                    isLogin = true
                    self.isLoggedIn = true
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
