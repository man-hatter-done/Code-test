// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import SwiftUI

// MARK: - NewsCardView

struct NewsCardView: View {
    // MARK: - Properties
    
    var news: NewsData
    
    private enum Constants {
        static let cardWidth: CGFloat = 250
        static let cardHeight: CGFloat = 150
        static let cornerRadius: CGFloat = 12
        static let blurOpacity: Double = 0.97
        static let gradientOpacity: Double = 0.7
        static let borderOpacity: Double = 0.15
        static let borderWidth: CGFloat = 2
        static let placeholderOpacity: Double = 0.2
        static let animationDuration: Double = 0.3
        static let topPadding: CGFloat = 95
        static let defaultTintColor = "000000"
    }

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            renderBackgroundImage()
            renderBlurOverlay()
            renderTitleContent()
        }
        .frame(
            width: Constants.cardWidth,
            height: Constants.cardHeight
        )
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
            RoundedRectangle(
                cornerRadius: Constants.cornerRadius,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(Constants.borderOpacity),
                lineWidth: Constants.borderWidth
            )
        )
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func renderBackgroundImage() -> some View {
        if news.imageURL != nil {
            // Background image
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
            
            // Gradient overlay
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
        }
    }
    
    private func renderBlurOverlay() -> some View {
        VariableBlurView()
            .opacity(Constants.blurOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotationEffect(.degrees(180))
            .padding(.top, Constants.topPadding)
    }
    
    private func renderTitleContent() -> some View {
        VStack {
            Spacer()
            Text(news.title ?? "")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding()
        }
    }
}
