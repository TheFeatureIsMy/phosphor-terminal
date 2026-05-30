# Phase 5: 全局打磨 Implementation Plan

**Goal:** Add toast notifications, integrate ErrorHandler into ViewModels, add keyboard shortcuts, and polish the overall app experience.

---

## Task 1: Toast Notification System

**Files:**
- Create: `macos-app/PulseDesk/Views/Shared/ToastOverlayView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

Create a toast overlay that shows success/error/warning/info messages at the top of the screen.

---

## Task 2: Integrate ErrorHandler into ViewModels

**Files:**
- Modify: `macos-app/PulseDesk/ViewModels/DashboardViewModel.swift`
- Modify: `macos-app/PulseDesk/ViewModels/StrategiesViewModel.swift`
- Modify: `macos-app/PulseDesk/ViewModels/BacktestViewModel.swift`

Add `@Environment(ErrorHandler.self)` usage pattern — ViewModels pass errors to ErrorHandler instead of storing them locally.

---

## Task 3: Keyboard Shortcuts

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/SidebarView.swift`

Add Cmd+N (new strategy), Cmd+R (refresh), Cmd+, (settings), Cmd+1-9 (page switch).

---

## Task 4: Empty State Polish

**Files:**
- Modify: Various view files to ensure consistent empty states

Verify all pages have proper EmptyStateView usage.

---

## Task 5: Build Verification

Run `swift build` and `pytest`.
