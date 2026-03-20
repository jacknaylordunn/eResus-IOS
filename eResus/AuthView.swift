//
//  AuthView.swift
//  eResus
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftData

struct AuthView: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var currentNonce: String?
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if firebaseManager.isAuthenticated, let userEmail = firebaseManager.currentUserEmail {
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
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.top, 15)
                    
                } else {
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
                                Button("Sign In") { handleEmailLogin(isSignUp: false) }
                                    .frame(maxWidth: .infinity)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.large)
                                
                                Button("Create") { handleEmailLogin(isSignUp: true) }
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
                    
                    VStack(spacing: 16) {
                        // Native Apple Sign-In
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
                        
                        // Google Sign-In
                        Button(action: handleGoogleSignIn) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Sign in with Google")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle(firebaseManager.isAuthenticated ? "Account" : "Sign In")
        // Triggers silent sync down immediately on sign-in
        .onChange(of: firebaseManager.isAuthenticated) { authenticated in
            if authenticated {
                firebaseManager.downloadLogs(to: modelContext)
            }
        }
    }
    
    // MARK: - Email Auth
    private func handleEmailLogin(isSignUp: Bool) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            return
        }
        isLoading = true
        errorMessage = ""
        
        if isSignUp {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error { self.errorMessage = error.localizedDescription }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                isLoading = false
                if let error = error { self.errorMessage = error.localizedDescription }
            }
        }
    }
    
    // MARK: - Apple Sign-In Callback handler
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce,
                      let appleIDToken = appleIDCredential.identityToken,
                      let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
                
                let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)
                firebaseManager.authenticate(with: credential) { error in
                    if let error = error { self.errorMessage = error.localizedDescription }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Google Sign-In Callback handler
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            firebaseManager.authenticate(with: credential) { authError in
                if let authError = authError { self.errorMessage = authError.localizedDescription }
            }
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
