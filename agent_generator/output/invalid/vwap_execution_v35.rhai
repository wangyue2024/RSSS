let initialized = false;
let target_shares = 100000;
let initial_stock = 0;
let bought_shares = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        initial_stock = account.stock;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if fomo_triggered {
        let remaining = target_shares - (account.stock - initial_stock);
        if remaining > 0 && market.ask_price_0 > 0 {
            orders.submit_market_buy(remaining);
        }
        return;
    }

    let price_change_window = 10;
    if market.history_len() >= price_change_window {
        let price_now = market.price;
        let price_old = market.history_price(price_change_window - 1);
        if price_old > 0 {
            let change_bps = (price_now - price_old) * 10000 / price_old;
            if change_bps > 200 {
                fomo_triggered = true;
                let remaining = target_shares - (account.stock - initial_stock);
                if remaining > 0 && market.ask_price_0 > 0 {
                    orders.submit_market_buy(remaining);
                }
                return;
            }
        }
    }

    let volume_lookback = 20;
    let total_volume = market.volume;
    let count = 1;
    let j = 0;
    while j < volume_lookback - 1 && j < market.history_len() {
        total_volume += market.history_volume(j);
        count += 1;
        j += 1;
    }
    let avg_volume = if count > 0 { total_volume / count } else { 1 };
    let volume_ratio = if avg_volume > 0 { market.volume * 100 / avg_volume } else { 100 };

    let remaining = target_shares - (account.stock - initial_stock);
    if remaining <= 0 { return; }

    let active_ticks_left = market.total_ticks / 5 - market.tick;
    let base_slice = if active_ticks_left > 0 { remaining / active_ticks_left } else { remaining };
    let dynamic_slice = base_slice * volume_ratio / 100;

    let slice = if dynamic_slice < 1 { 1 } else { dynamic_slice };
    let order_amount = if slice > remaining { remaining } else { slice };

    if order_amount > 0 && market.ask_price_0 > 0 {
        orders.submit_limit_buy(market.ask_price_0, order_amount);
    }
}