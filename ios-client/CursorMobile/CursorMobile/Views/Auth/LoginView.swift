import SwiftUI
import AVFoundation

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var savedHostsManager = SavedHostsManager.shared
    @State private var serverUrl = ""
    @State private var token = ""
    @State private var isConnecting = false
    @State private var showScanner = false
    @State private var connectingHostId: UUID? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                        
                        Text("Cursor Mobile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Control your Cursor IDE from your iPhone")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Saved Hosts Section (if any exist)
                    if savedHostsManager.hasSavedHosts {
                        VStack(spacing: 12) {
                            Text("Previous Hosts")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                ForEach(savedHostsManager.savedHosts) { host in
                                    SavedHostRow(
                                        host: host,
                                        isConnecting: connectingHostId == host.id,
                                        onConnect: {
                                            connectToSavedHost(host)
                                        },
                                        onDelete: {
                                            savedHostsManager.removeHost(host)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                    }
                    
                    // QR Code Scanner Button
                    VStack(spacing: 12) {
                        Button {
                            showScanner = true
                        } label: {
                            Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Text("Scan the QR code shown in your terminal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)
                    
                    // Manual Entry Form
                    VStack(spacing: 16) {
                        Text("Manual Connection")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server Address")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("http://192.168.1.100:3847", text: $serverUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Auth Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            SecureField("Enter your token", text: $token)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        Button {
                            connect()
                        } label: {
                            Group {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Connect")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canConnect ? Color.accentColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canConnect || isConnecting)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = authManager.error {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to connect:")
                            .font(.headline)
                        
                        InstructionRow(number: 1, text: "Run the server on your laptop")
                        InstructionRow(number: 2, text: "Scan the QR code or enter the server details")
                        InstructionRow(number: 3, text: "Start controlling Cursor!")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showScanner) {
                QRScannerView { result in
                    handleQRCode(result)
                    showScanner = false
                }
            }
        }
    }
    
    private var canConnect: Bool {
        !serverUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !token.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func connect() {
        isConnecting = true
        Task {
            await authManager.login(serverUrl: serverUrl, token: token)
            isConnecting = false
        }
    }
    
    private func handleQRCode(_ code: String) {
        // Parse QR code URL
        // Format: http://IP:PORT/?token=TOKEN
        guard let url = URL(string: code),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            authManager.error = "Invalid QR code"
            return
        }
        
        // Extract token from query
        if let tokenParam = components.queryItems?.first(where: { $0.name == "token" })?.value {
            token = tokenParam
        }
        
        // Build server URL (without query params)
        if let host = components.host {
            let port = components.port ?? 3847
            serverUrl = "\(components.scheme ?? "http")://\(host):\(port)"
        }
        
        // Auto-connect if we have both
        if !serverUrl.isEmpty && !token.isEmpty {
            connect()
        }
    }
    
    private func connectToSavedHost(_ host: SavedHost) {
        connectingHostId = host.id
        Task {
            await authManager.login(serverUrl: host.serverUrl, token: host.token)
            connectingHostId = nil
        }
    }
}

// MARK: - SavedHostRow Component

struct SavedHostRow: View {
    let host: SavedHost
    let isConnecting: Bool
    let onConnect: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 12) {
                // Host icon
                Image(systemName: "desktopcomputer")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                
                // Host info
                VStack(alignment: .leading, spacing: 2) {
                    Text(host.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(host.serverDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Connected \(host.formattedLastConnected)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                // Connect/loading indicator
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .disabled(isConnecting)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Remove \(host.displayName)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the saved connection. You can reconnect by scanning the QR code or entering the details manually.")
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
