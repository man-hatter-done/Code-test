// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import SwiftUI

// MARK: - CardContextMenuView

struct CardContextMenuView: View {
    // MARK: - Properties
    
    @Environment(\.dismiss) var dismiss
    let news: NewsData
    
    private enum Constants {
        static let imageHeight: CGFloat = 250
        static let cornerRadius: CGFloat = 12
        static let containerCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 10
        static let buttonIconPadding: CGFloat = 10
        
        static let stackSpacing: CGFloat = 12
        static let contentSpacing: CGFloat = 16
        
        static let gradientOpacity: Double = 0.2
        static let borderOpacity: Double = 0.15
        static let placeholderOpacity: Double = 0.2
        static let borderWidth: CGFloat = 2
        
        static let animationDuration: Double = 0.3
        static let dateFormat = "yyyy-MM-dd"
        static let defaultTintColor = "000000"
    }
    
    // MARK: - Computed Properties
    
    var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = Constants.dateFormat
        if let date = dateFormatter.date(from: news.date) {
            return date.formatted(.relative(presentation: .named))
        }
        return news.date
    }

    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.stackSpacing) {
                    renderHeaderImage()
                    renderContentSection()
                    Spacer()
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .background(Color(uiColor: .systemBackground))
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: Constants.containerCornerRadius,
                        style: .continuous
                    )
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    renderBackButton()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func renderHeaderImage() -> some View {
        if news.imageURL != nil {
            AsyncImage(url: URL(string: news.imageURL ?? "")) { image in
                Color.clear.overlay(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                )
                .transition(
                    .opacity.animation(.easeInOut(duration: Constants.animationDuration))
                )
            } placeholder: {
                Color.black
                    .opacity(Constants.placeholderOpacity)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    )
            }
            .background(
                Color(uiColor: UIColor(hex: news.tintColor ?? Constants.defaultTintColor))
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Constants.cornerRadius,
                    style: .continuous
                )
            )
            .overlay(
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            .clear,
                            .black.opacity(Constants.gradientOpacity)
                        ]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: Constants.cornerRadius,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(Constants.borderOpacity),
                    lineWidth: Constants.borderWidth
                )
            )
            .frame(height: Constants.imageHeight)
        }
    }
    
    private func renderContentSection() -> some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            // Title section
            if let title = news.title {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }

            // Caption section
            if let caption = news.caption {
                Text(caption)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }

            // URL button
            if let newsURL = news.url {
                Button {
                    UIApplication.shared.open(newsURL)
                } label: {
                    Label("Open URL", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .padding()
                .foregroundColor(.accentColor)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(Constants.buttonCornerRadius)
            }

            // Date section
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func renderBackButton() -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .padding(Constants.buttonIconPadding)
                .compatFontWeight(.bold)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Circle())
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Cross-platform compatible font weight modifier
    func compatFontWeight(_ weight: Font.Weight) -> some View {
        if #available(iOS 16.0, *) {
            return self.fontWeight(weight)
        } else {
            return self
        }
    }
}
