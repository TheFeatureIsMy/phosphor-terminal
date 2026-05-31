# Batch B: Shell + Navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development

**Goal:** Apply Batch A design system primitives to shell/navigation views, fix audit findings, extract shared components.

**Architecture:** Use new `LoadingView(type:)` and `ProofAlphaCard(emphasis:)` from Batch A. Extract `NavRowView` from the duplicated `SidebarButtonView` + `SettingsNavRowView`. Add keyboard navigation, empty states, and entrance animations.

**Tech Stack:** SwiftUI, macOS 14+, ProofAlpha design tokens

---

### Task 1: AppShellView — replace ProgressView with LoadingView, add hover/help

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

**Changes:**
1. Replace all `ProgressView("加载中...")` instances with `LoadingView(type: .detail)`
2. Add `.help()` to search and notification buttons
3. Add hover opacity transition to toolbar buttons

- [ ] Read file
- [ ] Find and replace `ProgressView("加载中...")` → `LoadingView(type: .detail)` (3 occurrences in detailContent switch)
- [ ] On search Button, add `.help("搜索 (⌘K)")`
- [ ] On notification Button, add `.help("通知")`
- [ ] Build: `cd macos-app && swift build 2>&1 | tail -5`
- [ ] Commit: `feat(shell): use LoadingView placeholder, add tooltips to toolbar`

---

### Task 2: SidebarView — drive footer from ViewModel, clean up collapsed dividers

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/SidebarView.swift`

**Changes:**
1. Footer status text: replace hardcoded "系统运行中"/"Freqtrade 已连接" with properties from a SystemStatus source (accept optional binding from AppShell)
2. In collapsed mode: emit a single Divider before the section loop instead of one per section
3. In the collapsed mode ForEach, when `appState.sidebarCollapsed`, break out of the ForEach after first Divider (use enumerated + first only)

- [ ] Read file
- [ ] In collapsed ForEach: wrap the Divider in `if index == 0` (only show one before first section)
- [ ] Build: `cd macos-app && swift build 2>&1 | tail -5`
- [ ] Commit: `fix(sidebar): single divider in collapsed mode`

---

### Task 3: CommandPaletteView — empty state, ScrollViewReader, entrance animation, shared row

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/CommandPaletteView.swift`

**Changes:**
1. Add empty state when both filteredRoutes and searchResults are empty (show muted text "无匹配结果")
2. Wrap ScrollView in `ScrollViewReader` + `.scrollTo(selectedIndex)` on key press
3. Add entrance animation to the panel: `.transition(.scale(scale: 0.95).combined(with: .opacity))`
4. Extract `resultRow` and `strategyRow` into shared `CommandPaletteRow` view to remove ~90% code duplication

The shared `CommandPaletteRow`:
```swift
private struct CommandPaletteRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? PulseColors.accent : colors.textSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PulseFonts.bodyMedium)
                        .foregroundStyle(colors.textPrimary)
                    Text(subtitle)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
                Spacer()
                if isSelected {
                    Text("Enter").font(PulseFonts.monoLabel).foregroundStyle(colors.textMuted)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(colors.surfaceHover))
                }
            }
            .padding(.vertical, PulseSpacing.xs).padding(.horizontal, PulseSpacing.xs)
            .background(RoundedRectangle(cornerRadius: PulseRadii.md)
                .fill(isSelected ? PulseColors.accent.opacity(0.1) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] Read file
- [ ] Extract shared CommandPaletteRow
- [ ] Wrap ScrollView in ScrollViewReader, scroll to selectedIndex on up/down key
- [ ] Add empty state when no results
- [ ] Add entrance animation on panel
- [ ] Build: `cd macos-app && swift build 2>&1 | tail -5`
- [ ] Commit: `feat(palette): add empty state, keyboard scroll, entrance animation, deduplicate rows`

---

### Task 4: SettingsView — extract shared NavRowView, keyboard shortcuts

**Files:**
- Modify: `macos-app/PulseDesk/Views/Settings/SettingsView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/SidebarView.swift` (minor — SidebarButtonView remains but uses same pattern)

**Changes:**
1. Replace `selectedSection: Int` with a proper enum for type safety (optional — can defer)
2. Add `Command+[1-6]` keyboard shortcuts for section navigation
3. Add `onChange(of: selectedSection)` to print or update state

Skip the NavRowView extraction for now — SidebarButtonView and SettingsNavRowView are visually identical but differ in data model (AppRoute vs Int index). The extraction requires a generic wrapper that's more complex than warranted. Note this as debt.

- [ ] Read file
- [ ] Add keyboard shortcut buttons (simple approach: use `.keyboardShortcut` on hidden buttons)
- [ ] Build and commit

---

### Task 5: APISettingsView — tappable cards, chevrons, TerminalLabel

**Files:**
- Modify: `macos-app/PulseDesk/Views/Settings/APISettingsView.swift`

**Changes:**
1. Replace section heading "API 密钥" plain text with `TerminalLabel(text: "API 密钥")`
2. Each row: add chevron `Image(systemName: "chevron.right")` to hint tappability
3. Add `.onTapGesture` or wrap in Button to show an edit sheet (stub sheet for now)

- [ ] Read file
- [ ] Wrap heading in `TerminalLabel(text: "API 密钥")`
- [ ] Add chevron to each apiRow
- [ ] Add stub edit sheet (just Text("配置 \(name)"))
- [ ] Build and commit

---

### Task 6: RiskSettingsView — validation, Slider, reset button, grouping

**Files:**
- Modify: `macos-app/PulseDesk/Views/Settings/RiskSettingsView.swift`

**Changes:**
1. Add validation: highlight out-of-range fields with accent red border
2. Add `Slider` alternative for percentage fields (0-100 range) next to text field
3. Add "恢复默认" reset button at bottom
4. Group parameters with dividers: loss params | position params | correlation params

- [ ] Read file
- [ ] Add Divider between param groups
- [ ] Add Slider for each numRow (percentage fields)
- [ ] Add reset button
- [ ] Add basic validation (red highlight if value > 100 or < 0 for percentage fields)
- [ ] Build and commit

---

### Task 7: ProfileSettingsView — editable fields, avatar

**Files:**
- Modify: `macos-app/PulseDesk/Views/Settings/ProfileSettingsView.swift`

**Changes:**
1. Make name and email editable with TextField + save button
2. Add avatar circle at top
3. Add fields: timezone, 2FA status

- [ ] Read file
- [ ] Add avatar circle with initials
- [ ] Replace Text display with TextField for name/email
- [ ] Add save button with simple state management
- [ ] Build and commit

---

### Task 8: Build verification

- [ ] Clean build
- [ ] Backend test regression
- [ ] Commit any remaining changes
