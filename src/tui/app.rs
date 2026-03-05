//! TUI 应用主循环

use std::io;
use std::time::Duration;

use crossterm::event::{self, Event, KeyCode};
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use crossterm::ExecutableCommand;
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

use super::state::SharedUiState;
use super::ui;

/// 运行 TUI 主循环 (在 main thread)
///
/// 10fps 刷新, q 退出。仿真完成 (state.done) 后等待按键。
pub fn run_tui(ui_state: SharedUiState) -> io::Result<()> {
    // 初始化终端
    enable_raw_mode()?;
    io::stdout().execute(EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(io::stdout());
    let mut terminal = Terminal::new(backend)?;

    loop {
        // 渲染
        {
            let state = ui_state.lock().unwrap();
            terminal.draw(|f| ui::draw(f, &state))?;
        }

        // 处理键盘事件 (100ms 超时 = 10fps)
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    _ => {}
                }
            }
        }

        // 检查仿真是否完成
        let done = {
            let state = ui_state.lock().unwrap();
            state.done
        };

        if done {
            // 最终渲染一次, 然后等待用户按 q
            {
                let state = ui_state.lock().unwrap();
                terminal.draw(|f| ui::draw(f, &state))?;
            }
            loop {
                if let Event::Key(key) = event::read()? {
                    if matches!(key.code, KeyCode::Char('q') | KeyCode::Esc | KeyCode::Enter) {
                        break;
                    }
                }
            }
            break;
        }
    }

    // 恢复终端
    disable_raw_mode()?;
    io::stdout().execute(LeaveAlternateScreen)?;

    Ok(())
}
