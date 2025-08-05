# Onboarding Implementation

## Overview
The onboarding flow has been implemented with an intelligent, adaptive system that only shows the necessary steps to users based on their current state.

## Implementation Details

### 1. **OnboardingContainerView**
- Main container that orchestrates the onboarding flow
- Intelligently determines which steps are needed based on:
  - User's first/last name completion status
  - Household membership status
- Steps flow seamlessly without unnecessary friction

### 2. **UserInfoView**
- Collects user's first and last name
- Pre-fills existing data if available
- Simple, clean UI with clear instructions
- Currently proceeds without saving (awaiting UpdateUser mutation)

### 3. **HouseholdCreationView**
- Updated for onboarding-specific experience
- Streamlined UI without back button during onboarding
- Clear explanation of household purpose
- Admin role information provided upfront

### 4. **AppState Integration**
- Updated `needsOnboarding` detection to check both:
  - Missing user information (firstName/lastName)
  - No household membership
- Proper hydration flow integration

## Onboarding Flow Logic

1. **User with complete info + household**: Skip onboarding entirely
2. **User missing name info**: Show UserInfoView → Check household → Complete or create
3. **User with name but no household**: Skip to HouseholdCreationView
4. **Invited user without name**: Show UserInfoView → Complete (already in household)

## Key Features

- **Adaptive Flow**: Only shows necessary steps
- **Seamless Transitions**: Smooth animations between steps
- **Loading States**: Clear feedback during async operations
- **Error Handling**: User-friendly error messages
- **Accessibility**: Proper text field types and labels

## Pending Backend Work

### UpdateUser Mutation Required
The backend needs to implement an UpdateUser mutation for saving user profile information:

```graphql
mutation UpdateUser($input: UpdateUserInput!) {
  updateUser(input: $input) {
    id
    first_name
    last_name
    # ... other user fields
  }
}
```

See `TODO_UpdateUserMutation.md` for full details.

## Testing Scenarios

1. **New user signup**: Should see both UserInfo and HouseholdCreation steps
2. **Invited user with incomplete profile**: Should only see UserInfo step
3. **User with complete profile but no household**: Should only see HouseholdCreation
4. **Returning user with everything**: Should skip onboarding entirely

## UI Components Created

- **PantryTextFieldStyle**: Consistent text field styling
- **PantryPrimaryButtonStyle**: Primary button styling for CTAs
- Proper use of DesignTokens throughout