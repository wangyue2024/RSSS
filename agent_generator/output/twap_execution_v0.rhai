let initialized = false;
let target_position = 50000;
let slice_size = 500;
let N_ticks = 10;
let last_buy_tick = -1000000;
let fomo_triggered = false;
let fomo_window = 5;
let target_acquired = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let morning_phase_limit = market.total_ticks / 5;
    if market.tick >= morning_phase_limit {
        return;
    }

    if target_acquired {
        return;
    }

    let current_pos = account.stock;
    if current_pos >= target_position {
        target_acquired = true;
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let sell_possible = account.stock > 0 && market.price > account.avg_cost;
    if sell_possible {
        let sell_amount = if slice_size > account.stock { account.stock } else { slice_size };
        if sell_amount > 0 {
            orders.submit_limit_sell(market.price, sell_amount);
        }
    }

    if market.tick - last_buy_tick >= N_ticks && !fomo_triggered {
        let remaining_to_target = target_position - current_pos;
        let buy_amount = if slice_size > remaining_to_target { remaining_to_target } else { slice_size };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            last_buy_tick = market.tick;
        }
    }

    if market.tick >= fomo_window {
        let past_price = market.history_price(market.tick - fomo_window);
        let price_jump_pct = (market.price - past_price) * 10000 / past_price;
        if price_jump_pct > 200 {
            fomo_triggered = true;
            let remaining = target_position - current_pos;
            let fomo_buy_amount = if slice_size > remaining { remaining } else { slice_size };
            if fomo_buy_amount > 0 {
                orders.submit_market_buy(fomo_buy_amount);
            }
        }
    }
}