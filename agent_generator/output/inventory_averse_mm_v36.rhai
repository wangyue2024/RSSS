let initialized = false;
let base_spread = 2000;
let order_size = 100;
let inv_threshold = 1000;
let max_skew = 1000;
let patience_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let mid_price;
    let best_bid = market.bid_price_0;
    let best_ask = market.ask_price_0;

    if best_bid > 0 && best_ask > 0 {
        mid_price = (best_bid + best_ask) / 2;
    } else {
        mid_price = market.price;
    }

    let inventory = account.stock;
    let inv_ratio;
    if inventory > inv_threshold {
        inv_ratio = 1_000_000;
    } else if inventory < 0 {
        inv_ratio = -1_000_000;
    } else {
        inv_ratio = inventory * 1_000_000 / inv_threshold;
    }
    if inv_ratio > 1_000_000 {
        inv_ratio = 1_000_000;
    }
    if inv_ratio < -1_000_000 {
        inv_ratio = -1_000_000;
    }

    let skew_adjust = (max_skew * inv_ratio) / 1_000_000;
    let half_spread = base_spread / 2;

    let target_bid_spread = half_spread + skew_adjust;
    let target_ask_spread = half_spread - skew_adjust;

    if target_bid_spread < 1 {
        target_bid_spread = 1;
    }
    if target_ask_spread < 1 {
        target_ask_spread = 1;
    }

    let bid_price = mid_price - target_bid_spread;
    let ask_price = mid_price + target_ask_spread;

    if bid_price <= 0 {
        bid_price = 1;
    }
    if ask_price <= bid_price {
        ask_price = bid_price + 1;
    }

    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_at = my_orders.pending_placed_tick(i);
        if current_tick - placed_at >= patience_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let remaining_buy_orders = 0;
    let remaining_sell_orders = 0;
    let pending_cnt2 = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt2 {
        let side = my_orders.pending_side(j);
        if side == 0 {
            remaining_buy_orders += 1;
        } else {
            remaining_sell_orders += 1;
        }
        j += 1;
    }

    if remaining_buy_orders == 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if remaining_sell_orders == 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}