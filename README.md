# 🍽️ MealPrep iOS App

A comprehensive meal planning and recipe management iOS application built with SwiftUI, featuring AI-powered meal generation, nutrition analysis, and smart shopping lists.

[![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green.svg)](https://developer.apple.com/xcode/swiftui/)

## 📱 Features

### 🍳 Recipe Management
- **Recipe Discovery**: Browse and search thousands of recipes with advanced filtering
- **Recipe Details**: Comprehensive ingredient lists, step-by-step instructions, and nutrition info
- **Recipe Creation**: Add and customize your own recipes with AI assistance
- **Smart Filtering**: Filter by cuisine, diet, cooking time, difficulty, and ingredients
- **Recipe Collections**: Organize recipes into custom collections and categories

### 📅 Meal Planning
- **Weekly Meal Plans**: Plan your meals for the entire week with drag & drop interface
- **Smart Scheduling**: Intuitive meal scheduling with automatic conflict detection
- **Meal Templates**: Save and reuse your favorite meal combinations
- **Batch Operations**: Copy from last week, duplicate to next week, clear all meals
- **Serving Adjustments**: Flexible serving size adjustments with real-time nutrition updates
- **Multiple Meal Types**: Support for breakfast, lunch, dinner, and snacks

### 🤖 AI-Powered Features
- **AI Recipe Generation**: Generate custom recipes based on your preferences and dietary restrictions
- **Smart Meal Planning**: AI-powered weekly meal plan generation with nutritional balance
- **Intelligent Recommendations**: Personalized recipe suggestions based on your history
- **Dietary Adaptation**: Automatic recipe modifications for dietary restrictions

### 📊 Nutrition Analysis
- **Comprehensive Tracking**: Detailed nutrition analysis for meals and weekly plans
- **Daily Summaries**: Monitor your daily nutritional intake and goals
- **Weekly Insights**: View weekly nutrition trends with actionable recommendations
- **Goal Setting**: Set and track custom nutritional targets
- **Visual Reports**: Interactive charts and graphs for nutrition data

### 🛒 Smart Shopping
- **Auto-Generated Lists**: Automatically create shopping lists from meal plans
- **Ingredient Consolidation**: Smart merging and grouping of duplicate ingredients
- **Shopping Progress**: Track your shopping progress with interactive checkboxes
- **Category Organization**: Ingredients organized by supermarket sections
- **Offline Access**: Shopping lists available offline for in-store use

### ❤️ Favorites & Collections
- **Favorite Recipes**: Save your most-loved recipes with personal ratings and notes
- **Custom Collections**: Organize recipes into themed collections
- **Quick Access**: Fast access to frequently used recipes from meal planning
- **Smart Suggestions**: Recommendations based on your favorite recipe patterns

### 👤 User Management
- **User Profiles**: Personalized experience with dietary preferences and restrictions
- **Sync Across Devices**: Cloud synchronization for seamless multi-device experience
- **Offline Support**: Full functionality available without internet connection
- **Data Privacy**: Local-first architecture with secure cloud backup

## 🏗️ Architecture

The app follows modern iOS development best practices with a feature-based, modular architecture:

```
MealPrepIOSApp/
├── App/                            # 🚀 Application Entry Point
│   ├── MealPrepIOSAppApp.swift    # Main app file
│   └── ContentView.swift          # Root content view
│
├── Core/                          # 🧠 Core Business Logic
│   ├── Models/                    # Data models and Core Data extensions
│   │   ├── Recipe.swift, User.swift, MealPlan.swift
│   │   ├── CachedUserMappingExtension.swift
│   │   └── CachedRecipeMappingExtension.swift
│   ├── Services/                  # Business logic and API services
│   │   ├── NetworkManager.swift, AuthenticationService.swift
│   │   ├── AIGenerationService.swift, MealPlanService.swift
│   │   ├── ShoppingListService.swift, NutritionAnalysisService.swift
│   │   └── CoreDataManager.swift
│   ├── Stores/                    # State management (ObservableObject)
│   │   ├── MealPlanStore.swift
│   │   ├── MealPlanStoreAnalysisExtension.swift
│   │   ├── MealPlanStoreLoadingExtension.swift
│   │   ├── MealPlanStoreMealManagementExtension.swift
│   │   ├── AuthStore.swift, RecipeStore.swift
│   │   └── FavoritesStore.swift, UserProfileStore.swift
│   └── Utils/                     # Utilities and extensions
│       ├── Logger.swift, ErrorHandler.swift
│       ├── AppError.swift, Extensions.swift
│       └── CacheManager.swift
│
├── Features/                      # 🎯 Feature-Based Organization
│   ├── Authentication/            # Login and registration
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Recipes/                   # Recipe management
│   │   ├── RecipesView.swift, RecipeDetailView.swift
│   │   ├── EditRecipeView.swift, RecipeFiltersView.swift
│   │   └── AIRecipeGenerationView.swift
│   ├── MealPlanning/              # Meal planning and analysis
│   │   ├── MealPlanView.swift, MealPlanAnalysisView.swift
│   │   ├── ShoppingListView.swift
│   │   ├── MealSelectionBottomSheet.swift
│   │   ├── MealActionSheet.swift, MealPlanTemplateSheet.swift
│   │   ├── BatchOperationsSheet.swift
│   │   └── MealPlanStoreBatchOperationsExtension.swift
│   ├── Favorites/                 # Favorites management
│   │   ├── FavoritesView.swift, FavoriteDetailView.swift
│   │   ├── EditFavoriteView.swift
│   │   └── FavoriteFiltersView.swift
│   ├── Profile/                   # User profile management
│   │   └── ProfileView.swift
│   └── AIGeneration/              # AI-powered features
│       ├── AIWorkflowCoordinator.swift
│       ├── AIWeeklyGenerationView.swift
│       ├── AIWeeklyWorkflowView.swift
│       ├── AIWeeklyPreviewView.swift
│       ├── MealPlanGenerationView.swift
│       └── MealPlanStoreAIExtension.swift
│
├── Shared/                        # 🔄 Shared Components and Resources
│   ├── Components/                # Reusable UI components
│   │   ├── SharedComponents.swift, AsyncImageView.swift
│   │   ├── LoadingAnimations.swift, MarkdownText.swift
│   │   ├── DefaultRecipeImageView.swift
│   │   ├── LightweightDailyMealCard.swift
│   │   ├── LightweightMealSlotView.swift
│   │   ├── RecipeStubCardView.swift
│   │   └── MagicUIComponents.swift
│   ├── Extensions/                # Shared extensions
│   │   └── NotificationExtensions.swift
│   └── Theme/                     # App theming and styling
│       └── GreenTheme.swift
│
└── Resources/                     # 📦 App Resources
    ├── Assets/                    # Images, colors, app icons
    │   └── Assets.xcassets/
    ├── Data/                      # Core Data models
    │   └── MealPrepDataModel.xcdatamodeld/
    └── Documentation/             # Project documentation
        └── AIWorkflowIntegration.md
```

## 🛠️ Technical Stack

### **Frontend Architecture**
- **SwiftUI**: Declarative UI framework with modern iOS design patterns
- **Combine**: Reactive programming for seamless data flow and state management
- **Core Data**: Robust local data persistence and offline support
- **URLSession**: High-performance networking with async/await patterns

### **State Management**
- **ObservableObject**: Reactive state management with automatic UI updates
- **Environment Objects**: Dependency injection and shared state management
- **Published Properties**: Real-time UI synchronization with data changes

### **Networking & APIs**
- **REST API**: Communication with Django backend using modern async/await
- **JWT Authentication**: Secure token-based authentication with auto-refresh
- **Error Handling**: Comprehensive error management with user-friendly messages
- **Offline Support**: Local-first architecture with intelligent sync

### **Data Storage**
- **Core Data**: Primary local storage with complex relationships
- **Keychain**: Secure credential and sensitive data storage
- **UserDefaults**: App preferences and lightweight settings
- **File System**: Advanced meal plan storage with multi-week support

### **Dependencies**
- **KeychainSwift** (24.0.0): Secure keychain access and credential management
- **AnyCodable** (0.6.7): Flexible JSON encoding/decoding for dynamic API responses
- **Reachability** (master): Network connectivity monitoring and offline detection

## 📋 Requirements

- **iOS**: 15.0+ (supports iOS 26 beta)
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **Deployment Target**: iOS 15.0 minimum, iOS 18.0 optimized
- **Device Support**: iPhone, iPad, Apple Silicon Macs with Catalyst

## 🚀 Getting Started

### Prerequisites
1. **Xcode 15.0+** with iOS SDK
2. **Apple Developer Account** (for device testing and distribution)
3. **Backend API Access** (Django REST API)

### Installation

1. **Clone the Repository**
   ```bash
   git clone [repository-url]
   cd MealPrep/MealPrepIOSApp
   ```

2. **Open Project**
   ```bash
   open MealPrepIOSApp.xcodeproj
   ```

3. **Configure Backend Connection**
   ```swift
   // Update NetworkManager.swift
   private let baseURL = "http://127.0.0.1:8000"      // Local development
   // private let baseURL = "https://meal-prep-app-backend.vercel.app"  // Production
   ```

4. **Install Dependencies**
   - Dependencies are automatically resolved via Swift Package Manager
   - No manual installation required

5. **Build and Run**
   - Select target device/simulator
   - Press `⌘+R` to build and run

### Development Configuration

#### Backend Integration
```swift
// Development Environment
#if DEBUG
let apiBaseURL = "http://127.0.0.1:8000"
let enableDebugLogging = true
#else
let apiBaseURL = "https://meal-prep-app-backend.vercel.app"
let enableDebugLogging = false
#endif
```

#### Feature Flags
```swift
struct FeatureFlags {
    static let aiGenerationEnabled = true
    static let nutritionAnalysisEnabled = true
    static let shoppingListEnabled = true
    static let offlineModeEnabled = true
}
```

## 🧪 Testing

Comprehensive testing suite covering all application layers:

### **Unit Tests** (`MealPrepIOSAppTests/`)
- **Model Testing**: Data parsing, validation, and transformation
- **Service Testing**: API integration, business logic, and error handling
- **Store Testing**: State management, reactive updates, and data flow
- **Utility Testing**: Helper functions, extensions, and calculations

### **Integration Tests**
- **API Contract Tests**: Backend compatibility and response validation
- **Core Data Tests**: Database operations and data integrity
- **Authentication Flow**: End-to-end login and token management
- **Storage Integration**: File system and caching functionality

### **UI Tests** (`MealPrepIOSAppUITests/`)
- **User Workflows**: Complete user journey testing
- **Navigation Testing**: Screen transitions and deep linking
- **Accessibility Testing**: VoiceOver and accessibility compliance
- **Performance Testing**: Load times and memory usage

### **Running Tests**
```bash
# All tests
xcodebuild test -scheme MealPrepIOSApp -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Unit tests only
⌘+U in Xcode (fastest)

# Specific test suite
xcodebuild test -scheme MealPrepIOSApp -only-testing:MealPrepIOSAppTests/RecipeStoreTests

# UI tests
xcodebuild test -scheme MealPrepIOSApp -only-testing:MealPrepIOSAppUITests
```

## 🏃‍♂️ Development Workflow

### **Code Standards**
- **Swift Style Guide**: Follow Apple's Swift API Design Guidelines
- **SwiftUI Best Practices**: Declarative UI patterns and performance optimization  
- **MVVM Architecture**: Clear separation between Views, ViewModels, and Models
- **Error Handling**: Comprehensive error handling with user-friendly messages

### **Git Workflow**
```bash
# Feature development
git checkout -b feature/meal-plan-templates
git add .
git commit -m "feat: add meal plan template management

- Implement template saving and loading
- Add duplicate template detection
- Create template selection UI"
git push origin feature/meal-plan-templates
```

### **Build Configurations**
```bash
# Development build
xcodebuild -scheme MealPrepIOSApp -configuration Debug build

# Release build  
xcodebuild -scheme MealPrepIOSApp -configuration Release build

# Archive for distribution
xcodebuild archive -scheme MealPrepIOSApp -archivePath build/MealPrepIOSApp.xcarchive
```

## 🐛 Debugging & Troubleshooting

### **Common Issues & Solutions**

#### Build Issues
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package cache
File → Package → Reset Package Caches (in Xcode)

# Clean build
xcodebuild clean && xcodebuild build
```

#### Runtime Issues
```bash
# Reset simulator
xcrun simctl erase all

# Clear app data
xcrun simctl uninstall booted [bundle-identifier]
```

### **Debugging Tools**
- **Console Logging**: Structured logging with different levels
- **Network Inspector**: Built-in request/response logging
- **Core Data Debugger**: Database query and relationship debugging
- **Memory Graph**: Memory leak detection and optimization

### **Performance Monitoring**
```swift
// Enable performance monitoring
#if DEBUG
import OSLog
let logger = Logger(subsystem: "com.mealprep.app", category: "performance")
#endif
```

## 📱 Deployment

### **App Store Distribution**

1. **Prepare Release**
   ```bash
   # Update version and build numbers
   # Configure release signing certificates
   # Run full test suite
   xcodebuild test -scheme MealPrepIOSApp
   ```

2. **Archive and Upload**
   ```bash
   # Archive release build
   Product → Archive (in Xcode)
   
   # Upload to App Store Connect
   # Configure app metadata and screenshots
   ```

3. **TestFlight Distribution**
   - Internal testing with development team
   - External testing with beta user groups
   - Gradual rollout and feedback collection

### **Enterprise Distribution**
```bash
# Configure enterprise certificates
# Build with enterprise provisioning profile  
# Distribute via internal app catalog
```

## 🔧 Configuration

### **Environment Variables**
```swift
// Configure for different environments
enum Environment {
    case development
    case staging  
    case production
    
    var apiBaseURL: String {
        switch self {
        case .development: return "http://127.0.0.1:8000"
        case .staging: return "https://staging.meal-prep-app.com"
        case .production: return "https://meal-prep-app-backend.vercel.app"
        }
    }
}
```

### **Build Settings**
- **Deployment Target**: iOS 15.0
- **Supported Architectures**: arm64, x86_64 (simulator)
- **Bitcode**: Disabled (iOS 15+ default)
- **App Transport Security**: Configured for HTTPS

## 📖 API Integration

### **Authentication Endpoints**
```
POST /api/auth/login/          # User authentication
POST /api/auth/register/       # User registration  
POST /api/auth/logout/         # Session termination
POST /api/auth/refresh/        # Token refresh
```

### **Recipe Management**
```
GET    /api/recipes/           # Browse recipes
POST   /api/recipes/           # Create recipe
GET    /api/recipes/{id}/      # Recipe details
PUT    /api/recipes/{id}/      # Update recipe
DELETE /api/recipes/{id}/      # Delete recipe
```

### **Meal Planning**
```
GET    /api/meal-plans/        # User meal plans
POST   /api/meal-plans/        # Create meal plan
PUT    /api/meal-plans/{id}/   # Update meal plan
POST   /api/meal-plans/{id}/analyze/  # Nutrition analysis
```

### **AI Features**
```
POST   /api/ai/generate-recipe/      # AI recipe generation
POST   /api/ai/generate-meal-plan/   # AI meal planning
POST   /api/ai/recipe-suggestions/   # Smart recommendations
```

## 🤝 Contributing

### **Getting Started**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add comprehensive tests
5. Ensure all tests pass (`⌘+U`)
6. Submit a pull request

### **Code Review Process**
- **Architecture Review**: Ensure changes follow MVVM patterns
- **Performance Review**: Memory usage and CPU optimization
- **Accessibility Review**: VoiceOver and accessibility compliance
- **Security Review**: Data handling and API security

### **Contribution Guidelines**
- Follow Swift API Design Guidelines
- Include unit tests for new functionality
- Update documentation for API changes
- Maintain backward compatibility when possible

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

### **Getting Help**
- **Issues**: Create an issue on GitHub for bugs and feature requests
- **Documentation**: Check `/Resources/Documentation/` for detailed guides
- **Discussions**: Join community discussions for general questions

### **Reporting Bugs**
Please include:
- iOS version and device model
- App version and build number
- Steps to reproduce the issue
- Expected vs actual behavior
- Screenshots or screen recordings

## 🗺️ Roadmap

### **Version 2.0** 🚧
- [ ] **Apple Watch App**: Companion app with meal reminders and quick shopping lists
- [ ] **iOS Widgets**: Home screen widgets for meal plans and shopping lists  
- [ ] **Siri Shortcuts**: Voice integration for adding meals and checking plans
- [ ] **SharePlay**: Collaborative meal planning with family and friends

### **Version 2.5** 🔮
- [ ] **ARKit Integration**: Augmented reality for portion size visualization
- [ ] **Machine Learning**: On-device personalization and recommendations
- [ ] **HealthKit Integration**: Sync with Apple Health for comprehensive wellness
- [ ] **CarPlay Support**: Voice-controlled shopping lists while driving

### **Future Vision** 🌟
- [ ] **Smart Home Integration**: Connect with IoT appliances and smart kitchens
- [ ] **Grocery Delivery**: Direct integration with delivery services
- [ ] **Social Features**: Recipe sharing and community meal planning
- [ ] **Advanced AI**: Computer vision for food recognition and logging

---

**Built with ❤️ using SwiftUI and modern iOS development practices**

*MealPrep iOS App - Making meal planning effortless and enjoyable*