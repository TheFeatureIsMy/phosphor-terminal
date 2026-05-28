import { create } from 'zustand'

interface AppState {
  sidebarCollapsed: boolean
  sidebarPinned: boolean
  toggleSidebar: () => void
  setSidebarCollapsed: (collapsed: boolean) => void
  toggleSidebarPinned: () => void
  setSidebarPinned: (pinned: boolean) => void
}

export const useAppStore = create<AppState>((set) => ({
  sidebarCollapsed: false,
  sidebarPinned: true,
  toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
  setSidebarCollapsed: (collapsed) => set({ sidebarCollapsed: collapsed }),
  toggleSidebarPinned: () => set((s) => ({ sidebarPinned: !s.sidebarPinned })),
  setSidebarPinned: (pinned) => set({ sidebarPinned: pinned }),
}))
