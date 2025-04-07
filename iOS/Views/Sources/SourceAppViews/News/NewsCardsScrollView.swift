// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted
// under the terms of the Proprietary Software License.

import SwiftUI

// MARK: - NewsCardsScrollView

struct NewsCardsScrollView: View {
    // MARK: - Properties
    
    @State private var newsData: [NewsData]
    @State private var sheetStates: [String: Bool] = [:]
    @State var isSheetPresented = false
    
    private enum Constants {
        static let cardSpacing: CGFloat = 10
    }
    
    // MARK: - Initialization
    
    init(newsData: [NewsData]) {
        _newsData = State(initialValue: newsData)
        // Convert debug print to proper logging
        Debug.shared.log(message: "Loaded \(newsData.count) news items", type: .debug)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.cardSpacing) {
                ForEach(newsData.reversed(), id: \.self) { newsItem in
                    let binding = createSheetBinding(for: newsItem)
                    NewsCardContainerView(isSheetPresented: binding, news: newsItem)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func createSheetBinding(for newsItem: NewsData) -> Binding<Bool> {
        return Binding(
            get: { sheetStates[newsItem.identifier] ?? false },
            set: { sheetStates[newsItem.identifier] = $0 }
        )
    }
}
