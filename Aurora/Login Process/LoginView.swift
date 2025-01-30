import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit


struct LoginView: View {
    @Environment(\.window) var window
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("SeenTutorial") private var SeenTutorial: Bool = false
    @State var isLogin = false
    
    @State private var isPostEmailVerification = false
    @State private var isPreEmailVerification = false
    
    @State private var uid = ""
    @State private var email = ""
    
    @State private var countryCode: String = "1"
    @State private var phoneNumber = ""
    // Apple nonce
    @State private var nonce: String?
    
    @State private var loginStatusMessage = ""
    @State var hasSeenTutorial = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    
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
        if Auth.auth().currentUser != nil && isLoggedIn && SeenTutorial{
            CustomTabNavigationView()
        }
        else if isLoggedIn && !SeenTutorial{
            TutorialView()
        }
        else{
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Spacer()
                                .frame(height: 139)
                            
                            Text("Welcome to AURORA!")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                            
                            Text("One-step Sign In")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            
                            Text("Enter your number to instantly login or create a new account.")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                .padding(.bottom, 4)
                            
                            Spacer()
                                .frame(height: 90)
                            
                            
                            phoneInputView
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                        
                        
                        
                        // Button for phone login
                        Button {
                            verifyPhoneNumber()
                            generateHapticFeedbackMedium()
                        } label: {
                            HStack {
                                Spacer()
                                Image("continuebutton")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width - 80)
                                Spacer()
                            }
                        }
                        .disabled(phoneNumber.isEmpty)
                        .opacity(phoneNumber.isEmpty ? 0.6 : 1)
                        
                        
                        
                        // Divider
                        HStack {
                            VStack { Divider() }.padding(.horizontal, 8)
                            Text("OR").foregroundColor(.gray)
                            VStack { Divider() }.padding(.horizontal, 8)
                        }
                        
                        
                        
                        // Button for google login
                        Button {
                            handleGoogleSignIn()
                            generateHapticFeedbackMedium()
                        } label: {
                            HStack {
                                Image("googlebutton")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width - 80)
                            }
                        }
                        
                        
                        
                        // Button for apple login
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
                                loginStatusMessage = "Error signing in with Apple: \(error.localizedDescription)"
                            }
                        }
                        .signInWithAppleButtonStyle(.black) // Choose black, white, or whiteOutline
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .cornerRadius(23)       // Adjust the corner radius here
                        .padding(.horizontal, 20) // Adjust horizontal padding
                        
                        Spacer()
                            .frame(height: 40)
                        
                        Text("By continuing, you accept Aurora’s")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))

                        HStack(spacing: 4) {
                            Button {
                                showTermsOfService = true
                                generateHapticFeedbackMedium()
                            } label: {
                                Text("Terms of Service")
                                    .underline()
                                    .foregroundColor(.blue)
                            }

                            Text("and")
                                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))

                            Button {
                                showPrivacyPolicy = true
                                generateHapticFeedbackMedium()
                            } label: {
                                Text("Privacy Policy")
                                    .underline()
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 40)

                        
                        
                        
                        // Status Message
                        Text(self.loginStatusMessage)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 20)
                    
                }
                .background(Color(red: 0.976, green: 0.980, blue: 1.0))
                    .ignoresSafeArea()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            // Phone verification with no email
            .fullScreenCover(isPresented: $isPreEmailVerification) {
                PhoneVerificationView(
                    isLogin: $isLogin,
                    hasSeenTutorial: $hasSeenTutorial,
                    isPreEmailVerification: true,
                    oldPhone: phoneNumber,
                    email: ""
                )
            }
            // Phone verification after google or apple
            .fullScreenCover(isPresented: $isPostEmailVerification) {
                if let user = FirebaseManager.shared.auth.currentUser {
                    PhoneVerificationView(
                        isLogin: $isLogin,
                        hasSeenTutorial: $hasSeenTutorial,
                        isPreEmailVerification: false,
                        oldPhone: "",
                        email: user.email
                    )
                }
            }
            .fullScreenCover(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
            .fullScreenCover(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }

        }
    }
    
    
    private var phoneInputView: some View {
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
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.white)
                .cornerRadius(100)
        }
    }


    
    
    
    
    
    
    // MARK: Functions Start Here
    // Verify using phone number
    private func verifyPhoneNumber() {
        // Format and validate the phone number using the Formatter class
        guard let formattedPhone = Formatter.formatPhoneNumber(phoneNumber, numericCode: countryCode) else {
            loginStatusMessage = "Please enter a valid phone number"
            return
        }
        
        self.phoneNumber = formattedPhone // Update the formatted phone number
        
        if Formatter.isValidPhoneNumber(phoneNumber, numericCode: countryCode) {
            isPreEmailVerification = true
        } else {
            loginStatusMessage = "Please enter a valid phone number"
        }
    }
    
    
    
    
    
    
    
    // Sign in using Google sign in
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseManager.shared.auth.app?.options.clientID else {
            self.loginStatusMessage = "Error getting client ID"
            return
        }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            self.loginStatusMessage = "Error getting root view controller"
            return
        }

        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                self.loginStatusMessage = "Error signing in with Google: \(error.localizedDescription)"
                return
            }
            
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString
            else {
                self.loginStatusMessage = "Error getting user data"
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            
            
            // Sign in google user!!
            FirebaseManager.shared.auth.signIn(with: credential) { result, error in
                if let error = error {
                    self.loginStatusMessage = "Firebase sign in error: \(error.localizedDescription)"
                    return
                }
                
                // Check if user exists
                guard let user = result?.user else { return }
                FirebaseManager.shared.firestore.collection("users")
                    .document(user.uid).getDocument { snapshot, error in
                        if let error = error {
                            self.loginStatusMessage = "\(error)"
                            return
                        }
                        
                        // User exists
                        if (snapshot?.data()) != nil {
                            checkTutorialStatus()
                            self.isLogin = true
                            self.isLoggedIn = true
                        // New user set up profile
                        } else {
                            self.isPostEmailVerification = true
                        }
                    }
            }
        }
    }
    
    
    // Sign in using Apple account
    func handleAppleSignIn(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Showing loading screen later
            
            guard let nonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            // Initialize a Firebase credential, including the user's full name.
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nonce,
                                                           fullName: appleIDCredential.fullName)
            // Sign in with Firebase.
            FirebaseManager.shared.auth.signIn(with: credential) { (authResult, error) in
                if let error {
                    // Error. If error.code == .MissingOrInvalidNonce, make sure
                    // you're sending the SHA256-hashed nonce as a hex string with
                    // your request to Apple.
                    self.loginStatusMessage = "Apple sign in error: \(error.localizedDescription)"
                    return
                }
                
                // User is signed in to Firebase with Apple.
                guard let user = authResult?.user else { return }
                FirebaseManager.shared.firestore.collection("users")
                    .document(user.uid).getDocument { snapshot, error in
                        if let error = error {
                            self.loginStatusMessage = "\(error)"
                            return
                        }
                        
                        // User exists
                        if (snapshot?.data()) != nil {
                            checkTutorialStatus()
                            self.isLogin = true
                            self.isLoggedIn = true
                        // New user set up profile
                        } else {
                            self.isPostEmailVerification = true
                        }
                    }
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
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    
    
    
    
}



extension EnvironmentValues {
    var window: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        return scene.windows.first
    }
}



#Preview {
    LoginView()
}
