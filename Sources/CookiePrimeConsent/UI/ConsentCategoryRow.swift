// FILE: Sources/CookiePrimeConsent/UI/ConsentCategoryRow.swift
#if canImport(SwiftUI)
import SwiftUI

/// A detailed consent category row with description
@available(iOS 14.0, *)
public struct ConsentCategoryRow: View {
    
    // MARK: - Properties
    
    let category: ConsentCategory
    let onToggle: (String) -> Void
    
    @State private var isExpanded = false
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconName(for: category.id))
                    .font(.title3)
                    .foregroundColor(category.isEnabled ? .blue : .gray)
                    .frame(width: 30)
                
                // Title and status
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(category.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if category.required {
                            Text("Required")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if category.isEnabled {
                            Label("Enabled", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else if !category.required {
                            Label("Disabled", systemImage: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                if !category.required {
                    Toggle("", isOn: Binding(
                        get: { category.isEnabled },
                        set: { _ in onToggle(category.id) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .labelsHidden()
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                if !category.required {
                    onToggle(category.id)
                }
            }
            
            // Description (collapsible)
            VStack(alignment: .leading, spacing: 8) {
                Text(category.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 16) {
                    if category.required {
                        TagView(text: "Required", color: .gray)
                    } else {
                        TagView(
                            text: category.isEnabled ? "Allowed" : "Blocked",
                            color: category.isEnabled ? .green : .red
                        )
                    }
                    
                    if !category.required && !category.isEnabled {
                        TagView(text: "No Data Shared", color: .blue)
                    }
                }
            }
            .padding(.bottom, isExpanded ? 8 : 0)
            .opacity(isExpanded ? 1 : 0)
            .frame(height: isExpanded ? nil : 0)
            .clipped()
        }
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func iconName(for categoryId: String) -> String {
        switch categoryId {
        case "essential": return "shield.fill"
        case "analytics": return "chart.bar.fill"
        case "advertising": return "megaphone.fill"
        case "social": return "person.2.fill"
        case "location": return "location.fill"
        case "personalization": return "wand.and.stars"
        case "performance": return "gauge.medium"
        case "crash_reporting": return "exclamationmark.triangle.fill"
        case "notifications": return "bell.fill"
        case "attribution": return "link"
        default: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Tag View

@available(iOS 14.0, *)
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 14.0, *)
struct ConsentCategoryRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConsentCategoryRow(
                category: ConsentCategory(
                    id: "analytics",
                    name: "Analytics",
                    description: "Help us improve the app by collecting usage data",
                    required: false,
                    isEnabled: true
                ),
                onToggle: { _ in }
            )
            .previewDisplayName("Analytics (Enabled)")
            
            ConsentCategoryRow(
                category: ConsentCategory(
                    id: "advertising",
                    name: "Advertising",
                    description: "Show you relevant advertisements",
                    required: false,
                    isEnabled: false
                ),
                onToggle: { _ in }
            )
            .previewDisplayName("Advertising (Disabled)")
            
            ConsentCategoryRow(
                category: ConsentCategory(
                    id: "essential",
                    name: "Essential",
                    description: "Required for basic app functionality",
                    required: true,
                    isEnabled: true
                ),
                onToggle: { _ in }
            )
            .previewDisplayName("Essential (Required)")
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
#endif

#endif