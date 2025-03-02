import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct Sub_CreateGroupView: View {
    // The selected contacts from the previous step.
    let selectedUserIDs: Set<String>
    
    @State private var groupName: String = ""
    @State private var image: UIImage?
    @State private var showImagePicker = false
    @State private var isCreatingGroup = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss

    private let db = FirebaseManager.shared.firestore
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header texts
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Details")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        Text("Add a group name and select a group photo to continue.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Group photo selection button
                    VStack {
                        Button {
                            showImagePicker.toggle()
                            // Optionally generate haptic feedback here.
                        } label: {
                            VStack {
                                if let image = image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 128, height: 128)
                                        .clipShape(Circle())
                                } else {
                                    Image("imagepickerpicture")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 132, height: 132)
                                        .padding()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Group name text field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter group name", text: $groupName)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(Color.white)
                            .cornerRadius(100)
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    }
                    .padding(.horizontal)
                    
                    // Error message if any
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Create button
                    Button {
                        createGroupChat()
                    } label: {
                        HStack {
                            Spacer()
                            Image((image == nil || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                  ? "continuebuttonunpressed" : "continuebutton")
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width - 80)
                            Spacer()
                        }
                    }
                    .disabled(isCreatingGroup ||
                              groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              image == nil)
                    .opacity((isCreatingGroup || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image == nil) ? 0.6 : 1)
                    .padding(.horizontal)
                    
                    if isCreatingGroup {
                        ProgressView()
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true) // Hides the default back button.
            .navigationBarItems(leading:
                Button {
                    dismiss()
            } label: {
                Text("Cancel")
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                    .font(.system(size: 17))
            })
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $image)
            }
        }
    }
    
    private func createGroupChat() {
        guard let currentUserUID = Auth.auth().currentUser?.uid else {
            errorMessage = "No current user logged in."
            return
        }
        
        isCreatingGroup = true
        
        // Generate a unique group ID.
        let groupID = UUID().uuidString
        
        // Include the current user in the list of members.
        let members = Array(selectedUserIDs.union([currentUserUID]))
        
        // Upload the group image to storage first.
        guard let image = self.image, let imageData = image.jpegData(compressionQuality: 0.5) else {
            errorMessage = "Please select a valid group photo."
            isCreatingGroup = false
            return
        }
        
        // Create a storage reference for the group image.
        let storageRef = FirebaseManager.shared.storage.reference(withPath: "group_photos/\(groupID).jpg")
        storageRef.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                errorMessage = "Failed to upload group photo: \(err.localizedDescription)"
                isCreatingGroup = false
                return
            }
            
            storageRef.downloadURL { url, err in
                if let err = err {
                    errorMessage = "Failed to retrieve group photo URL: \(err.localizedDescription)"
                    isCreatingGroup = false
                    return
                }
                
                guard let groupPhotoURL = url?.absoluteString else {
                    errorMessage = "Invalid group photo URL."
                    isCreatingGroup = false
                    return
                }
                
                // Prepare the group data for the global "groups" collection.
                let groupData: [String: Any] = [
                    "groupID": groupID,
                    "groupName": groupName,
                    "members": members,
                    "groupPhoto": groupPhotoURL,
                    "createdBy": currentUserUID,
                    "createdAt": Timestamp(date: Date()),
                    "latestMessageTimestamp": Timestamp(date: Date()),
                ]
                
                // Minimal group info to store in each user's group_list subcollection.
                let userGroupData: [String: Any] = [
                    "groupID": groupID,
                    "groupName": groupName,
                    "groupPhoto": groupPhotoURL,
                    "createdAt": Timestamp(date: Date()),
                    "isPinned": false,
                    "hasUnseenLatestMessage": false
                ]
                
                let batch = db.batch()
                
                // Set group document in "groups" collection.
                let groupDocRef = db.collection("groups").document(groupID)
                batch.setData(groupData, forDocument: groupDocRef)
                
                // For each member, add the group info in their group_list subcollection.
                for member in members {
                    let userGroupRef = db.collection("users").document(member).collection("group_list").document(groupID)
                    batch.setData(userGroupData, forDocument: userGroupRef)
                }
                
                batch.commit { error in
                    isCreatingGroup = false
                    if let error = error {
                        errorMessage = "Failed to create group: \(error.localizedDescription)"
                    } else {
                        print("Group created successfully with ID: \(groupID)")
                        dismiss()
                    }
                }
            }
        }
    }
}
