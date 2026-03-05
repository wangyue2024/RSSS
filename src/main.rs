//! RSSS — Rust Stock Simulation System
//!
//! 3 线程架构:
//! - Main Thread: TUI 渲染循环 (或无 TUI 模式下等待仿真完成)
//! - Simulation Thread: World::run() 循环
//! - IO Thread: Record CSV 写入 (由 Recorder 管理)

use std::env;
use std::fs;
use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::Instant;

use rsss::record::{RecordConfig, Recorder};
use rsss::simulation::{SimConfig, World};
use rsss::tui::{AgentUiRow, TradeUiRow, UiState};

fn main() {
    let args: Vec<String> = env::args().collect();

    // ── 解析命令行参数 ──────────────────────────────
    let mut config = SimConfig::default();
    let mut scripts_dir = String::from("scripts");
    let mut no_tui = false;
    let mut no_record = false;
    let mut output_dir = String::from("output");

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--ticks" => {
                i += 1;
                config.total_ticks = args[i].parse().expect("Invalid --ticks value");
            }
            "--agents" => {
                i += 1;
                config.num_agents = args[i].parse().expect("Invalid --agents value");
            }
            "--seed" => {
                i += 1;
                config.global_seed = args[i].parse().expect("Invalid --seed value");
            }
            "--warmup" => {
                i += 1;
                config.warmup_ticks = args[i].parse().expect("Invalid --warmup value");
            }
            "--cash" => {
                i += 1;
                let yuan: i64 = args[i].parse().expect("Invalid --cash value");
                config.initial_cash = yuan * 1_000_000;
            }
            "--stock" => {
                i += 1;
                config.initial_stock = args[i].parse().expect("Invalid --stock value");
            }
            "--fee" => {
                i += 1;
                config.fee_rate_bps = args[i].parse().expect("Invalid --fee value");
            }
            "--output" => {
                i += 1;
                output_dir = args[i].clone();
            }
            "--no-tui" => {
                no_tui = true;
            }
            "--no-record" => {
                no_record = true;
            }
            "--help" | "-h" => {
                print_usage();
                return;
            }
            other => {
                if !other.starts_with("--") {
                    scripts_dir = other.to_string();
                } else {
                    eprintln!("Unknown option: {}", other);
                    print_usage();
                    std::process::exit(1);
                }
            }
        }
        i += 1;
    }

    // ── 加载脚本 ────────────────────────────────────
    let scripts = load_scripts(&scripts_dir);
    let num_scripts = scripts.len();
    if scripts.is_empty() {
        eprintln!("Warning: No .rhai scripts found in '{}'", scripts_dir);
    }

    // 非 TUI 模式下打印配置
    if no_tui {
        println!("╔══════════════════════════════════════════╗");
        println!("║  RSSS — Rust Stock Simulation System     ║");
        println!("╠══════════════════════════════════════════╣");
        println!(
            "║  Agents:    {:>8}                      ║",
            config.num_agents
        );
        println!(
            "║  Ticks:     {:>8}                      ║",
            config.total_ticks
        );
        println!(
            "║  Warmup:    {:>8}                      ║",
            config.warmup_ticks
        );
        println!(
            "║  Seed:      {:>8}                      ║",
            config.global_seed
        );
        println!("║  Scripts:   {:>8}                      ║", num_scripts);
        println!(
            "║  Fee (bps): {:>8}                      ║",
            config.fee_rate_bps
        );
        println!(
            "║  Record:    {:>8}                      ║",
            if no_record { "OFF" } else { "ON" }
        );
        println!("╚══════════════════════════════════════════╝");
    }

    // ── 构建世界 ────────────────────────────────────
    let mut world = match World::new(config.clone(), scripts) {
        Ok(w) => w,
        Err(e) => {
            eprintln!("Error building world: {}", e);
            std::process::exit(1);
        }
    };

    // ── 创建 Recorder ───────────────────────────────
    let recorder = if !no_record {
        let rc = RecordConfig {
            enabled: true,
            output_dir: output_dir.clone(),
        };
        match Recorder::new(&rc) {
            Ok(r) => Some(r),
            Err(e) => {
                eprintln!("Warning: Failed to create recorder: {}", e);
                None
            }
        }
    } else {
        None
    };

    // ── 创建 UiState ────────────────────────────────
    let ui_state = Arc::new(Mutex::new(UiState::new(config.total_ticks, num_scripts)));

    // ── Simulation Thread ───────────────────────────
    let ui_state_sim = Arc::clone(&ui_state);
    let total_ticks = config.total_ticks;
    let _warmup_ticks = config.warmup_ticks;
    let no_tui_flag = no_tui;

    let sim_handle = std::thread::spawn(move || {
        let t0 = Instant::now();

        for tick in 0..total_ticks {
            world.tick = tick;
            world.run_tick();

            let elapsed = t0.elapsed().as_secs_f64();
            let price = world.indicators.last_price();

            // ── 记录数据 ──
            if let Some(ref rec) = recorder {
                // 市场快照
                let (bids, asks) = world.order_book.get_l2_snapshot(5);
                let b1_px = bids.first().map(|(p, _)| p.as_micros()).unwrap_or(0);
                let b1_vol = bids.first().map(|(_, v)| v.as_u64() as i64).unwrap_or(0);
                let a1_px = asks.first().map(|(p, _)| p.as_micros()).unwrap_or(0);
                let a1_vol = asks.first().map(|(_, v)| v.as_u64() as i64).unwrap_or(0);

                rec.record_market_tick(
                    tick,
                    price,
                    world.tick_volume,
                    world.tick_buy_volume,
                    world.tick_sell_volume,
                    b1_px,
                    b1_vol,
                    a1_px,
                    a1_vol,
                    world.indicators.ma_5(),
                    world.indicators.ma_20(),
                    world.indicators.ma_60(),
                    world.indicators.rsi_14(),
                    world.indicators.atr_14(),
                    world.indicators.vwap(),
                    world.indicators.std_dev(),
                    0, // imbalance (可从 market_state 获取)
                );

                // Agent 快照
                rec.record_agent_snapshots(&world.agents, tick, price);

                // 成交明细
                for &(maker_id, taker_id, px, amt, side) in &world.last_tick_trades {
                    rec.record_trade(tick, maker_id, taker_id, px, amt, side);
                }
            }

            // ── 更新 UiState ──
            {
                let mut state = ui_state_sim.lock().unwrap();
                state.tick = tick + 1;
                state.elapsed_secs = elapsed;
                state.price = price;
                state.volume = world.tick_volume;
                state.total_trades = world.order_book.stats().total_trades;
                state.total_orders = world.order_book.stats().total_orders;
                state.total_cancels = world.order_book.stats().total_cancels;
                state.sim_rejects = world.sim_rejects;
                state.ma_5 = world.indicators.ma_5();
                state.ma_20 = world.indicators.ma_20();
                state.rsi_14 = world.indicators.rsi_14();

                // L2 盘口
                let (bids, asks) = world.order_book.get_l2_snapshot(5);
                for (i, &(p, v)) in bids.iter().enumerate().take(5) {
                    state.bid_prices[i] = p.as_micros();
                    state.bid_volumes[i] = v.as_u64() as i64;
                }
                for (i, &(p, v)) in asks.iter().enumerate().take(5) {
                    state.ask_prices[i] = p.as_micros();
                    state.ask_volumes[i] = v.as_u64() as i64;
                }

                // 最近成交
                for &(maker_id, taker_id, px, amt, side) in &world.last_tick_trades {
                    state.recent_trades.push_back(TradeUiRow {
                        tick,
                        maker_id,
                        taker_id,
                        price: px,
                        amount: amt,
                        taker_side: side,
                    });
                    if state.recent_trades.len() > 20 {
                        state.recent_trades.pop_front();
                    }
                }

                // 价格历史
                state.price_history.push_back(price);
                if state.price_history.len() > 200 {
                    state.price_history.pop_front();
                }

                // Agent 排行 (每 10 Tick 更新避免频繁排序)
                if tick % 10 == 0 || tick == total_ticks - 1 {
                    let mut rows: Vec<AgentUiRow> = world
                        .agents
                        .iter()
                        .map(|a| {
                            let equity = a.cash + a.stock * price;
                            AgentUiRow {
                                id: a.id,
                                strategy_idx: a.id as usize % num_scripts.max(1),
                                cash: a.cash,
                                stock: a.stock,
                                equity,
                                realized_pnl: a.realized_pnl,
                            }
                        })
                        .collect();
                    rows.sort_by(|a, b| b.equity.cmp(&a.equity));
                    state.agents = rows;
                }
            }

            // 非 TUI 模式: 每 100 Tick 打印进度
            if no_tui_flag && (tick + 1) % 100 == 0 {
                let elapsed = t0.elapsed().as_secs_f64();
                let tps = (tick + 1) as f64 / elapsed;
                eprintln!(
                    "  [Tick {:>6}/{}] price={} trades={} tps={:.0}",
                    tick + 1,
                    total_ticks,
                    format_price(price),
                    world.order_book.stats().total_trades,
                    tps,
                );
            }
        }

        // ── 完成 ──
        if let Some(rec) = recorder {
            rec.finish();
        }

        // 标记完成
        {
            let mut state = ui_state_sim.lock().unwrap();
            state.done = true;
        }

        // 返回最终统计给 main thread
        let stats = world.order_book.stats().clone();
        let final_price = world.indicators.last_price();
        let elapsed = t0.elapsed();
        (stats, final_price, elapsed, world.sim_rejects)
    });

    // ── Main Thread: TUI 或等待 ─────────────────────
    if no_tui {
        // 等待 simulation 完成
        let (stats, final_price, elapsed, sim_rejects) = sim_handle.join().unwrap();
        println!();
        println!("═══════════════ Results ═══════════════");
        println!("  Run time:      {:.2?}", elapsed);
        println!(
            "  Ticks/sec:     {:.0}",
            total_ticks as f64 / elapsed.as_secs_f64()
        );
        println!("  Last price:    {}", format_price(final_price));
        println!("  Sim rejects:   {}", sim_rejects);
        println!("  Engine stats:  {:?}", stats);
        if !no_record {
            println!("  Output:        {}/", output_dir);
        }

        // Agent 排行
        let state = ui_state.lock().unwrap();
        println!();
        println!("═══════════ Top 10 Agents ═══════════");
        println!(
            "{:>5}  {:>6}  {:>12}  {:>6}  {:>12}  {:>12}",
            "ID", "Type", "Cash", "Stock", "Equity", "PnL"
        );
        for a in state.agents.iter().take(10) {
            println!(
                "{:>5}  {:>6}  {:>12}  {:>6}  {:>12}  {:>12}",
                a.id,
                strategy_name(a.strategy_idx, num_scripts),
                format_price(a.cash),
                a.stock,
                format_price(a.equity),
                format_price(a.realized_pnl),
            );
        }
    } else {
        // TUI 模式
        if let Err(e) = rsss::tui::run_tui(ui_state) {
            eprintln!("TUI error: {}", e);
            let _ = sim_handle.join();
        } else {
            let _ = sim_handle.join();
        }
    }
}

/// 加载目录下所有 .rhai 文件 (按文件名排序)
fn load_scripts(dir: &str) -> Vec<String> {
    let path = Path::new(dir);
    if !path.exists() || !path.is_dir() {
        return vec![];
    }
    let mut entries: Vec<_> = Vec::new();
    if let Ok(dir) = fs::read_dir(path) {
        for entry in dir.flatten() {
            let p = entry.path();
            if p.extension().and_then(|e| e.to_str()) == Some("rhai") {
                entries.push(p);
            }
        }
    }
    entries.sort();

    let mut scripts = Vec::new();
    for p in &entries {
        if let Ok(content) = fs::read_to_string(p) {
            eprintln!("  Loaded: {}", p.display());
            scripts.push(content);
        }
    }
    scripts
}

fn format_price(micros: i64) -> String {
    let sign = if micros < 0 { "-" } else { "" };
    let abs = micros.unsigned_abs();
    let yuan = abs / 1_000_000;
    let frac = abs % 1_000_000;
    format!("{}{}.{:02}", sign, yuan, frac / 10_000)
}

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

fn print_usage() {
    println!("Usage: rsss [scripts_dir] [options]");
    println!();
    println!("Options:");
    println!("  --ticks N      Total simulation ticks (default: 10000)");
    println!("  --agents N     Number of agents (default: 1000)");
    println!("  --seed N       Global random seed (default: 42)");
    println!("  --warmup N     Warmup ticks (default: 100)");
    println!("  --cash N       Initial cash in yuan (default: 10000)");
    println!("  --stock N      Initial stock per agent (default: 100)");
    println!("  --fee N        Fee rate in bps (default: 3)");
    println!("  --output DIR   Output directory (default: output)");
    println!("  --no-tui       Disable TUI, use text mode");
    println!("  --no-record    Disable CSV recording");
    println!("  -h, --help     Show this help");
}
