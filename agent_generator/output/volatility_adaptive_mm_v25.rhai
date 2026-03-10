let initialized = false;
let base_spread = 0;
let volatility_factor = 0;
let order_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(5_000, 20_000);
        volatility_factor = rng.rand_int(3, 10);
        order_amount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    if mid_price <= 0 { return; }

    let volatility = market.std_dev;
    let spread_adjustment = volatility * volatility_factor / 100;
    let total_spread = base_spread + spread_adjustment;

    let half_spread = total_spread / 2;
    let raw_bid_price = mid_price - half_spread;
    let raw_ask_price = mid_price + half_spread;

    let round_to = 1_000_000;
    let rounded_bid = ((raw_bid_price + round_to / 2) / round_to) * round_to;
    let rounded_ask = ((raw_ask_price + round_to / 2) / round_to) * round_to;

    let bid_price = clamp_val(rounded_bid, 100, 1_000_000_000);
    let ask_price = clamp_val(rounded_ask, 100, 1_000_000_000);

    let max_buy_qty = account.cash / bid_price;
    let buy_qty = order_amount;
    if max_buy_qty < buy_qty { buy_qty = max_buy_qty; }
    if buy_qty > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_qty);
    }

    if ask_price > account.avg_cost {
        let sell_qty = order_amount;
        if sell_qty > account.stock { sell_qty = account.stock; }
        if sell_qty > 0 && ask_price > 0 {
            orders.submit_limit_sell(ask_price, sell_qty);
        }
    }
}