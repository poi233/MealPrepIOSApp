# MealPrepIOSApp

Native iOS client for the MealPrepAI application, providing a seamless mobile experience for AI-powered meal planning.

## Features

- **Native iOS Experience**: Built with SwiftUI for iOS 15+ compatibility
- **AI-Powered Meal Planning**: Generate personalized weekly meal plans (primary feature - default tab)
- **Recipe Management**: Browse, create, and manage recipes
- **Favorites System**: Save and organize favorite recipes
- **Offline Support**: ⚠️ Temporarily disabled - Core Data integration planned for future implementation
- **Robust API Integration**: Flexible parsing with resilient ID handling for backend compatibility

## Architecture

### MVVM Pattern
- **Models**: Data structures matching backend API contracts
- **Views**: SwiftUI views for user interface
- **ViewModels**: ObservableObject stores for state management
- **Services**: API communication and business logic

### Key Components

#### Services Layer
- `AuthenticationService`: User authentication and profile management
- `RecipeService`: Recipe CRUD operations
- `MealPlanService`: Meal plan management
- `MealPlanTemplateService`: Template creation and management with duplicate filtering
- `FavoritesService`: User favorites handling
- `LocalMealPlanStorage`: File-based meal plan persistence with multi-week support
- `NetworkManager`: Centralized HTTP client with JWT handling

#### Utilities Layer
- `UserCacheManager`: Local user data caching and session persistence
- `RecipeCacheManager`: ⚠️ Not implemented - Recipe caching temporarily disabled

#### Data Models
- `User`: User profile with flexible ID parsing
- `Recipe`: Recipe data with ingredients and nutrition
- `MealPlan`: Weekly meal plan structure
- `Favorite`: User favorite recipes

#### Shared Enums
- `MealType`: Breakfast, lunch, dinner meal categories
- `Difficulty`: Recipe difficulty levels (easy, medium, hard)
- `AnalysisType`: Meal plan analysis types (nutrition, variety, balance, full)
- `BudgetLevel`: Budget categories for meal planning
- `WeekDirection`: Week navigation directions (previous, current, next)

#### Stores (ViewModels)
- `AuthStore`: Authentication state management
- `RecipeStore`: Recipe data and operations
- `MealPlanStore`: Meal plan state
- `FavoritesStore`: Favorites management
- `UserProfileStore`: User profile data

## API Compatibility

### Flexible Data Parsing
The iOS client implements robust parsing to handle backend API variations:

#### User Model Flexibility
```swift
// Handles both String UUID and Integer ID formats
if let idString = try? container.decode(String.self, forKey: .id) {
    id = idString
} else if let idInt = try? container.decode(Int.self, forKey: .id) {
    id = String(idInt)
}
```

#### Date Handling
- Flexible ISO-8601 date parsing for `created_at` and `updated_at` fields
- Automatic timezone handling

#### Ingredient Amount Parsing
- Flexible parsing for ingredient amounts (String, Double, or Int)
- Consistent String representation for UI display
- Handles backend variations in numeric data formats
- **AI Integration v2.0 Support**: Parses new AI-generated ingredient format `{name: "鸡胸肉", amount: "150克"}` and stores the complete amount string with unit field left empty for simplified handling
- **Multi-Format Support**: Handles structured objects, AI format, and legacy string arrays seamlessly

#### Nutrition Data Parsing
- Optimized flexible parsing prioritizing numeric types (Double, Int) over String
- Enhanced servings field supports both whole and fractional serving sizes
- Consistent String representation for nutrition display in UI
- Improved parsing performance for common API response formats
- Robust handling of nutrition field data type variations (String/Double conversion)
- Internal property naming uses descriptive names (e.g., `carbohydrates`) while maintaining API compatibility with backend field names (e.g., "carbs")

#### Error Handling
- Descriptive error messages for debugging
- Graceful fallbacks for missing optional data
- Resilient ID handling with temporary ID generation for missing fields

#### Custom Serialization Control
- Bidirectional encoding/decoding control for API communication
- Conditional field encoding to optimize request payloads
- Consistent data format handling across different backend response variations

### Backend Integration
- **Primary Backend**: Django REST API at `http://127.0.0.1:8000` (development)
- **Production**: `meal-prep-app-backend.vercel.app`
- **Authentication**: JWT tokens with automatic refresh
- **Data Format**: JSON with UUID strings for IDs
- **AI Integration**: Full compatibility with AI Integration v2.0 including structured ingredient parsing
- **Recipe Generation**: Simplified request format using only recipe name for AI-powered recipe generation

## Development Setup

### Prerequisites
- Xcode 15.0+
- iOS 15.0+ deployment target
- Swift 5.9+

### Installation
1. Clone the repository
2. Open `MealPrepIOSApp.xcodeproj` in Xcode
3. Configure backend URL in `NetworkManager.swift`
4. Build and run on simulator or device

### Configuration
Update `NetworkManager.swift` with appropriate backend URLs:
```swift
private let baseURL = "http://127.0.0.1:8000/api"  // Development
// private let baseURL = "https://meal-prep-app-backend.vercel.app/api"  // Production
```

## Testing

### Unit Tests
- Model parsing and validation
- Service layer functionality
- Store state management
- Error handling scenarios

### API Contract Tests
- Backend response compatibility
- Data model parsing
- Authentication flow
- Error response handling

### UI Tests
- User authentication flows
- Recipe management
- Meal plan creation
- Favorites functionality

Run tests in Xcode:
```bash
# Unit tests
⌘+U in Xcode

# Specific test suites
xcodebuild test -scheme MealPrepIOSApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Project Structure

```
MealPrepIOSApp/
├── MealPrepIOSApp/
│   ├── Models/              # Data models
│   │   ├── User.swift       # User model with flexible parsing
│   │   ├── Recipe.swift     # Recipe data structure
│   │   ├── MealPlan.swift   # Meal plan models
│   │   ├── Favorite.swift   # Favorites model
│   │   └── SharedEnums.swift # Shared enums and types
│   ├── Services/            # API services
│   │   ├── NetworkManager.swift      # HTTP client
│   │   ├── AuthenticationService.swift
│   │   ├── RecipeService.swift
│   │   ├── MealPlanService.swift
│   │   ├── MealPlanTemplateService.swift  # Template management with duplicate filtering
│   │   ├── LocalMealPlanStorage.swift     # File-based meal plan persistence
│   │   └── FavoritesService.swift
│   ├── Stores/              # ViewModels
│   │   ├── AuthStore.swift
│   │   ├── RecipeStore.swift
│   │   ├── MealPlanStore.swift
│   │   └── FavoritesStore.swift
│   ├── Views/               # SwiftUI views
│   │   ├── LoginView.swift
│   │   ├── RecipesView.swift
│   │   ├── MealPlanView.swift
│   │   ├── MealPlan/        # Meal planning components
│   │   │   ├── ServingAdjustmentSheet.swift  # Serving size adjustment UI (post-addition)
│   │   │   ├── BatchOperationsSheet.swift
│   │   │   ├── MealActionSheet.swift
│   │   │   └── MealSelectionBottomSheet.swift  # Streamlined meal selection UI
│   │   ├── FavoritesView.swift
│   │   ├── FavoriteDetailView.swift
│   │   └── EditFavoriteView.swift
│   ├── Components/          # Reusable UI components
│   ├── Utils/               # Utilities and extensions
│   │   └── UserCacheManager.swift  # User data caching
│   └── Data/                # Core Data stack
├── MealPrepIOSAppTests/     # Unit tests
└── MealPrepIOSAppUITests/   # UI tests
```

## Key Features Implementation

### Meal Planning (Primary Feature - Default Tab)
- **User Experience Priority**: Meal planning is the first screen users see when opening the app
- Weekly meal plan generation
- **Template Management**: Save and apply meal plan templates with robust duplicate filtering and auto-fill functionality for seamless template selection
- Manual recipe assignment with streamlined workflow:
  - Quick meal addition with default serving size (1.0)
  - Simplified one-tap meal selection process
  - Categorized recipe browsing (Search, Recent, Favorites, AI Picks)
  - Custom meal creation option
  - **Duplicate Prevention**: Intelligent duplicate recipe detection prevents adding the same recipe to the same day and meal type combination, with user-friendly error messaging
- **Advanced Serving Size Adjustment** (available after meal addition): 
  - Interactive serving size selection with predefined options (½, 1, 1½, 2, 2½, 3 servings)
  - Custom serving size input with decimal precision and validation
  - Real-time nutrition calculation and preview for adjusted portions
  - Visual feedback with animated selection states and gradient backgrounds
  - Fine-tuning controls with stepper for precise adjustments
  - Recipe information display with image, description, and cooking time
- Meal plan analysis
- Shopping list generation

### Authentication
- JWT token management with automatic refresh
- Secure token storage in Keychain
- User profile management
- Password change functionality
- Offline authentication with UserCacheManager
- Form validation with comprehensive error handling
- Session persistence across app launches

### Recipe Management
- Browse recipe catalog
- Create custom recipes
- AI-generated recipe details
- Recipe search and filtering

### Favorites System
- Save favorite recipes with personal ratings (1-5 stars) and notes
- Comprehensive favorite detail view with recipe information
- Edit ratings and notes for saved favorites
- Quick access to full recipe details from favorites
- Remove recipes from favorites with confirmation
- View favorite metadata (when added, recipe author)
- Display recipe tags and nutritional information
- Simplified architecture using recipe ID as the favorite identifier
- Organize favorites collections (planned feature)

## Data Persistence

### Multi-Tier Storage Architecture
The iOS app implements a sophisticated multi-tier storage system optimized for different data types:

#### User Session Caching
- `UserCacheManager`: Local user data persistence using UserDefaults
- Automatic session restoration across app launches
- Consistent date parsing matching NetworkManager
- Secure local storage for user profile data
- Cache-first authentication approach for offline access
- Seamless integration with AuthStore for state management
- Proper cache cleanup during logout operations

#### Meal Plan File-Based Storage
- `LocalMealPlanStorage`: Hybrid file-based + UserDefaults storage system
- **Primary Storage**: JSON files in Documents/MealPlans directory
- **Backup Storage**: UserDefaults for redundancy and migration
- **Multi-Week Support**: Independent storage for up to 6 weeks of meal plans
- **Automatic Cleanup**: Intelligent storage management prevents unlimited growth
- **File Protection**: Uses `.completeFileProtection` for enhanced security
- **Atomic Operations**: Ensures data integrity during save operations
- **Legacy Migration**: Seamless migration from UserDefaults-only storage
- **Error Recovery**: Robust retry logic with fallback mechanisms

#### Storage Directory Structure
```
Documents/
└── MealPlans/
    ├── 2025-07-14.json    # Week starting July 14, 2025
    ├── 2025-07-21.json    # Week starting July 21, 2025
    └── 2025-07-28.json    # Week starting July 28, 2025
```

#### Core Data Integration (Planned)
- ⚠️ **Recipe Caching**: Temporarily disabled due to implementation issues
- Offline recipe caching (planned)
- User preference storage
- Favorites management
- Advanced search indexing

### Sync Strategy
- Online-first approach with intelligent local caching
- **User Data**: UserDefaults-based caching for session persistence
- **Meal Plans**: File-based storage with UserDefaults backup
- **Recipes**: ⚠️ No caching currently - always fetches from server (Core Data integration planned)
- Background sync when connectivity restored
- Conflict resolution for concurrent edits
- Automatic data migration between storage tiers

## Storage Implementation Details

### File-Based Meal Plan Storage
The `LocalMealPlanStorage` service implements a robust file-based storage system for meal plans:

#### Key Features
- **Week-Specific Storage**: Each week's meal plan is stored in a separate JSON file
- **Atomic Operations**: File writes use atomic operations to prevent data corruption
- **Retry Logic**: Automatic retry with exponential backoff for failed operations
- **Enhanced Data Verification**: Comprehensive integrity checks with proper date handling consistency
- **Automatic Cleanup**: Maintains only the most recent 6 weeks of data
- **Backward Compatibility**: Seamless migration from legacy UserDefaults storage

#### Storage Methods
```swift
// Save meal plan for specific week
func saveWeeklyMealPlan(for weekStartDate: Date, _ weeklyGrid: WeeklyMealGrid) -> Result<Void, LocalStorageError>

// Load meal plan for specific week
func loadWeeklyMealPlan(for weekStartDate: Date) -> WeeklyMealGrid?

// Clear meal plan for specific week
func clearMealPlan(for weekStartDate: Date)
```

#### Error Handling
- Custom `LocalStorageError` enum for specific error types
- Comprehensive logging for debugging and monitoring
- Graceful fallback to UserDefaults backup when file operations fail
- Automatic recovery from corrupted data
- Enhanced verification with consistent date handling between encoding and decoding

## Performance Considerations

### Network Optimization
- Request batching for efficiency
- Image caching for recipes
- Pagination for large datasets
- Background refresh for updated data

### Memory Management
- Lazy loading for large lists
- Image memory management
- Proper view lifecycle handling
- Store cleanup on logout

### Storage Optimization
- JSON file compression for reduced disk usage
- Intelligent caching with automatic cleanup
- File protection for enhanced security
- Optimized read/write operations with retry logic

## Security

### Data Protection
- JWT token secure storage
- API request encryption (HTTPS)
- User data privacy compliance
- Secure authentication flows

### Error Handling
- Network error recovery
- Authentication error handling
- Data validation errors
- User-friendly error messages

## Deployment

### App Store Preparation
1. Update version numbers
2. Configure release signing
3. Generate app icons and screenshots
4. Submit for App Store review

### TestFlight Distribution
1. Archive release build
2. Upload to App Store Connect
3. Configure TestFlight testing
4. Distribute to beta testers

## Contributing

### Code Standards
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Implement proper error handling
- Write comprehensive tests

### Pull Request Process
1. Create feature branch
2. Implement changes with tests
3. Update documentation
4. Submit pull request with description

## Troubleshooting

### Common Issues
- **Network connectivity**: Check backend URL configuration
- **Authentication failures**: Verify JWT token handling
- **Data parsing errors**: Check API contract compatibility
- **Build errors**: Ensure Xcode version compatibility
- **Recipe loading issues**: ⚠️ Recipe caching is disabled - requires network connection

### Debug Tools
- Network request logging in NetworkManager
- Core Data debugging
- Console logging for API responses
- Xcode debugging tools
- **StorageDebugHelper**: Enhanced debugging utilities including:
  - Week storage analysis and validation (`debugStoredWeeksAndDates()`)
  - Invalid week cleanup functionality (`cleanupInvalidWeeks()`)
  - Date calculation debugging
  - Storage integrity verification

## License

This project is part of the MealPrepAI application suite.