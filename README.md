# MealPrepIOSApp

Native iOS client for the MealPrepAI application, providing a seamless mobile experience for AI-powered meal planning.

## Features

- **Native iOS Experience**: Built with SwiftUI for iOS 15+ compatibility
- **AI-Powered Meal Planning**: Generate personalized weekly meal plans (primary feature - default tab)
- **Recipe Management**: Browse, create, and manage recipes
- **Favorites System**: Save and organize favorite recipes
- **Offline Support**: Core Data integration for offline functionality
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
- `FavoritesService`: User favorites handling
- `NetworkManager`: Centralized HTTP client with JWT handling

#### Utilities Layer
- `UserCacheManager`: Local user data caching and session persistence

#### Data Models
- `User`: User profile with flexible ID parsing
- `Recipe`: Recipe data with ingredients and nutrition
- `MealPlan`: Weekly meal plan structure
- `Favorite`: User favorite recipes

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
│   │   └── Favorite.swift   # Favorites model
│   ├── Services/            # API services
│   │   ├── NetworkManager.swift      # HTTP client
│   │   ├── AuthenticationService.swift
│   │   ├── RecipeService.swift
│   │   ├── MealPlanService.swift
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
- Manual recipe assignment with streamlined workflow:
  - Quick meal addition with default serving size (1.0)
  - Simplified one-tap meal selection process
  - Categorized recipe browsing (Search, Recent, Favorites, AI Picks)
  - Custom meal creation option
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

### User Session Caching
- `UserCacheManager`: Local user data persistence using UserDefaults
- Automatic session restoration across app launches
- Consistent date parsing matching NetworkManager
- Secure local storage for user profile data
- Cache-first authentication approach for offline access
- Seamless integration with AuthStore for state management
- Proper cache cleanup during logout operations

### Core Data Integration (Planned)
- Offline recipe caching
- User preference storage
- Meal plan synchronization
- Favorites management

### Sync Strategy
- Online-first approach with local user caching
- Offline fallback for cached user data
- Background sync when connectivity restored
- Conflict resolution for concurrent edits

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

### Debug Tools
- Network request logging in NetworkManager
- Core Data debugging
- Console logging for API responses
- Xcode debugging tools

## License

This project is part of the MealPrepAI application suite.