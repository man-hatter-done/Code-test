// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import SwiftUI

/// Extension to define notification names for tab-related events
extension Notification.Name {
    static let tabDidChange = Notification.Name("tabDidChange")
    static let changeTab = Notification.Name("changeTab")
}

/// Main TabView providing navigation between app sections with enhanced appearance
struct TabbarView: View {
    // State for the selected tab, initialized from UserDefaults
    @State private var selectedTab: Tab = .init(rawValue: UserDefaults.standard.string(forKey: "selectedTab") ?? "home") ?? .home

    // Track if a programmatic tab change is in progress to avoid notification loops
    @State private var isProgrammaticTabChange = false
    
    // Animation states for enhanced transitions
    @State private var animateIcon = false
    @State private var previousTab: Tab? = nil
    
    // Environment values for color scheme and dynamic sizing
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Tab identifiers with enhanced visual properties
    enum Tab: String, CaseIterable, Identifiable {
        case home
        case sources
        case library
        case settings
        case bdgHub

        var id: String { self.rawValue }

        var displayName: String {
            switch self {
                case .home: return String.localized("TAB_HOME")
                case .sources: return String.localized("TAB_SOURCES")
                case .library: return String.localized("TAB_LIBRARY")
                case .settings: return String.localized("TAB_SETTINGS")
                case .bdgHub: return "BDG HUB"
            }
        }

        var iconName: String {
            switch self {
                case .home: return "house.fill"
                case .sources:
                    if #available(iOS 16.0, *) {
                        return "globe.desk.fill"
                    } else {
                        return "books.vertical.fill"
                    }
                case .library: return "square.grid.2x2.fill"
                case .settings: return "gearshape.2.fill"
                case .bdgHub: return "sparkles" // More modern icon for BDG Hub
            }
        }
        
        // Each tab has its own accent color for better visual distinction
        var accentColor: Color {
            switch self {
                case .home: return Color.blue
                case .sources: return Color.purple
                case .library: return Color.orange
                case .settings: return Color.gray
                case .bdgHub: return Color(UIColor(hex: "#FF6482")) // Pink accent for BDG Hub
            }
        }
        
        // Additional SF Symbols icons for selected state
        var selectedIconName: String? {
            switch self {
                case .bdgHub: return "sparkles.rectangle.stack.fill"
                default: return nil
            }
        }
    }

    // Initialize with notification observer for tab changes and UI appearance
    init() {
        Debug.shared.log(message: "Enhanced TabbarView initialized", type: .debug)
        
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Add subtle shadow
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        
        // Add subtle blur effect for a more modern look
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        
        // Configure selected item appearance
        let itemAppearance = UITabBarItemAppearance()
        
        // Adjust label appearance for selected/normal states
        itemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        itemAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular)
        ]
        
        // Apply appearances
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        // Set the appearance for the tab bar
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    // Handle tab change notification from other parts of the app with enhanced animations
    private func handleTabChangeNotification(_ notification: Notification) {
        if let newTab = notification.userInfo?["tab"] as? String,
           let tab = Tab(rawValue: newTab)
        {
            // Store previous tab for transition direction
            previousTab = selectedTab
            
            // Set the flag to prevent duplicate notifications
            isProgrammaticTabChange = true

            // Update tab with enhanced animation on the main thread
            DispatchQueue.main.async {
                // Animate icon before tab change
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animateIcon = true
                }
                
                // Change tab with animation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedTab = tab
                }
                
                // Reset icon animation with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        animateIcon = false
                    }
                }

                // Save selection to UserDefaults
                UserDefaults.standard.set(tab.rawValue, forKey: "selectedTab")
                UserDefaults.standard.synchronize()

                // Reset the flag with a slight delay to allow animations to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProgrammaticTabChange = false

                    // Notify that tab change is complete
                    NotificationCenter.default.post(
                        name: .tabDidChange,
                        object: nil,
                        userInfo: ["tab": tab.rawValue]
                    )
                }
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tabCase in
                tabView(for: tabCase)
                    .tag(tabCase)
            }
        }
        // Apply dynamic accent color based on selected tab
        .accentColor(selectedTab.accentColor)
        
        // Apply smoother animation for tab content changes
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        
        // Apply modern tab transition effect
        .transition(.asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ))
        
        // Handle tab change notifications
        .onReceive(NotificationCenter.default.publisher(for: .changeTab)) { notification in
            handleTabChangeNotification(notification)
        }
        
        // Handle user-initiated tab changes with enhanced feedback
        .onChange(of: selectedTab) { newTab in
            // Only handle if not a programmatic change to avoid loops
            if !isProgrammaticTabChange {
                // Store previous tab for transition direction
                previousTab = selectedTab
                
                // Save the selected tab to UserDefaults
                UserDefaults.standard.set(newTab.rawValue, forKey: "selectedTab")
                UserDefaults.standard.synchronize()

                // Log the tab change
                Debug.shared.log(message: "User changed tab to: \(newTab.rawValue)", type: .debug)

                // Trigger animation for tab change with enhanced feedback
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.4)) {
                    // Provide enhanced haptic feedback for tab change
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare() // Prepare the generator for immediate use
                    generator.impactOccurred(intensity: 0.8)

                    // Animate icon
                    animateIcon = true
                    
                    // Reset animation after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            animateIcon = false
                        }
                    }

                    // Notify that tab has changed (for other components to react)
                    NotificationCenter.default.post(
                        name: .tabDidChange,
                        object: nil,
                        userInfo: ["tab": newTab.rawValue]
                    )
                }
            }
        }
        .onAppear {
            // Ensure the app is responsive on appear
            if let topVC = UIApplication.shared.topMostViewController() {
                topVC.view.isUserInteractionEnabled = true

                // Log the initial tab
                Debug.shared.log(message: "Enhanced TabbarView appeared with tab: \(selectedTab.rawValue)", type: .debug)
            }
        }
    }

    @ViewBuilder
    private func tabView(for tab: Tab) -> some View {
        switch tab {
            case .home:
                createTab(
                    viewController: HomeViewController.self,
                    title: tab.displayName,
                    imageName: tab.iconName,
                    selectedImageName: tab.selectedIconName,
                    color: tab.accentColor,
                    isSelected: selectedTab == tab
                )
            case .sources:
                createTab(
                    viewController: SourcesViewController.self,
                    title: tab.displayName,
                    imageName: tab.iconName,
                    selectedImageName: tab.selectedIconName,
                    color: tab.accentColor,
                    isSelected: selectedTab == tab
                )
            case .library:
                createTab(
                    viewController: LibraryViewController.self,
                    title: tab.displayName,
                    imageName: tab.iconName,
                    selectedImageName: tab.selectedIconName,
                    color: tab.accentColor,
                    isSelected: selectedTab == tab
                )
            case .settings:
                createTab(
                    viewController: SettingsViewController.self,
                    title: tab.displayName,
                    imageName: tab.iconName,
                    selectedImageName: tab.selectedIconName,
                    color: tab.accentColor,
                    isSelected: selectedTab == tab
                )
            case .bdgHub:
                createTab(
                    viewController: WebViewController.self,
                    title: tab.displayName,
                    imageName: tab.iconName,
                    selectedImageName: tab.selectedIconName,
                    color: tab.accentColor,
                    isSelected: selectedTab == tab
                )
        }
    }

    @ViewBuilder
    private func createTab<T: UIViewController>(
        viewController: T.Type,
        title: String,
        imageName: String,
        selectedImageName: String? = nil,
        color: Color,
        isSelected: Bool
    ) -> some View {
        NavigationViewController(viewController, title: title, tintColor: UIColor(color))
            .edgesIgnoringSafeArea(.all)
            .tabItem {
                VStack {
                    // Use different icon if provided and selected
                    if isSelected, let selectedName = selectedImageName {
                        Image(systemName: selectedName)
                            .renderingMode(.template)
                            .scaleEffect(isSelected && animateIcon ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected && animateIcon)
                    } else {
                        Image(systemName: imageName)
                            .renderingMode(.template)
                            .scaleEffect(isSelected && animateIcon ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected && animateIcon)
                    }
                    
                    Text(title)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                }
            }
            // Add enhanced transition effects
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                removal: .opacity.combined(with: .scale(scale: 1.1))
            ))
    }
}

/// SwiftUI wrapper for UIKit view controllers with improved lifecycle management
struct NavigationViewController<Content: UIViewController>: UIViewControllerRepresentable {
    let content: Content.Type
    let title: String
    let tintColor: UIColor
    
    // Coordinator to maintain controller references and prevent premature deallocations
    class Coordinator {
        var viewController: UIViewController?
    }

    init(_ content: Content.Type, title: String, tintColor: UIColor = .systemBlue) {
        self.content = content
        self.title = title
        self.tintColor = tintColor
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        // Create view controller
        let viewController = content.init()
        context.coordinator.viewController = viewController

        // Configure view controller with improved styling
        viewController.navigationItem.title = title
        
        // Apply modern appearance
        viewController.view.backgroundColor = .systemBackground
        
        // Apply modern shadow style to the view
        viewController.view.layer.shadowColor = UIColor.black.withAlphaComponent(0.15).cgColor
        viewController.view.layer.shadowOffset = CGSize(width: 0, height: 1)
        viewController.view.layer.shadowRadius = 1.5
        viewController.view.layer.shadowOpacity = 0

        // Ensure user interaction is enabled
        viewController.view.isUserInteractionEnabled = true

        // Create navigation controller with enhanced appearance
        let navController = UINavigationController(rootViewController: viewController)
        
        // Apply tint color for a consistent theme
        navController.navigationBar.tintColor = tintColor
        
        // Configure enhanced navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        
        // Apply improved title formatting
        appearance.titleTextAttributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Apply the appearance to all navigation bar styles
        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navController.navigationBar.scrollEdgeAppearance = appearance
        }

        // Ensure navigation controller is interactive
        navController.view.isUserInteractionEnabled = true

        // Ensure the controller is properly initialized
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        // Log successful creation
        Debug.shared.log(message: "Created enhanced navigation controller for \(String(describing: content))", type: .debug)

        return navController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context _: Context) {
        // Ensure the view controller remains responsive
        uiViewController.view.isUserInteractionEnabled = true
        
        // Update navigation bar tint color
        uiViewController.navigationBar.tintColor = tintColor

        // Update top view controller's properties if needed
        if let topVC = uiViewController.topViewController {
            topVC.view.isUserInteractionEnabled = true

            // Update title if changed with smooth transition
            if topVC.navigationItem.title != title {
                // Animate title change for a smoother experience
                UIView.transition(with: uiViewController.navigationBar, duration: 0.3, options: .transitionCrossDissolve) {
                    topVC.navigationItem.title = title
                }
            }

            // If the view controller supports content refreshing, refresh it
            // Check if the view is loaded and visible first to avoid unnecessary work
            if topVC.isViewLoaded && topVC.view.window != nil {
                topVC.refreshContent() 
            }
        }
    }
}

/// Protocol for view controllers that can refresh their content during tab switches
protocol ViewControllerRefreshable {
    func refreshContent()
}

/// Default implementation for all UIViewControllers
extension UIViewController: ViewControllerRefreshable {
    @objc func refreshContent() {
        // Default implementation does nothing
        // Subclasses can override this to refresh their content when tabs switch
    }
}
