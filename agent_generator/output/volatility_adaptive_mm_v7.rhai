let initialized = false;
let last_action_tick = 0;
let base_spread = 0;
let volatility_factor = 0;
let order_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(500, 3000);
        volatility_factor = rng.rand_int(50, 300);
        order_amount = rng.rand_int(10, 100);
        last_action_tick = market.tick;
    }

    if !market.trading_enabled { return; }

    let i = 0;
    let pcount = my_orders.pending_count();
    while i < pcount {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if market.tick % 50 != 0 { return; }

    let pcount2 = my_orders.pending_count();
    let j = 0;
    while j < pcount2 {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    let vol_scale = market.std_dev * volatility_factor / 10000;
    let total_spread = base_spread + vol_scale;
    let half_spread = total_spread / 2;

    let mid_price = market.price;
    let bid_price = mid_price - half_spread;
    let ask_price = mid_price + half_spread;

    let adjusted_bid = bid_price + 1;

    if account.cash >= adjusted_bid * order_amount {
        orders.submit_limit_buy(adjusted_bid, order_amount);
    }

    if account.stock >= order_amount {
        orders.submit_limit_sell(ask_price, order_amount);
    }

    last_action_tick = market.tick;
}