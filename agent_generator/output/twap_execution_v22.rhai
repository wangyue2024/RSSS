let target_position = 50_000;
let slice_size = 500;
let ticks_interval = 50;
let fomo_window = 10;
let fomo_threshold_pct = 200; // 2% = 200/10000

fn on_tick() {
    if !market.trading_enabled { return; }

    // Cancel any pending orders at the start of each active evaluation
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_position = account.stock;
    if current_position >= target_position { return; }
    let remaining_to_buy = target_position - current_position;

    // FOMO check (runs every tick, overrides lazy interval)
    if market.history_len() >= fomo_window {
        let current_price = market.price;
        let past_price = market.history_price(fomo_window - 1);
        let price_jump_pct = (current_price - past_price) * 10000 / past_price;
        if price_jump_pct >= fomo_threshold_pct && remaining_to_buy > 0 {
            orders.submit_market_buy(remaining_to_buy);
            return;
        }
    }

    // Lazy trader: core TWAP logic only runs every N ticks
    if market.tick % ticks_interval != 0 { return; }

    let buy_amount = slice_size;
    if remaining_to_buy < slice_size {
        buy_amount = remaining_to_buy;
    }
    if buy_amount > 0 {
        orders.submit_market_buy(buy_amount);
    }
}