# iOS App Troubleshooting Guide

## Common Issues and Solutions

### Date Parsing Errors

#### Issue: "Cannot decode date string" Error
**Error Message**: `dataCorrupted(Swift.DecodingError.Context(codingPath: [..., "week_start_date"], debugDescription: "Cannot decode date string 2025-07-21", ...))`

**Cause**: Backend returns date in different format than expected by iOS client

**Solution**: The iOS models now include flexible date parsing. If you encounter this error:

1. **Check Date Format**: Verify the backend is returning dates in expected formats:
   - Simple dates: `YYYY-MM-DD` (e.g., "2025-07-21")
   - ISO-8601 timestamps: `YYYY-MM-DDTHH:mm:ss.SSSSSZ` (e.g., "2025-07-20T08:21:52.001886Z")

2. **Update Models**: Ensure you're using the latest model versions with flexible parsing:
   - `User.swift` - Has flexible ID and date parsing
   - `MealPlan.swift` - Has flexible ID and enhanced date parsing
   - `Recipe.swift` - Has flexible ID parsing

3. **Test Date Parsing**: Use the test file to verify parsing works:
   ```bash
   swift MealPrepIOSApp/test_date_parsing.swift
   ```

#### Supported Date Formats
The iOS client supports these date formats automatically:

- **Simple Date**: `yyyy-MM-dd` (e.g., "2025-07-21")
- **ISO-8601 with Microseconds**: `yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'`
- **ISO-8601 with Milliseconds**: `yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`
- **Basic ISO-8601**: `yyyy-MM-dd'T'HH:mm:ss'Z'`

### ID Format Issues

#### Issue: ID Decoding Errors
**Error Message**: `ID must be either String or Int`

**Cause**: Backend returns ID in unexpected format

**Solution**: The iOS models now handle both String UUID and Integer ID formats:

```swift
// Flexible ID parsing handles both formats
if let idString = try? container.decode(String.self, forKey: .id) {
    id = idString  // UUID string from Django
} else if let idInt = try? container.decode(Int.self, forKey: .id) {
    id = String(idInt)  // Integer ID converted to string
}
```

### Network Issues

#### Issue: Authentication Failures
**Symptoms**: 401 Unauthorized errors, login failures

**Solutions**:
1. **Check Backend URL**: Verify `NetworkManager.swift` has correct backend URL
   ```swift
   private let baseURL = "http://127.0.0.1:8000/api"  // Development
   ```

2. **JWT Token Issues**: Clear stored tokens and re-authenticate
   ```swift
   // In AuthenticationService
   KeychainHelper.delete(key: "access_token")
   KeychainHelper.delete(key: "refresh_token")
   ```

3. **Backend Connectivity**: Ensure Django backend is running on correct port

#### Issue: Network Request Timeouts
**Solutions**:
1. **Increase Timeout**: Modify `NetworkManager.swift`
   ```swift
   request.timeoutInterval = 30.0  // Increase from default
   ```

2. **Check Backend Performance**: Monitor Django backend response times

#### Issue: Favorites Toggle Failures
**Symptoms**: Heart button fails with decoding errors, favorites functionality completely broken

**Root Cause**: Backend serializer regression removed explicit `id` field handling and `FavoriteStatusSerializer`, breaking iOS compatibility.

**Error Messages**:
1. **ID Field Error**:
```
dataCorrupted(Swift.DecodingError.Context(codingPath: [CodingKeys(stringValue: "id", intValue: nil)], debugDescription: "ID must be either String or Int", underlyingError: nil))
```

2. **Missing is_favorite Field Error**:
```
keyNotFound(CodingKeys(stringValue: "is_favorite", intValue: nil), Swift.DecodingError.Context(codingPath: [], debugDescription: "No value associated with key CodingKeys(stringValue: \"is_favorite\", intValue: nil) (\"is_favorite\").", underlyingError: nil))
```

**Current Status**: ❌ **BROKEN** - Favorites functionality is non-functional due to backend changes

**Solutions**:
1. **Backend Fix Required**: The backend needs to restore both explicit `id` field handling and `FavoriteStatusSerializer`:
   ```python
   # Restore explicit ID field in FavoriteSerializer
   class FavoriteSerializer(serializers.ModelSerializer):
       id = serializers.CharField(read_only=True)  # Add this line
       # ... other fields
       class Meta:
           fields = ['id', 'user', 'user_id', ...]  # Include 'id' in fields
   
   # Restore FavoriteStatusSerializer for proper response format
   class FavoriteStatusSerializer(serializers.Serializer):
       is_favorite = serializers.BooleanField()
       favorite = FavoriteSerializer(required=False, allow_null=True)
   ```

2. **Alternative iOS Fix**: Update iOS models to handle missing `id` field (not recommended as it breaks CRUD operations)

3. **Temporary Workaround**: Disable favorites functionality until backend is fixed

**Impact**: 
- ❌ Heart button toggle completely broken
- ❌ Users cannot add/remove recipes from favorites  
- ❌ Favorites list may not load properly
- ❌ All favorites-related functionality is non-functional

**Resolution Status**: Requires backend changes to restore compatibility

### Data Model Issues

#### Issue: Missing Fields in API Response
**Symptoms**: Optional fields showing as nil unexpectedly

**Solutions**:
1. **Check Backend Serializers**: Verify Django serializers include all expected fields
2. **Update iOS Models**: Add new fields as optional properties
3. **Handle Missing Data**: Implement proper nil handling in UI

#### Issue: User Session Not Persisting
**Symptoms**: User logged out after app restart, session data lost

**Solutions**:

1. **Check UserCacheManager**: Verify user data is being cached properly

   ```swift
   // Check if user data is cached
   let cachedUser = try await UserCacheManager().getCurrentUser()
   print("Cached user: \(cachedUser?.username ?? "nil")")
   ```

2. **Clear Cache**: Reset user cache if corrupted

   ```swift
   // Clear corrupted cache
   try await UserCacheManager().clearCurrentUser()
   ```

3. **Verify Date Parsing**: Ensure cached user data can be decoded properly
4. **Check UserDefaults**: Verify data is being stored in UserDefaults
5. **Check AuthStore Integration**: Verify AuthStore is properly loading from cache

   ```swift
   // In AuthStore
   func checkAuthenticationStatus() {
       Task {
           // First try to load from cache
           await loadCurrentUserFromCache()
           
           // Then update from server if authenticated
           if networkManager.isAuthenticated {
               await loadCurrentUser()
           }
       }
   }
   ```

#### Issue: Type Mismatch Errors
**Symptoms**: Decoding errors for specific fields

**Solutions**:
1. **Check Data Types**: Verify backend returns expected data types
2. **Add Flexible Parsing**: Implement custom decoding for problematic fields
3. **Update Model Definitions**: Match iOS model types to backend response

### UI Issues

#### Issue: Empty Lists or Missing Data
**Symptoms**: UI shows empty states when data should be present

**Solutions**:
1. **Check Network Calls**: Verify API requests are successful
2. **Debug Response Data**: Log API responses to identify issues
3. **Verify Data Binding**: Ensure SwiftUI views are properly bound to data

#### Issue: App Crashes on Data Loading
**Solutions**:
1. **Add Error Handling**: Implement proper error handling in ViewModels
2. **Use Optional Binding**: Safely unwrap optional data
3. **Add Loading States**: Show loading indicators during data fetches

## Debugging Tools

### Network Request Logging
Enable detailed logging in `NetworkManager.swift`:

```swift
// Add to NetworkManager
private func logRequest(_ request: URLRequest) {
    print("🌐 Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
    if let body = request.httpBody {
        print("📤 Body: \(String(data: body, encoding: .utf8) ?? "Unable to decode")")
    }
}

private func logResponse(_ data: Data?, _ response: URLResponse?) {
    if let httpResponse = response as? HTTPURLResponse {
        print("📥 Response: \(httpResponse.statusCode)")
    }
    if let data = data {
        print("📄 Data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
    }
}
```

### Model Parsing Testing
Test individual model parsing:

```swift
// Test User model parsing
let userJSON = """
{
    "id": "uuid-string",
    "username": "testuser",
    "email": "test@example.com",
    "created_at": "2025-07-20T08:21:52.001886Z",
    "updated_at": "2025-07-20T18:54:17.594007Z"
}
""".data(using: .utf8)!

do {
    let user = try JSONDecoder().decode(User.self, from: userJSON)
    print("✅ User parsed successfully: \(user.username)")
} catch {
    print("❌ User parsing failed: \(error)")
}
```

### Core Data Debugging
Enable Core Data debugging:

```swift
// Add to AppDelegate or App struct
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "DataModel")
    container.loadPersistentStores { _, error in
        if let error = error {
            print("❌ Core Data error: \(error)")
        }
    }
    return container
}()
```

## Performance Optimization

### Memory Management
- Use `weak` references in closures to prevent retain cycles
- Implement proper view lifecycle management
- Clear large data sets when not needed

### Data Integrity
- Recipe pagination includes duplicate prevention to ensure clean lists
- ID-based filtering prevents duplicate entries during concurrent loading
- Efficient pagination maintains performance while ensuring data consistency

### Network Optimization
- Implement request caching for frequently accessed data
- Use pagination for large data sets
- Batch multiple requests when possible

### UI Performance
- Use lazy loading for large lists
- Implement proper image caching
- Optimize SwiftUI view updates

## Getting Help

### Log Collection
When reporting issues, include:

1. **Error Messages**: Full error text and stack traces
2. **Network Logs**: Request/response details
3. **Device Info**: iOS version, device model
4. **Backend Info**: Django version, API endpoint details

### Common Log Locations
- **Xcode Console**: Runtime errors and print statements
- **Device Console**: System-level errors (in Xcode > Window > Devices and Simulators)
- **Network Inspector**: HTTP request/response details

### Useful Debugging Commands
```bash
# Check backend connectivity
curl -X GET http://127.0.0.1:8000/api/auth/me/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test date parsing in Swift
swift -e "
import Foundation
let formatter = DateFormatter()
formatter.dateFormat = \"yyyy-MM-dd\"
print(formatter.date(from: \"2025-07-21\") ?? \"Failed\")
"
```

This troubleshooting guide should help resolve most common issues encountered when using the iOS app with the Django backend.