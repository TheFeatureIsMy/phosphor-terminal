#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::Serialize;
use sysinfo::{Networks, System};
use tauri::menu::{MenuBuilder, MenuItemBuilder, SubmenuBuilder};
use tauri::Manager;
use window_vibrancy::{apply_vibrancy, NSVisualEffectMaterial};

#[derive(Serialize)]
pub struct SystemMetrics {
    pub cpu_usage: f32,
    pub mem_usage: f32,
    pub mem_total: u64,
    pub mem_used: u64,
    pub network_rx: u64,
    pub network_tx: u64,
}

#[tauri::command]
fn get_system_metrics() -> SystemMetrics {
    let mut sys = System::new();
    sys.refresh_cpu_all();
    sys.refresh_memory();

    let cpu_usage = sys.global_cpu_usage();
    let mem_total = sys.total_memory();
    let mem_used = sys.used_memory();
    let mem_usage = if mem_total > 0 {
        (mem_used as f32 / mem_total as f32) * 100.0
    } else {
        0.0
    };

    let networks = Networks::new_with_refreshed_list();
    let mut total_rx: u64 = 0;
    let mut total_tx: u64 = 0;
    for (_name, data) in &networks {
        total_rx += data.total_received();
        total_tx += data.total_transmitted();
    }

    SystemMetrics {
        cpu_usage,
        mem_usage,
        mem_total,
        mem_used,
        network_rx: total_rx,
        network_tx: total_tx,
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            // Apply native macOS vibrancy to the window
            let window = app.get_webview_window("main").unwrap();

            #[cfg(target_os = "macos")]
            {
                let _ = apply_vibrancy(&window, NSVisualEffectMaterial::HudWindow, None, None);
            }

            // Build native macOS menu bar
            let quit = MenuItemBuilder::with_id("quit", "退出 PulseDesk")
                .accelerator("CmdOrCtrl+Q")
                .build(app)?;
            let hide = MenuItemBuilder::with_id("hide", "隐藏")
                .accelerator("CmdOrCtrl+H")
                .build(app)?;
            let hide_others = MenuItemBuilder::with_id("hide_others", "隐藏其他")
                .accelerator("CmdOrCtrl+Option+H")
                .build(app)?;
            let show = MenuItemBuilder::with_id("show", "显示全部")
                .build(app)?;
            let settings = MenuItemBuilder::with_id("settings", "设置...")
                .accelerator("CmdOrCtrl+,")
                .build(app)?;
            let fullscreen = MenuItemBuilder::with_id("fullscreen", "全屏")
                .accelerator("CmdOrCtrl+Ctrl+F")
                .build(app)?;

            let copy = MenuItemBuilder::with_id("copy", "复制")
                .accelerator("CmdOrCtrl+C")
                .build(app)?;
            let paste = MenuItemBuilder::with_id("paste", "粘贴")
                .accelerator("CmdOrCtrl+V")
                .build(app)?;
            let select_all = MenuItemBuilder::with_id("select_all", "全选")
                .accelerator("CmdOrCtrl+A")
                .build(app)?;

            let search = MenuItemBuilder::with_id("search", "搜索")
                .accelerator("CmdOrCtrl+K")
                .build(app)?;

            let reload = MenuItemBuilder::with_id("reload", "重新加载")
                .accelerator("CmdOrCtrl+R")
                .build(app)?;
            let devtools = MenuItemBuilder::with_id("devtools", "开发者工具")
                .accelerator("CmdOrCtrl+Option+I")
                .build(app)?;

            // PulseDesk menu
            let app_menu = SubmenuBuilder::new(app, "PulseDesk")
                .item(&settings)
                .separator()
                .item(&hide)
                .item(&hide_others)
                .item(&show)
                .separator()
                .item(&quit)
                .build()?;

            // Edit menu
            let edit_menu = SubmenuBuilder::new(app, "编辑")
                .item(&copy)
                .item(&paste)
                .item(&select_all)
                .build()?;

            // View menu
            let view_menu = SubmenuBuilder::new(app, "视图")
                .item(&search)
                .separator()
                .item(&fullscreen)
                .separator()
                .item(&reload)
                .item(&devtools)
                .build()?;

            let menu = MenuBuilder::new(app)
                .item(&app_menu)
                .item(&edit_menu)
                .item(&view_menu)
                .build()?;

            app.set_menu(menu)?;

            Ok(())
        })
        .on_menu_event(|app, event| {
            let id = event.id().as_ref();
            match id {
                "quit" => app.exit(0),
                "hide" => {
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.minimize();
                    }
                }
                "fullscreen" => {
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.set_fullscreen(!window.is_fullscreen().unwrap_or(false));
                    }
                }
                "reload" => {
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.eval("location.reload()");
                    }
                }
                "devtools" => {
                    // DevTools available via right-click > Inspect in dev builds
                }
                "search" => {
                    if let Some(window) = app.get_webview_window("main") {
                        let _ = window.eval("document.dispatchEvent(new KeyboardEvent('keydown', {key: 'k', metaKey: true}))");
                    }
                }
                _ => {}
            }
        })
        .invoke_handler(tauri::generate_handler![get_system_metrics])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
