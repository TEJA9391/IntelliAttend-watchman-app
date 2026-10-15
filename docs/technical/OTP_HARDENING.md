# Technical Documentation: Hardened OTP System

## Overview
The IntelliAttend OTP system has been hardened to ensure zero-trust, idempotent, and rate-limited session management. The primary goal was to eliminate "zombie timers" (automated background polling) and strictly enforce a "Manual Trigger Only" pattern.

## Architecture

### 1. Manual Trigger Enforcement
The application strictly avoids automated background API requests for OTP rotation. 
- **Trigger Points**: 
  - Initial session start via the "Slide to Start" slider.
  - Manual "Regenerate Code" button available ONLY after the current code expires.

### 2. Zombie Timer Elimination
- **SmartBoardController**: Removed the `Timer.periodic` loop that automatically triggered `refreshOtp()`. The timer now correctly stops at zero and waits for user action.
- **AttendanceCodeScreen**: UI timers are used solely for local countdown visualization and are explicitly cancelled when they reach zero.

### 3. Visual Expiration & UX
- When the 30-second countdown reaches zero, the UI provides immediate feedback:
  - The OTP code is replaced with a **"CODE EXPIRED"** label.
  - The screen layout greys out or darkens to indicate a "Dead" state.
  - The "Regenerate" button transitions from a disabled (waiting) state to an active (actionable) state.

### 4. Server-Side Sync & Rate Limiting (429)
The app is designed to work in tandem with the server's strict rate-limiting shield.
- **429 Handling**: The app explicitly catches HTTP 429 (Too Many Requests) errors.
- **Feedback**: Displays a specialized yellow SnackBar informing the user that they must wait a few seconds before another refresh is allowed.

## Status: VERIFIED
The OTP system, including fetching, rotation, and expiration logic, is fully operational and production-hardened.
