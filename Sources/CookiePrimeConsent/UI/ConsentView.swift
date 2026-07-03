// FILE: Sources/CookiePrimeConsent/UI/ConsentView.swift
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Consent View

@available(iOS 14.0, *)
public struct ConsentView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: ConsentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // MARK: - Initialization
    
    public init(viewModel: ConsentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Categories
                    categoriesView
                    
                    // Buttons
                    buttonsView
                    
                    // Error
                    if viewModel.error != nil {
                        errorView
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
            .overlay(loadingOverlay)
            .onChange(of: viewModel.hasChanges) { hasChanges in
                // Update navigation bar if needed
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
                .padding(.top, 8)
            
            Text("Privacy Choices")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(viewModel.getSummary())
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.horizontal)
        }
    }
    
    private var categoriesView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.categories) { category in
                ConsentCategoryRowView(
                    category: category,
                    onToggle: { categoryId in
                        viewModel.toggleCategory(categoryId)
                    }
                )
            }
        }
    }
    
    private var buttonsView: some View {
        VStack(spacing: 12) {
            // Accept All Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.acceptAll()
                }
            }) {
                Text("Accept All")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(viewModel.isSaving)
            
            // Save Button
            Button(action: {
                Task { @MainActor in
                    do {
                        try await viewModel.saveConsent()
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }) {
                Text("Save Selection")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.hasChanges ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(viewModel.hasChanges ? .white : .gray)
                    .cornerRadius(10)
            }
            .disabled(!viewModel.hasChanges || viewModel.isSaving)
            
            // Reject All Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.rejectAll()
                }
            }) {
                Text("Reject All")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.red)
            }
            .disabled(viewModel.isSaving)
        }
    }
    
    private var errorView: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
                .font(.title2)
            
            Text(viewModel.error ?? "Unknown error")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Button("Dismiss") {
                viewModel.error = nil
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isSaving {
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                )
        }
    }
}

// MARK: - Category Row View

@available(iOS 14.0, *)
struct ConsentCategoryRowView: View {
    let category: ConsentCategory
    let onToggle: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if category.required {
                    Text("Required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                } else {
                    Toggle("", isOn: Binding(
                        get: { category.isEnabled },
                        set: { _ in onToggle(category.id) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                    .disabled(category.required)
                }
            }
            
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 14.0, *)
struct ConsentView_Previews: PreviewProvider {
    static var previews: some View {
        let categories = [
            "essential": "Essential (Required)",
            "analytics": "Analytics",
            "advertising": "Advertising",
            "social": "Social Features"
        ]
        let consent = [
            "essential": true,
            "analytics": true,
            "advertising": false,
            "social": false
        ]
        let viewModel = ConsentViewModel(
            appId: "preview",
            categories: categories,
            currentConsent: consent
        )
        
        ConsentView(viewModel: viewModel)
    }
}
#endif

#endif