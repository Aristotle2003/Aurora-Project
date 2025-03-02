//
//  MainMessagesViewModel.swift
//  Aurora
//
//  Created by Zhu Allen on 2/26/25.
//
import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

// MARK: - GroupChat Model
struct GroupChat: Identifiable {
    var id: String {uid}
    let uid: String
    let groupName: String
    let members: [String]
    var groupPhoto: String
    let createdBy: String
    let createdAt: Timestamp?
    var isPinned: Bool
    var hasUnseenLatestMessage: Bool
    var latestMessageTimestamp: Timestamp?
    
    init?(data: [String: Any]) {

        self.uid = data["groupID"] as? String ?? ""
        self.groupName = data["groupName"] as? String ?? ""
        self.members = data["members"] as? [String] ?? []
        self.groupPhoto = data["groupPhoto"] as? String ?? ""
        self.createdBy = data["createdBy"] as? String ?? ""
        self.createdAt = data["createdAt"] as? Timestamp
        self.latestMessageTimestamp = data["latestMessageTimestamp"] as? Timestamp
        self.isPinned = data["isPinned"] as? Bool ?? false
        self.hasUnseenLatestMessage = data["hasUnseenLatestMessage"] as? Bool ?? false
    }
}

class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    @Published var users = [ChatUser]()
    @Published var groups = [GroupChat]()  // New array for groups
    @Published var isLoading = false

    var messageListener: ListenerRegistration?
    var groupListener: ListenerRegistration?  // Listener for groups
    var friendRequestListener: ListenerRegistration?
    
    @Published var hasNewFriendRequest = false
    @AppStorage("lastCheckedTimestamp") var lastCheckedTimestamp: Double = 0
    @AppStorage("lastLikesCount") var lastLikesCount: Int = 0
    
    init() {
        DispatchQueue.main.async {
            self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        setupFriendListListener()
        setupGroupListener() // Set up group listener
        setupFriendRequestListener()
    }
    
    func setupFriendListListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        isLoading = true

        messageListener?.remove()
        messageListener = nil

        messageListener = FirebaseManager.shared.firestore
            .collection("friends")
            .document(uid)
            .collection("friend_list")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for friend list changes: \(error)"
                    print("Failed to listen for friend list changes: \(error)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    self.errorMessage = "No friend list documents found"
                    return
                }

                DispatchQueue.global(qos: .background).async {
                    var users: [ChatUser] = []
                    for document in documents {
                        let data = document.data()
                        let user = ChatUser(data: data)
                        if user.uid != uid {
                            users.append(user)
                        }
                    }
                    // Sort pinned and unpinned friends.
                    let pinnedUsers = users.filter { $0.isPinned }.sorted {
                        ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }
                    let unpinnedUsers = users.filter { !$0.isPinned }.sorted {
                        ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }
                    DispatchQueue.main.async {
                        self.users = pinnedUsers + unpinnedUsers
                        self.isLoading = false
                    }
                }
            }
    }
    
    // New group listener: fetch groups where current user is a member.
    func setupGroupListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        groupListener?.remove()
        groupListener = nil
        
        // Listen to the current user's group_list subcollection.
        groupListener = FirebaseManager.shared.firestore
            .collection("users")
            .document(uid)
            .collection("group_list")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for group_list changes: \(error)"
                    print("Failed to listen for group_list changes: \(error)")
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    self.errorMessage = "No group_list documents found"
                    return
                }
                
                var fetchedGroups: [GroupChat] = []
                let dispatchGroup = DispatchGroup()
                
                // For each document in group_list, fetch the group info from the "groups" collection.
                for document in documents {
                    let userGroupData = document.data() // Contains isPinned, hasUnseenLatestMessage, etc.
                    let groupId = document.documentID
                    
                    dispatchGroup.enter()
                    FirebaseManager.shared.firestore
                        .collection("groups")
                        .document(groupId)
                        .getDocument { snapshot, error in
                            defer { dispatchGroup.leave() }
                            
                            if let error = error {
                                print("Failed to fetch group data for group \(groupId): \(error)")
                                return
                            }
                            guard let snapshot = snapshot, let groupData = snapshot.data() else {
                                print("No group data found for group \(groupId)")
                                return
                            }
                            
                            // Merge the two dictionaries.
                            var combinedData = groupData
                            // Ensure the group id is stored under "groupID"
                            combinedData["groupID"] = groupId
                            // Override UI-related fields with values from the user's group_list doc.
                            combinedData["isPinned"] = userGroupData["isPinned"] as? Bool ?? false
                            combinedData["hasUnseenLatestMessage"] = userGroupData["hasUnseenLatestMessage"] as? Bool ?? false
                            
                            // Optionally, override latestMessageTimestamp if it's stored in group_list.
                            if let latestTS = userGroupData["latestMessageTimestamp"] as? Timestamp {
                                combinedData["latestMessageTimestamp"] = latestTS
                            }
                            
                            if let group = GroupChat(data: combinedData) {
                                fetchedGroups.append(group)
                            }
                        }
                }
                
                dispatchGroup.notify(queue: .main) {
                    // Sort pinned and unpinned groups.
                    let pinnedGroups = fetchedGroups.filter { $0.isPinned }.sorted {
                        ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) >
                        ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }
                    let unpinnedGroups = fetchedGroups.filter { !$0.isPinned }.sorted {
                        ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) >
                        ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                    }
                    self.groups = pinnedGroups + unpinnedGroups
                }
            }
    }
    
    func setupFriendRequestListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        friendRequestListener?.remove()
        friendRequestListener = nil
        
        friendRequestListener = FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(uid)
            .collection("request_list")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Failed to listen for friend requests: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    self?.hasNewFriendRequest = !documents.isEmpty
                }
            }
    }
    
    func stopListening() {
        messageListener?.remove()
        messageListener = nil
        groupListener?.remove()
        groupListener = nil
        friendRequestListener?.remove()
        friendRequestListener = nil
    }
    
    func fetchCurrentUser() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        isLoading = true
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
                self.chatUser = ChatUser(data: data)
            }
        }
    }
    
    func markMessageAsSeen(for userId: String) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        let friendRef = FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUserId)
            .collection("friend_list")
            .document(userId)
        
        friendRef.updateData(["hasUnseenLatestMessage": false]) { error in
            if let error = error {
                print("Failed to update hasUnseenLatestMessage: \(error)")
                return
            }
            print("Successfully updated hasUnseenLatestMessage to false")
        }
    }
    
    func handleSignOut() {
        guard let currentUserID = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userRef = FirebaseManager.shared.firestore.collection("users").document(currentUserID)
        
        userRef.updateData(["fcmToken": ""]) { error in
            if let error = error {
                print("Failed to update FCM token: \(error)")
                return
            }
            DispatchQueue.main.async {
                self.isUserCurrentlyLoggedOut.toggle()
                try? FirebaseManager.shared.auth.signOut()
            }
        }
    }
}
