let initialized = false;
let fomo_triggered = false;
let fomo_tick = 0;
let price_history = [];
let base_spread_bps = 12;
let min_order_size = 100;
let max_order_size = 500;
let inventory_target = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_bps = rng.rand_int(8, 20);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let current_price = market.price;

    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if fomo_triggered && current_tick - fomo_tick > 5 {
        fomo_triggered = false;
    }

    let fomo_check_ticks = 3;
    if price_history.len() >= fomo_check_ticks + 1 {
        let old_idx = price_history.len() - fomo_check_ticks - 1;
        let old_price = price_history[old_idx];
        if old_price != 0 {
            let price_change_pct = (current_price - old_price) * 10000 / old_price;
            if price_change_pct > 200 || price_change_pct < -200 {
                fomo_triggered = true;
                fomo_tick = current_tick;
                let buy_amount = clamp_val(min_order_size * 3, min_order_size, max_order_size);
                orders.submit_market_buy(buy_amount);
                return;
            }
        }
    }

    if fomo_triggered { return; }

    let inventory = account.stock;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    if mid_price <= 0 { return; }

    let spread_adjust = 0;
    if inventory > 1000 {
        spread_adjust = 50;
    } else if inventory <= 0 {
        spread_adjust = -50;
    }

    let buy_spread_bps = base_spread_bps + spread_adjust;
    let sell_spread_bps = base_spread_bps - spread_adjust;

    let min_spread = 2;
    if buy_spread_bps < min_spread { buy_spread_bps = min_spread; }
    if sell_spread_bps < min_spread { sell_spread_bps = min_spread; }

    let buy_price = mid_price - (mid_price * buy_spread_bps) / 10000;
    let sell_price = mid_price + (mid_price * sell_spread_bps) / 10000;

    buy_price = clamp_val(buy_price, 1, market.bid_price_0 - 1);
    sell_price = clamp_val(sell_price, market.ask_price_0 + 1, 10_000_000_000);

    let order_size = clamp_val(abs_val(inventory_target - inventory) / 10, min_order_size, max_order_size);

    if account.cash >= buy_price * order_size / 1_000_000 {
        orders.submit_limit_buy(buy_price, order_size);
    }

    if account.stock >= order_size {
        orders.submit_limit_sell(sell_price, order_size);
    }
}