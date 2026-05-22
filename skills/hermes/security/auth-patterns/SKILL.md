---
name: auth-patterns
description: auth-patterns Skill
---

# auth-patterns Skill

## Purpose
Implement secure authentication with OAuth readiness.

## JWT Implementation

### Access Token
- Short-lived: 15 minutes
- Contains: userId, tenantId, roles
- Signed with HS256/RS256

### Refresh Token
- Long-lived: 7 days
- Stored in database
- Rotated on use

### Token Payload
```typescript
interface JWTPayload {
  sub: string;           // userId
  tenantId: string;
  roles: string[];
  iat: number;
  exp: number;
}
```

## Authentication Flow

### Login
1. Validate credentials
2. Generate access + refresh tokens
3. Store refresh token
4. Return tokens

### Token Refresh
1. Receive expired access + valid refresh
2. Validate refresh token
3. Generate new access token
4. Rotate refresh token

### Logout
1. Invalidate refresh token
2. Clear client storage

## Password Security
- bcrypt hashing (cost factor 12)
- Password requirements: 8+ chars
- Rate limiting on login

## OAuth Readiness
- Passport.js strategy pattern
- Google, GitHub providers ready
- Token exchange standard

## Skills Used
- system-design
- rbac-design
- scalable-api
## Quick Commands
- `skill-load auth-patterns` — Load this skill
