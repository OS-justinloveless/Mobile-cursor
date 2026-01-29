import SwiftUI

/// Sheet for configuring git repository filters
struct GitFilterSheet: View {
    @Binding var settings: GitFilterSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var newExcludePath = ""
    @State private var showAddPathAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // Sort Section
                Section {
                    Picker("Sort by", selection: $settings.sortOption) {
                        ForEach(GitFilterSettings.SortOption.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Sorting")
                } footer: {
                    Text("Choose how repositories are ordered in the list.")
                }
                
                // Filter Section
                Section {
                    Toggle(isOn: $settings.hideCleanRepos) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide clean repos")
                            Text("Repos with no changes to commit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $settings.hideSyncedRepos) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide synced repos")
                            Text("Repos with nothing to push or pull")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Visibility Filters")
                }
                
                // Excluded Paths Section
                Section {
                    ForEach(settings.excludedPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder.badge.minus")
                                .foregroundStyle(.red)
                            Text(path)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                        }
                    }
                    .onDelete { indexSet in
                        settings.excludedPaths.remove(atOffsets: indexSet)
                    }
                    
                    Button {
                        showAddPathAlert = true
                    } label: {
                        Label("Add excluded path", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Excluded Paths")
                } footer: {
                    Text("Use glob patterns to exclude repos. Examples: external/**, vendor/*, node_modules/**")
                }
                
                // Reset Section
                if settings.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            withAnimation {
                                settings.reset()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Reset All Filters", systemImage: "arrow.counterclockwise")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Add Excluded Path", isPresented: $showAddPathAlert) {
                TextField("Path pattern (e.g., external/**)", text: $newExcludePath)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Button("Cancel", role: .cancel) {
                    newExcludePath = ""
                }
                
                Button("Add") {
                    let trimmed = newExcludePath.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !settings.excludedPaths.contains(trimmed) {
                        settings.excludedPaths.append(trimmed)
                    }
                    newExcludePath = ""
                }
            } message: {
                Text("Enter a glob pattern to exclude matching repositories.")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GitFilterSheet(settings: .constant(GitFilterSettings()))
}
