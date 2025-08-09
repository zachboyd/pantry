# CASLSwift Permission JSON Format

## Overview

This document defines the standard JSON format for permissions in CASLSwift. This format **exactly matches** CASL's JavaScript RawRule implementation to ensure compatibility between backend and frontend.

CASLSwift supports both the standard object format and the CASL shorthand array format for permissions.

## Permission Structure (CASL RawRule Format)

### Single Permission

```json
{
  "action": "update",
  "subject": "Article",
  "conditions": {
    "authorId": "${userId}"
  },
  "inverted": true,
  "fields": ["title", "content"],
  "reason": "Users can update their own articles"
}
```

### Fields (Matching CASL's RawRule Interface)

- **action** (required): String or array of strings representing the action(s) (e.g., "create", ["read", "update"], "manage")
- **subject** (optional): String or array of strings representing the subject type(s) (e.g., "Article", ["Post", "Comment"], "all"). Optional for claim-based rules
- **conditions** (optional): Object containing MongoDB-style conditions that must be met
- **inverted** (optional): Boolean indicating if this is a denial rule (only included when true)
- **fields** (optional): String or array of strings specifying field names this permission applies to
- **reason** (optional): String explaining why this permission exists (for debugging/audit)

**Note**: Priority is NOT part of the JSON format - it's only used internally by CASL

### Permission Array

Permissions are typically transmitted as an array:

```json
[
  {
    "action": "read",
    "subject": "Post"
  },
  {
    "action": "manage",
    "subject": "Post",
    "conditions": {
      "authorId": "${userId}"
    }
  },
  {
    "action": "delete",
    "subject": "Comment",
    "inverted": true,
    "conditions": {
      "protected": true
    }
  }
]
```

### Examples of Array Actions/Subjects

```json
[
  {
    "action": ["read", "update"],
    "subject": "Post",
    "conditions": {
      "authorId": "${userId}"
    }
  },
  {
    "action": "manage",
    "subject": ["Post", "Comment"],
    "conditions": {
      "blogId": "${blogId}"
    }
  }
]
```

### CASL Shorthand Array Format

CASLSwift also supports the CASL shorthand array format where each permission is represented as an array:

```json
[
  ["read", "Post"],
  ["update", "Post", { "authorId": "${userId}" }],
  ["manage", "Comment", { "postId": 123 }],
  ["delete", "User", { "role": "admin" }]
]
```

The array elements are:
1. **action** (required): The action string
2. **subject** (required): The subject type string  
3. **conditions** (optional): Object with MongoDB-style conditions

This format is commonly used by CASL backends for more compact representation.

### Claim-Based Rules (No Subject)

```json
[
  {
    "action": "moderate"
  },
  {
    "action": ["invite", "ban"],
    "inverted": true,
    "reason": "Cannot invite or ban users"
  }
]
```

### Permission Set with Metadata

For versioning and additional context:

```json
{
  "version": "1.0",
  "permissions": [
    {
      "action": "read",
      "subject": "Post"
    },
    {
      "action": "manage",
      "subject": "Post",
      "conditions": {
        "authorId": "${userId}"
      }
    }
  ],
  "metadata": {
    "generated": "2024-01-20T10:00:00Z",
    "source": "backend-api",
    "userId": "user123"
  }
}
```

### Field-Level Permissions

Fields can be specified as a single string or array:

```json
[
  {
    "action": "read",
    "subject": "User",
    "fields": "email"
  },
  {
    "action": "update", 
    "subject": "User",
    "fields": ["firstName", "lastName", "bio"]
  }
]
```

## Condition Operators

Conditions support MongoDB-style operators:

### Comparison Operators
- `$eq`: Equals
- `$ne`: Not equals
- `$gt`: Greater than
- `$gte`: Greater than or equal
- `$lt`: Less than
- `$lte`: Less than or equal

### Array Operators
- `$in`: Value is in array
- `$nin`: Value is not in array

### Existence Operators
- `$exists`: Field exists (true/false)

### String Operators
- `$regex`: Regular expression match

### Logical Operators
- `$and`: All conditions must be true
- `$or`: At least one condition must be true
- `$not`: Inverts the condition

### Example with Operators

```json
{
  "action": "update",
  "subject": "Article",
  "conditions": {
    "$or": [
      { "authorId": "${userId}" },
      { "collaborators": { "$in": ["${userId}"] } }
    ],
    "status": { "$ne": "archived" }
  }
}
```

## Variable Substitution

Conditions can include variables that are substituted at runtime:

- `${userId}`: Current user's ID
- `${organizationId}`: Current organization ID
- `${now}`: Current timestamp
- Custom variables as defined by the application

## Special Actions

- **manage**: Grants all permissions (create, read, update, delete)
- **all**: Alias for "manage"

## Special Subjects

- **all**: Applies to all subject types
- **any**: Alias for "all"

## Version History

### Version 1.0
- Initial format definition
- Support for basic CRUD operations
- MongoDB-style conditions
- Field-level permissions
- Priority-based rule evaluation