let initialized = false;
let lot_size = 0;
let max_inventory = 1000;
let volatility_threshold = 50000;
let cancel_threshold_ticks = 3;
let base_spread = 2000;
let skew_factor = 1000;

fn on_tick() {
    if !initialized {
        if market.price > 0 {
            let five_percent_capital = account.total_equity * 5 / 100;
            let max_shares = five_percent_capital / market.price;
            if max_shares < 1 {
                lot_size = 1;
            } else {
                lot_size = rng.rand_int(1, max_shares);
            }
            initialized = true;
        }
        return;
    }

    if !market.trading_enabled {
        return;
    }

    if market.std_dev > volatility_threshold {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= cancel_threshold_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let inventory = account.stock;
    let inv_ratio = inventory * 100 / max_inventory;
    let clamped_inv = clamp_val(inv_ratio, -100, 100);

    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let buy_skew = clamped_inv * skew_factor / 100;
    let sell_skew = -clamped_inv * skew_factor / 100;

    let buy_price = mid_price - base_spread + buy_skew;
    let sell_price = mid_price + base_spread + sell_skew;

    let has_buy_order = false;
    let has_sell_order = false;
    let pending_cnt2 = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt2 {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy_order = true;
        } else if side == 1 {
            has_sell_order = true;
        }
        j += 1;
    }

    if !has_buy_order && inventory < max_inventory {
        let cash_available = account.cash;
        let max_buy_amount = cash_available / buy_price;
        let buy_amount = clamp_val(lot_size, 1, max_buy_amount);
        if buy_amount > 0 && buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    if !has_sell_order && inventory > -max_inventory {
        let stock_available = account.stock;
        let sell_amount = clamp_val(lot_size, 1, stock_available);
        if sell_amount > 0 && sell_price > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}