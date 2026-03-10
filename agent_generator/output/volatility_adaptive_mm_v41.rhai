let initialized = false;
let stop_loss_threshold = 0;
let base_order_size = 100;
let min_spread = 5_000;
let max_spread = 50_000;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price + (1_000_000 - remainder)
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(100_000, 500_000);
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(j));
        j += 1;
    }

    if market.price == 0 { return; }

    let vol_factor = market.std_dev * 100 / 1_000_000;
    let spread = clamp_val(min_spread + vol_factor * 200, min_spread, max_spread);
    let half_spread = spread / 2;

    let bid_target = market.price - half_spread;
    let ask_target = market.price + half_spread;

    let bid_price_rounded = round_to_dollar(bid_target);
    let ask_price_rounded = round_to_dollar(ask_target);

    let final_bid = bid_price_rounded + 1;

    if final_bid > 0 && account.cash >= final_bid * base_order_size {
        orders.submit_limit_buy(final_bid, base_order_size);
    }

    if ask_price_rounded > 0 && account.stock >= base_order_size {
        orders.submit_limit_sell(ask_price_rounded, base_order_size);
    }
}