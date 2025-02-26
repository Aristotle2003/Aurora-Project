import SwiftUI
import SDWebImageSwiftUI

struct CreateGroupView: View {
    // Using the same view model to fetch contacts (friends)
    @StateObject private var viewModel = CreateNewMessageViewModel()
    // A Set to hold the IDs of selected contacts
    @State private var selectedUserIDs = Set<String>()
    // Environment dismiss action to go back
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Spacer().frame(height: 49)
                        
                        Text("Create New Group")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        Text("Select contacts to invite to your group chat.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    }
                    .padding(.horizontal)
                    
                    // Contacts List Section
                    VStack {
                        ForEach(viewModel.users) { user in
                            Button(action: {
                                toggleSelection(for: user)
                            }) {
                                HStack {
                                    // User profile image
                                    WebImage(url: URL(string: user.profileImageUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 45, height: 45)
                                        .clipShape(Circle())
                                    
                                    // User name
                                    Text(user.username)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    // Checkmark for selected contacts
                                    if selectedUserIDs.contains(user.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .padding(.vertical)
            }
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
            .navigationTitle("Select Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back button on the top left
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        .font(.system(size: 17, weight: .bold))
                    }
                }
                // Next button on the top right, disabled if no contacts are selected
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: Sub_CreateGroupView(selectedUserIDs: selectedUserIDs)) {
                        Text("Next")
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedUserIDs.isEmpty ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(selectedUserIDs.isEmpty)
                }
            }
        }
        .onAppear {
            viewModel.fetchAllFriends()
        }
    }
    
    // Toggle selection for a given user
    private func toggleSelection(for user: ChatUser) {
        if selectedUserIDs.contains(user.id) {
            selectedUserIDs.remove(user.id)
        } else {
            selectedUserIDs.insert(user.id)
        }
    }
}
