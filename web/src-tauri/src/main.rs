// AlphaLoop Tauri shell — React 前端 + 本地 BFF(8000)
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running AlphaLoop");
}
