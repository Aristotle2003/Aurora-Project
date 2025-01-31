//
//  PrivacyPolicyView.swift
//  Aurora
//
//  Created by Shawn on 1/11/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
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
            ZStack {
                // MARK: - BACKGROUND GRADIENT
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - HEADER
                        VStack(spacing: 4) {
                            Text("Privacy Policy")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            
                            Text("Last Modified: 01/31/2024")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 16)
                        
                        // MARK: - INTRODUCTION
                        FancyPrivacySectionView(
                            iconName: "lock.shield.fill",
                            sectionTitle: "Introduction",
                            content: """
Welcome to Aurora’s *fancified* Privacy Policy. We aim to clearly explain how we handle, protect, and utilize your personal data. By continuing to use Aurora, you acknowledge and accept these practices, empowering you with significant control over your own information.
"""
                        )
                        
                        // MARK: - INFORMATION COLLECTION
                        FancyPrivacySectionView(
                            iconName: "tray.full.fill",
                            sectionTitle: "I. Information Collection",
                            content: """
                        1.1 User-Provided Information
                        - Account Information: When you register, we collect your mobile phone number for account creation and verification. If you choose to log in through third-party services (such as Apple ID or Google), we'll collect the account information necessary for authentication.
                        
                        - Profile Data: You may choose to provide additional information such as a display name, profile picture, and basic profile details. This information is optional and not required to use the core features of Aurora.
                        
                        - Content: The messages, photos, and videos you share through our platform are temporarily stored on our servers to enable message delivery. This content is encrypted and automatically deleted after being viewed or after a set expiration period.
                        
                        - Customer Support: When you contact our support team, we collect communications and any information you provide to help resolve your issues.
                        
                        1.2 Automatically Collected Information
                        - Device Information: We collect device-specific information such as your device model, operating system version, and unique device identifiers to ensure secure operation and prevent unauthorized access.
                        
                        - Usage Data: We gather data about how you interact with Aurora, including message sending patterns (but not message content), feature usage, and app performance metrics to improve our service.
                        
                        - Connection Information: Basic network data such as IP address and mobile network information is collected to maintain service quality and security.
                        """
                        )
                        
                        // MARK: - INFORMATION USAGE
                        FancyPrivacySectionView(
                            iconName: "gearshape.2.fill",
                            sectionTitle: "II. Information Usage",
                            content: """
                        2.1 Core Service Delivery
                        - Operating the messaging platform and ensuring reliable message delivery
                        - Maintaining account security and verifying user identity
                        - Processing and storing temporary messages until they're viewed
                        - Providing customer support and addressing technical issues
                        - Managing account settings and privacy preferences
                        
                        2.2 Platform Security & Quality
                        - Detecting and preventing unauthorized access or abuse
                        - Maintaining service stability and performance
                        - Conducting security audits and risk assessments
                        - Investigating potential violations of our terms of service
                        - Implementing safety features and content moderation
                        
                        2.3 Service Enhancement
                        - Improving app functionality based on usage patterns
                        - Debugging technical issues and optimizing performance
                        - Developing new features based on user feedback
                        - Conducting research to enhance user experience
                        - Testing and implementing security improvements
                        
                        2.4 Communications
                        - Sending essential service notifications and updates
                        - Providing account security alerts
                        - Responding to customer support inquiries
                        - Delivering important platform announcements
                        - Sending optional marketing communications (with your consent)
                        
                        2.5 Information Sharing
                        We may share information with:
                        - Other users (according to your privacy settings)
                        - Service providers essential for app operation
                        - Law enforcement when legally required
                        - Potential new owners in case of business transfer
                        
                        2.6 Information We Never Share
                        - Private message content
                        - Personal information with advertisers
                        - User data with unauthorized third parties
                        - Sensitive information without explicit consent
                        """
                        )
                        
                        // MARK: - INFORMATION SHARING
                        FancyPrivacySectionView(
                            iconName: "square.and.arrow.up.fill",
                            sectionTitle: "III. Information Sharing",
                            content: """
                        3.1 How We Share Your Information
                        We share your information with the following parties only when necessary:
                        
                        - Other Aurora Users: Content you share will be delivered to your intended recipients according to your privacy settings and choices within the app.
                        
                        - Service Providers: We work with trusted service providers who help us operate Aurora, including:
                            * Cloud storage providers for temporary message storage
                            * Security services for fraud prevention and account protection
                            * Analytics providers to improve our service (using anonymized data only)
                            * Customer support platform providers
                        
                        - Legal Requirements: We may share information when required by law, such as:
                            * Responding to valid legal requests from law enforcement
                            * Complying with court orders or legal proceedings
                            * Protecting user safety and preventing harm
                            * Enforcing our Terms of Service
                        
                        3.2 Business Transfers
                        If Aurora is involved in a merger, acquisition, or sale of assets, we will notify you before your information is transferred and becomes subject to a different privacy policy.
                        
                        3.3 Information We Never Share
                        We will not share:
                        - Your private message content
                        - Your personal information with advertisers
                        - Your contact information with other users without consent
                        - Any sensitive data with unauthorized third parties
                        
                        3.4 International Data Transfers
                        When we transfer your information across borders, we implement appropriate safeguards to protect your data in accordance with applicable laws and regulations.
                        
                        3.5 Third-Party Services
                        If you choose to connect your Aurora account with third-party services, those services may receive information you choose to share with them. Their use of this information is governed by their respective privacy policies.
                        """
                        )
                        
                        // MARK: - DATA STORAGE AND PROTECTION
                        FancyPrivacySectionView(
                            iconName: "externaldrive.fill.badge.person.crop",
                            sectionTitle: "IV. Data Storage and Protection",
                            content: """
                        4.1 Data Storage Duration
                        We store your information based on the following principles:
                        - Messages and Content: Messages are temporarily stored in encrypted form and automatically deleted within 24 hours after being viewed by all recipients, unless you've changed your default settings.
                        - Account Information: Basic account details (phone number, account settings) are retained as long as your account is active.
                        - Profile Data: Profile information is stored until you modify or delete it.
                        - System Logs: Technical logs and usage data are kept for a limited time to maintain service quality and security.
                        
                        We may retain information longer if:
                        - Required by law or valid legal requests
                        - Necessary to prevent harm or investigate violations
                        - Needed to protect the safety and security of our users
                        - Required to resolve disputes or enforce our Terms of Service
                        
                        4.2 Security Measures
                        To protect your personal information, we implement:
                        - End-to-end encryption for messages
                        - Secure data storage with industry-standard encryption
                        - Regular security audits and updates
                        - Access controls and authentication systems
                        - Automated threat detection and prevention
                        - Regular backup systems to prevent data loss
                        
                        4.3 Data Protection Commitments
                        We are committed to:
                        - Storing data securely using industry-standard practices
                        - Limiting employee access to personal information
                        - Regular security training for our team
                        - Prompt notification of any security incidents
                        - Maintaining emergency response procedures
                        - Regular testing of our security systems
                        
                        4.4 Account Closure
                        When you close your Aurora account:
                        - Your messages will be deleted from our servers
                        - Your profile information will be removed
                        - Your account data will be permanently deleted after any required retention period
                        """
                        )
                        
                        // MARK: - MANAGING YOUR INFORMATION
                        FancyPrivacySectionView(
                            iconName: "person.crop.circle.badge.checkmark",
                            sectionTitle: "V. Managing Your Information",
                            content: """
                        5.1 Accessing and Updating Your Information
                        You can manage your information directly through the Aurora app:
                        - View and edit your profile information in Settings
                        - Update your account preferences
                        - Modify your privacy settings
                        - Access your chat history (within message retention period)
                        - Review and update your contact list
                        
                        5.2 Privacy Controls
                        Control who can interact with you:
                        - Choose who can send you messages
                        - Set message visibility preferences
                        - Manage blocked users
                        - Control read receipts
                        - Set message expiration times
                        - Manage who can see your online status
                        
                        5.3 Device Permissions
                        Manage app permissions through your device settings:
                        - Camera access
                        - Microphone access
                        - Contact list access
                        - Storage access
                        - Location services
                        - Push notifications
                        
                        5.4 Message Controls
                        Manage your messages and content:
                        - Delete messages for yourself or all participants
                        - Set auto-deletion timeframes
                        - Save or unsave specific messages
                        - Control message forwarding
                        - Manage media auto-download settings
                        
                        5.5 Account Management
                        Take control of your account:
                        - Change your phone number or email
                        - Update your password and security settings
                        - Enable two-factor authentication
                        - Download your account data
                        - Deactivate or delete your account
                        
                        5.6 Communication Preferences
                        Choose how Aurora communicates with you:
                        - Manage notification settings
                        - Opt out of promotional messages
                        - Control service updates
                        - Set do-not-disturb periods
                        """
                        )
                        
                        // MARK: - AGE AND ELIGIBILITY REQUIREMENTS
                        FancyPrivacySectionView(
                            iconName: "person.2.fill",
                            sectionTitle: "VI. Age and Eligibility Requirements",
                            content: """
                        6.1 Basic Requirements
                        - You must be at least 13 years old to create an Aurora account
                        - You must meet any higher minimum age required in your jurisdiction
                        - You must provide a valid phone number or email address
                        - All registration information must be accurate and truthful
                        - Certain individuals are prohibited from using Aurora (see Restrictions)
                        
                        6.2 Restrictions
                        - No accounts for users under 13
                        - No accounts for individuals convicted of sexual offenses
                        - No accounts for individuals on government prohibited persons lists
                        - Accounts violating these restrictions will be terminated immediately
                        - All associated data will be deleted upon termination
                        
                        6.3 Parental Controls and Oversight
                        - Parents/guardians should review this policy with minor users
                        - Dedicated support for parents managing minor accounts
                        - Resources for safe messaging practices
                        """
                        )
                        
                        // MARK: - POLICY UPDATES
                        FancyPrivacySectionView(
                            iconName: "arrow.triangle.2.circlepath.circle.fill",
                            sectionTitle: "VII. Policy Updates",
                            content: """
                        7.1 Changes to This Policy
                        We may update this Privacy Policy periodically to reflect:
                        - Changes in our services
                        - New legal requirements
                        - Improved privacy protection measures
                        - Updates to our data practices
                        
                        7.2 Notification of Changes
                        When we make changes to this Privacy Policy, we will:
                        - Notify you through in-app notifications
                        - Display a notice in the Aurora app
                        - Update the "Last Modified" date at the top of the policy
                        - Provide a summary of key changes
                        - For significant changes, request your consent when required by law
                        
                        7.3 Review and Consent
                        - We encourage you to review our Privacy Policy regularly
                        - Your continued use of Aurora after policy changes constitutes acceptance of the updated terms
                        - For material changes that affect your privacy rights, we will seek your explicit consent before implementing the changes
                        - Previous versions of the Privacy Policy will be archived and available upon request

                        """
                        )
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitle("Privacy Policy", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .fontWeight(.bold)  // Changed from .bold since it's a cancel button
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                            .font(.system(size: 17))
                    }
                }
            }
        }
    }
}

// MARK: - FancyPrivacySectionView
/// Reusable stylized card for displaying sections of the Privacy Policy
struct FancyPrivacySectionView: View {
    let iconName: String
    let sectionTitle: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(sectionTitle)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
            }
            
            Divider()
                .background(Color.accentColor.opacity(0.7))
            
            // Section Content
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(5)
        }
        .padding(16)
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
    }
}
