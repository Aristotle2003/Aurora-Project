//
//  TermsOfServiceView.swift
//  Aurora
//
//  Created by Shawn on 1/11/25.
//

import SwiftUI

struct TermsOfServiceView: View {
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
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - HEADER
                        VStack(spacing: 4) {
                            Text("Terms of Service")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            
                            Text("Last Modified: 01/29/2025")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 16)
                        
                        // MARK: - INTRODUCTION
                        FancySectionView(
                            iconName: "sparkles",
                            title: "Introduction",
                            content: """
Welcome to Aurora!!

These Terms of Service ("Terms") govern your use of Aurora and all associated services (collectively, the "Service"). By using Aurora, you accept these Terms in full. If you disagree with any part of these Terms, you must not use the Service.
These Terms constitute a legally binding agreement between you and Aurora. While we've written them to be as clear as possible, certain sections retain formal legal language to ensure their enforceability.

IMPORTANT: ARBITRATION AGREEMENT
By using Aurora, you agree that all disputes between us will be resolved through binding individual arbitration. This means you waive your right to:
1. Participate in a class-action lawsuit against us
2. Join any class-wide arbitration
3. Have disputes heard by a judge or jury
"""
                        )
                        
                        // MARK: - I. SERVICE DESCRIPTION
                        FancySectionView(
                            iconName: "rectangle.and.pencil.and.ellipsis",
                            title: "I. Service Description",
                            content: """
1.1 Platform Overview
Aurora is a messaging and communication platform that enables users to exchange messages, media, and engage in voice and video calls. We provide these services through our mobile applications.

1.2 Service Availability
We strive to maintain continuous service availability but cannot guarantee uninterrupted access. The Service may be temporarily unavailable for maintenance, upgrades, or factors beyond our control.
"""
                        )
                        
                        // MARK: - II. YOUR ACCOUNT
                        FancySectionView(
                            iconName: "person.crop.circle",
                            title: "II. Your Account",
                            content: """
2.1 Account Creation
You need to create an account with us in order to access and use Aurora. To be eligible, you must register using a valid phone number or email address and provide accurate and truthful registration information. You must be at least 13 years old, or if your jurisdiction requires a higher minimum age for using the Services without parental consent, you must meet that age requirement. Additionally, you are not eligible to create or maintain an account if you have been convicted of any sexual offense or appear on any government list of prohibited persons.

2.2 Account Responsibilities
Your account is personal to you and you are responsible for safeguarding your account information and maintaining the confidentiality of your login credentials. While you may choose to gift, lend, transfer, or permit others to access or use your account, you remain solely responsible for all activities that occur under your account. We bear no responsibility or liability for any consequences arising from such third-party access or use. All account-related elements, including your account name, user ID, and any identifiers you adopt within Aurora, remain our property. We retain the right to disable, reclaim, and reuse these identifiers upon termination or deactivation of your account.

2.3 Third Party Authentication
We may allow you to register for and login to Aurora using sign-on functionalities provided by third-party platforms, such as Google or Apple. By using such third-party sign-on functionalities, you agree to comply with the relevant third-party platform's terms and conditions, in addition to these Terms.
"""
                        )
                        
                        // MARK: - III. YOUR CONTENT
                        FancySectionView(
                            iconName: "doc.richtext",
                            title: "III. Your Content",
                            content: """
3.1 Content Management
We reserve the right to review, moderate, block, or remove content for any reason, though we do not review all content. You are solely responsible for the content you create or share. Keep backups, as we do not guarantee data preservation.

3.2 Reporting and Appeals
Users can report content or accounts that violate our Terms or policies. We will review in a timely manner and reverse decisions if found incorrect. All complaints must be submitted within six months of the relevant moderation decision.

3.2 Content License
When you submit content to Aurora, you retain ownership but grant us a perpetual, non-exclusive, transferable, sub-licensable, royalty-free, worldwide license to use it for operating, improving, and promoting our services. We may share your content with partners who help provide and improve Aurora. We may retain or disclose content to comply with legal obligations.
"""
                        )
                        
                        // MARK: - IV. USER CONDUCT
                        FancySectionView(
                            iconName: "hand.raised.fill",
                            title: "IV. User Conduct",
                            content: """
4.1 General Principles
Respect others, comply with intellectual property laws, and follow our Community Guidelines.

4.2 Prohibited Activities
- Creating multiple accounts for abuse
- Impersonation or fake accounts
- Malware distribution
- Unauthorized access attempts
- Harassment or threats
- Uploading illegal or harmful material
We reserve the right to investigate violations and take appropriate action, including termination of your account or reporting to law enforcement.
"""
                        )
                        
                        // MARK: - V. INTELLECTUAL PROPERTY
                        FancySectionView(
                            iconName: "lightbulb",
                            title: "V. Intellectual Property",
                            content: """
5.1 Proprietary Rights
Aurora owns and retains all rights to the Services, including brands, software, and technology. Respect Aurora's IP rights and use them only as permitted by these Terms.

5.2 Copyright Protection
We follow applicable copyright laws and remove infringing content. Repeat infringers will have their accounts terminated.
"""
                        )
                        
                        // MARK: - VI. THIRD PARTY CONTENT
                        FancySectionView(
                            iconName: "person.3.fill",
                            title: "VI. Third Party Content",
                            content: """
6.1 General
You may access content from various sources within Aurora. We are not responsible for all third-party content’s accuracy or legality.

6.2 Content Review and Removal
We may remove or refuse to display content violating our policies or posing security risks.

6.3 Third Party Services
Aurora may integrate third-party services under their own terms and conditions.

6.4 User Responsibilities
Report misleading or unlawful content immediately. We do not endorse or assume liability for third-party content or services.
"""
                        )
                        
                        // MARK: - VII. SERVICE MODIFICATIONS AND UPDATES
                        FancySectionView(
                            iconName: "rectangle.and.arrow.up.right.and.arrow.down.left.slash",
                            title: "VII. Service Modifications and Updates",
                            content: """
7.1 Service Evolution
We may add or remove features at any time, with or without notice.

7.2 Terms Updates
We may update these Terms. Material changes will be communicated in advance where possible. Continuing to use Aurora means you accept the updated Terms.

7.3 Technical Requirements
You agree to install updates and maintain devices that meet our minimum system requirements.
"""
                        )
                        
                        // MARK: - VIII. TERMINATION
                        FancySectionView(
                            iconName: "stop.fill",
                            title: "VIII. Termination",
                            content: """
8.1 User-Initiated Termination
You may delete your account if you disagree with these Terms.

8.2 Suspension or Termination by Aurora
We may restrict, suspend, or terminate access if you violate these Terms or for any other reason allowed by law.

8.3 Effects of Termination
All rights under these Terms end. Some provisions may survive.

8.4 Content After Termination
We may handle your content as required by law or our policies. We don't guarantee returning your content after account deletion.
"""
                        )
                        
                        // MARK: - IX. LIMITATION OF LIABILITY
                        FancySectionView(
                            iconName: "exclamationmark.triangle.fill",
                            title: "IX. Limitation of Liability",
                            content: """
To the maximum extent allowed by law, Aurora is not liable for indirect, incidental, special, or consequential damages arising from your use of our Services. Our total liability to you for any claim will not exceed the amount you paid Aurora in the previous 12 months or $100, whichever is greater.
"""
                        )
                        
                        // MARK: - X. DISPUTE RESOLUTION
                        FancySectionView(
                            iconName: "hammer.fill",
                            title: "X. Dispute Resolution",
                            content: """
10.1 Agreement to Arbitrate
All claims and disputes arising out of these Terms or Services usage will be resolved by binding arbitration on an individual basis.

10.2 Informal Dispute Resolution
Attempt to resolve disputes informally first by contacting us or vice versa.

10.3 Arbitration Process
If informal resolution fails, arbitration is conducted by a neutral arbitrator under the rules of [Arbitration Provider].

10.4 Class Action Waiver
No class actions or consolidated proceedings.

10.5 Costs
Aurora pays arbitration costs for claims under $10,000, unless deemed frivolous.

10.6 Opt-Out Rights
You may opt out within 30 days by sending written notice.

10.7 Survival
Arbitration agreement survives termination of your account.
"""
                        )
                        
                        // MARK: - XI. CONTACT INFORMATION
                        FancySectionView(
                            iconName: "envelope.fill",
                            title: "XI. Contact Information",
                            content: """
For questions about these Terms, contact us at:
Email: aurora888borealis888@gmail.com
"""
                        )
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitle("Terms of Service", displayMode: .inline)
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

// MARK: - FancySectionView
/// A reusable view to display each section in a "card" style with an icon, title, and text content.
struct FancySectionView: View {
    let iconName: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
            }
            
            Divider()
                .background(Color.accentColor.opacity(0.7))
            
            // Body
            Text(content)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.primary)
                .lineSpacing(5)
        }
        .padding(16)
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
    }
}
