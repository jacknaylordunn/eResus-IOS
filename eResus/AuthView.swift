//
//  AuthView.swift
//  eResus
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

struct AuthView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var currentNonce: String?
    
    // Email / Password States
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if firebaseManager.isAuthenticated, let userEmail = firebaseManager.currentUserEmail {
                    // MARK: - Logged In State
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                        .padding(.top, 40)
                    
                    Text("Welcome to eResus")
                        .font(.largeTitle).bold()
                    
                    Text("Signed in as: \(userEmail)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("Sign Out") {
                        firebaseManager.signOut()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .padding(.top, 20)
                    
                } else {
                    // MARK: - Logged Out State
                    Image(systemName: "person.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    Text("Sign in to eResus")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Sync your logbooks and retain your organization profile across devices.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Email & Password Fields
                    VStack(spacing: 16) {
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            HStack(spacing: 16) {
                                Button("Sign In") {
                                    handleEmailSignIn()
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                
                                Button("Create Account") {
                                    handleEmailSignUp()
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        VStack { Divider() }
                        Text("OR").font(.caption).foregroundColor(.secondary)
                        VStack { Divider() }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Native Apple Sign-In Button
                    SignInWithAppleButton(
                        onRequest: { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        },
                        onCompletion: { result in
                            handleAppleSignIn(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(AppSettings.appearanceMode == .dark ? .white : .black)
                    .frame(height: 50)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle(firebaseManager.isAuthenticated ? "Account" : "Sign In")
    }
    
    // MARK: - Email Auth Handlers
    private func handleEmailSignIn() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            return
        }
        isLoading = true
        errorMessage = ""
        
        firebaseManager.signInWithEmail(email: email, password: password) { error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleEmailSignUp() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter an email and a password to create an account."
            return
        }
        isLoading = true
        errorMessage = ""
        
        firebaseManager.signUpWithEmail(email: email, password: password) { error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Apple Sign-In Callback handler
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else { return }
                guard let appleIDToken = appleIDCredential.identityToken else { return }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
                
                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Cryptography Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Unable to generate nonce.") }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
