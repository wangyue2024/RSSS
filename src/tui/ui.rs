//! ratatui 布局渲染

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Cell, Paragraph, Row, Sparkline, Table};
use ratatui::Frame;

use super::state::UiState;

/// 微元 → "100.50" 字符串
fn fmt_price(micros: i64) -> String {
    let sign = if micros < 0 { "-" } else { "" };
    let abs = micros.unsigned_abs();
    format!(
        "{}{}.{:02}",
        sign,
        abs / 1_000_000,
        (abs % 1_000_000) / 10_000
    )
}

/// 策略名
fn strategy_name(idx: usize, num_scripts: usize) -> &'static str {
    if num_scripts == 0 {
        return "empty";
    }
    match idx % num_scripts {
        0 => "MM",
        1 => "MOM",
        2 => "MR",
        3 => "NOISE",
        4 => "RSI",
        _ => "OTHER",
    }
}

/// 渲染整个 UI
pub fn draw(f: &mut Frame, state: &UiState) {
    let size = f.area();

    // 主布局: 上(状态栏) | 中(内容) | 下(帮助)
    let main_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // 状态栏
            Constraint::Min(10),   // 内容区
            Constraint::Length(3), // 统计 + 帮助
        ])
        .split(size);

    draw_header(f, main_chunks[0], state);
    draw_content(f, main_chunks[1], state);
    draw_footer(f, main_chunks[2], state);
}

fn draw_header(f: &mut Frame, area: Rect, state: &UiState) {
    let tps = if state.elapsed_secs > 0.0 {
        state.tick as f64 / state.elapsed_secs
    } else {
        0.0
    };
    let progress = if state.total_ticks > 0 {
        state.tick * 100 / state.total_ticks
    } else {
        0
    };

    let status = if state.done { " ✅ DONE" } else { "" };
    let text = format!(
        " Tick: {}/{} ({:>3}%)  │  {:.0} tps  │  {:.1}s{}  │  Price: {}  │  Trades: {}",
        state.tick,
        state.total_ticks,
        progress,
        tps,
        state.elapsed_secs,
        status,
        fmt_price(state.price),
        state.total_trades,
    );

    let block = Block::default()
        .title(" RSSS — Rust Stock Simulation System ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Cyan));

    let para = Paragraph::new(text).block(block);
    f.render_widget(para, area);
}

fn draw_content(f: &mut Frame, area: Rect, state: &UiState) {
    // 左(价格+成交) | 右(盘口+Agent)
    let h_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
        .split(area);

    // 左侧: 价格走势 + 最近成交
    let left_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(55), Constraint::Percentage(45)])
        .split(h_chunks[0]);

    draw_sparkline(f, left_chunks[0], state);
    draw_recent_trades(f, left_chunks[1], state);

    // 右侧: 盘口 + Agent 表
    let right_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(13), Constraint::Min(5)])
        .split(h_chunks[1]);

    draw_orderbook(f, right_chunks[0], state);
    draw_agents(f, right_chunks[1], state);
}

fn draw_sparkline(f: &mut Frame, area: Rect, state: &UiState) {
    let block = Block::default().title(" 价格走势 ").borders(Borders::ALL);

    if state.price_history.is_empty() {
        let para = Paragraph::new(" Waiting for data...").block(block);
        f.render_widget(para, area);
        return;
    }

    // 归一化: sparkline 只接受 u64, 需要 offset 到 0 基
    let min_p = state.price_history.iter().copied().min().unwrap_or(0);
    let data: Vec<u64> = state
        .price_history
        .iter()
        .map(|&p| (p - min_p) as u64 + 1)
        .collect();

    // 限制宽度
    let inner = block.inner(area);
    let width = inner.width as usize;
    let slice = if data.len() > width {
        &data[data.len() - width..]
    } else {
        &data
    };

    let sparkline = Sparkline::default()
        .block(block)
        .data(slice)
        .style(Style::default().fg(Color::Green));

    f.render_widget(sparkline, area);
}

fn draw_orderbook(f: &mut Frame, area: Rect, state: &UiState) {
    let block = Block::default()
        .title(" L2 盘口 ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Yellow));

    let mut lines = Vec::new();

    // Asks (从高到低, 红色)
    for i in (0..5).rev() {
        let px = state.ask_prices[i];
        let vol = state.ask_volumes[i];
        if px > 0 {
            lines.push(Line::from(vec![Span::styled(
                format!("  ASK {:>10}  × {:>5}", fmt_price(px), vol),
                Style::default().fg(Color::Red),
            )]));
        }
    }

    // Spread
    let spread = if state.ask_prices[0] > 0 && state.bid_prices[0] > 0 {
        state.ask_prices[0] - state.bid_prices[0]
    } else {
        0
    };
    lines.push(Line::from(vec![Span::styled(
        format!("  ─── Spread: {} ───", fmt_price(spread)),
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::DIM),
    )]));

    // Bids (从高到低, 绿色)
    for i in 0..5 {
        let px = state.bid_prices[i];
        let vol = state.bid_volumes[i];
        if px > 0 {
            lines.push(Line::from(vec![Span::styled(
                format!("  BID {:>10}  × {:>5}", fmt_price(px), vol),
                Style::default().fg(Color::Green),
            )]));
        }
    }

    let para = Paragraph::new(lines).block(block);
    f.render_widget(para, area);
}

fn draw_agents(f: &mut Frame, area: Rect, state: &UiState) {
    let header_cells = ["ID", "Type", "Cash (Lck)", "Stock (Lck)", "Equity", "PnL"]
        .iter()
        .map(|h| {
            Cell::from(*h).style(
                Style::default()
                    .fg(Color::Cyan)
                    .add_modifier(Modifier::BOLD),
            )
        });
    let header = Row::new(header_cells).height(1);

    let rows = state.agents.iter().map(|a| {
        let pnl_color = if a.realized_pnl > 0 {
            Color::Green
        } else if a.realized_pnl < 0 {
            Color::Red
        } else {
            Color::White
        };
        Row::new(vec![
            Cell::from(format!("{:>3}", a.id)),
            Cell::from(strategy_name(a.strategy_idx, state.num_scripts)),
            Cell::from(format!(
                "{} ▼{}",
                fmt_price(a.cash),
                fmt_price(a.locked_cash)
            )),
            Cell::from(format!("{} ▼{}", a.stock, a.locked_stock)),
            Cell::from(fmt_price(a.equity)),
            Cell::from(fmt_price(a.realized_pnl)).style(Style::default().fg(pnl_color)),
        ])
    });

    let table = Table::new(
        rows,
        [
            Constraint::Length(4),
            Constraint::Length(6),
            Constraint::Length(20),
            Constraint::Length(12),
            Constraint::Length(12),
            Constraint::Length(12),
        ],
    )
    .header(header)
    .block(Block::default().title(" Agent 排行 ").borders(Borders::ALL));

    f.render_widget(table, area);
}

fn draw_recent_trades(f: &mut Frame, area: Rect, state: &UiState) {
    let block = Block::default().title(" 最近成交 ").borders(Borders::ALL);

    let lines: Vec<Line> = state
        .recent_trades
        .iter()
        .rev()
        .take(area.height.saturating_sub(2) as usize)
        .map(|t| {
            let side_str = if t.taker_side == 1 { "B" } else { "S" };
            let color = if t.taker_side == 1 {
                Color::Green
            } else {
                Color::Red
            };
            Line::from(vec![
                Span::raw(format!("T{:>5} ", t.tick)),
                Span::styled(
                    format!(
                        "{} #{:>2}→#{:<2} @{} ×{}",
                        side_str,
                        t.maker_id,
                        t.taker_id,
                        fmt_price(t.price),
                        t.amount,
                    ),
                    Style::default().fg(color),
                ),
            ])
        })
        .collect();

    let para = Paragraph::new(lines).block(block);
    f.render_widget(para, area);
}

fn draw_footer(f: &mut Frame, area: Rect, state: &UiState) {
    let text = format!(
        " Orders: {}  │  Trades: {}  │  Cancels: {}  │  Sim Rejects: {}  │  MA5: {}  MA20: {}  RSI: {}  │  [q] Quit",
        state.total_orders, state.total_trades, state.total_cancels, state.sim_rejects,
        fmt_price(state.ma_5), fmt_price(state.ma_20), state.rsi_14 / 100,
    );
    let block = Block::default().borders(Borders::ALL);
    let para = Paragraph::new(text).block(block);
    f.render_widget(para, area);
}
