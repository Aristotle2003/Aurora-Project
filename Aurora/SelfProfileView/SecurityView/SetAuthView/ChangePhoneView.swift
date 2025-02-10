//
//  ChangePhoneView.swift
//  Synx
//
//  Created by Zifan Deng on 12/1/24.
//

import SwiftUI
import Firebase
import FirebaseAuth




struct ChangePhoneView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var countryCode: String = "1"
    @State private var phoneNumber: String = ""
    
    @State private var verificationID: String? = nil
    @State private var verificationCode: String = ""
    @State private var showVerificationField: Bool = false
    
    @State private var newPhoneCredential: PhoneAuthCredential?
    @State private var isLoading: Bool = false
    @FocusState private var focusItem: Bool

    @State private var errorMessage: String = ""
    let onComplete: (String) -> Void
    
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
            ZStack{
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
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
                        Text("Change Phone Number")
                            .font(.system(size: 20, weight: .bold)) // Customize font style
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255)) // Customize text color
                        Spacer()
                        Image("spacerformainmessageviewtopleft") // Replace with your back button image
                            .resizable()
                            .frame(width: 24, height: 24) // To balance the back button
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    VStack {
                        headerView
                        
                        if !showVerificationField {
                            PhoneInputView
                            
                            // Friendly reminder
                            Text("You will receive an SMS verification code.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(.gray))
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 16)
                                .padding(.bottom, 4)
                                .padding(.top, 4)
                            
                            sendCodeButton
                        } else {
                            // Verification code input
                            TextField("Enter verification code", text: $verificationCode)
                                .keyboardType(.numberPad)
                                .focused($focusItem)
                                .toolbar {
                                    if focusItem {  // Only show when keyboard is visible
                                        ToolbarItemGroup(placement: .keyboard) {
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.gray))
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 16)
                            .padding(.bottom, 4)
                            .padding(.top, 4)
                        }
                        
                        if isLoading {
                            ProgressView()
                        }
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } // VStack ends here
                    .navigationBarBackButtonHidden(true)
                    .padding()
                } // VStack ends here
                .navigationBarBackButtonHidden(true)
            } // ZStack ends here
            .navigationBarBackButtonHidden(true)
        } // Navigation ends here
        .navigationBarBackButtonHidden(true)
    }
    
    
    private var headerView: some View {
        HStack {
            Text("Send code to your phone number")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(.gray))
                .multilineTextAlignment(.leading)
                .padding(.leading, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            Spacer()
        }
    }
    
    
    private var PhoneInputView: some View {
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
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .focused($focusItem)
                .toolbar {
                    if focusItem {  // Only show when keyboard is visible
                        ToolbarItemGroup(placement: .keyboard) {
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
                .textContentType(.telephoneNumber)
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
        } label: {
            HStack {
                Spacer()
                Image(phoneNumber.isEmpty ? "continuebuttonunpressed" : "continuebutton")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width - 80)
                Spacer()
            }
        }
        .disabled(phoneNumber.isEmpty)
        .opacity(phoneNumber.isEmpty ? 0.6 : 1)
    }
    
    private var verifyCodeButton: some View {
        Button {
            verifyCode()
            generateHapticFeedbackMedium()
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
    private func requestVerificationCode() {
        errorMessage = ""
        isLoading = true
        
        let formattedPhone = Formatter.formatPhoneNumber(phoneNumber, numericCode: countryCode)
        guard let formattedPhone = formattedPhone else {
            errorMessage = "Please enter a valid phone number"
            isLoading = false
            return
        }
        self.phoneNumber = formattedPhone
        
        // Check if the phone number already exists in the database
        checkIfPhoneNumberExists(phoneNumber: phoneNumber) { exists in
            if exists {
                self.errorMessage = "This phone number is already in use. Log in or choose another one"
                self.isLoading = false
            } else {
                // Send the verification code
                PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.verificationID = verificationID
                    self.showVerificationField = true
                }
            }
        }
    }


    private func verifyCode() {
        errorMessage = ""
        isLoading = true
        
        // Crucial Line
        guard let verificationID = verificationID else {
            errorMessage = "Verification ID not found"
            isLoading = false
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            errorMessage = "No current user found"
            isLoading = false
            return
        }
        
        
        // Unlink all previous phone numbers first
        unlinkAllPhoneProviders(currentUser: currentUser) { success in
            if success {
                // Link and update phone number after unlinking
                self.linkCredentialAndUpdatePhone(currentUser: currentUser, credential: credential)
            } else {
                self.errorMessage = "Failed to unlink previous phone numbers."
                self.isLoading = false
            }
        }
    }
    
    
    private func unlinkAllPhoneProviders(currentUser: User, completion: @escaping (Bool) -> Void) {
        // Identify phone-based providers
        let phoneProviders = currentUser.providerData.filter { $0.providerID == PhoneAuthProviderID }
        let group = DispatchGroup()
        var unlinkingError: Error?
        
        for provider in phoneProviders {
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
        
        group.notify(queue: .main) {
            if let error = unlinkingError {
                self.errorMessage = "Error unlinking providers: \(error.localizedDescription)"
                completion(false)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    print("All phone providers unlinked successfully.")
                    completion(true)
                }
            }
        }
    }
    
    
    // Link credentials, update Firebase, update Firestore
    private func linkCredentialAndUpdatePhone(currentUser: User, credential: PhoneAuthCredential) {
        let newPhoneNumber = phoneNumber
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Link the provided phone credential
            currentUser.link(with: credential) { authResult, error in
                if let error = error {
                    self.errorMessage = "Error linking phone number: \(error.localizedDescription)"
                    print("Error linking phone number: \(error.localizedDescription)")
                    return
                }
                print("Phone number immediately after link: \(authResult?.user.phoneNumber ?? "nil")")
                
                
                // Reload user to verify the update
                currentUser.reload { error in
                    if let error = error {
                        self.errorMessage = "Error reloading user: \(error.localizedDescription)"
                        print("Error reloading user: \(error.localizedDescription)")
                        return
                    }
                    
                    // Verify the phone number was updated
                    if let freshUser = FirebaseManager.shared.auth.currentUser,
                       let updatedPhoneNumber = freshUser.phoneNumber {
                        print("Verified phone number in Firebase Auth: \(updatedPhoneNumber)")
                        
                        // Update Firestore
                        let db = Firestore.firestore()
                        let userId = currentUser.uid
                        
                        db.collection("users").document(userId).updateData([
                            "phoneNumber": newPhoneNumber
                        ]) { error in
                            if let error = error {
                                self.errorMessage = "Error updating phone number in Firestore: \(error.localizedDescription)"
                                print("Error updating phone number in Firestore: \(error.localizedDescription)")
                            } else {
                                print("Successfully updated phone number in Firestore to \(newPhoneNumber)")
                                onComplete("Phone number successfully changed!")
                                dismiss()
                            }
                        }
                    } else {
                        self.errorMessage = "Phone number not updated in Firebase Auth"
                        print("No phone number available after update.")
                    }
                }
            }
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
}
