let initialized = false;
let lazy_counter = 0;
let base_spread_micros = 50_000;
let base_order_size = 100;
let last_trade_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_micros = rng.rand_int(30_000, 70_000);
        base_order_size = rng.rand_int(50, 150);
    }

    if !market.trading_enabled { return; }

    lazy_counter += 1;
    if lazy_counter < 50 { return; }
    lazy_counter = 0;

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.price <= 0 { return; }

    let volatility_factor = market.std_dev * 150 / 1_000_000;
    let volatility_factor = clamp_val(volatility_factor, 100, 300);
    let dynamic_spread = base_spread_micros * volatility_factor / 100;

    let mid_price = market.price;
    let bid_price = mid_price - dynamic_spread / 2;
    let ask_price = mid_price + dynamic_spread / 2;

    let max_buy_shares = account.cash / bid_price;
    let buy_size = base_order_size;
    if max_buy_shares < buy_size {
        buy_size = max_buy_shares;
    }
    if buy_size > 0 {
        orders.submit_limit_buy(bid_price, buy_size);
    }

    let avg_cost = account.avg_cost;
    if avg_cost > 0 && ask_price > avg_cost {
        let sell_size = base_order_size;
        if account.stock < sell_size {
            sell_size = account.stock;
        }
        if sell_size > 0 {
            orders.submit_limit_sell(ask_price, sell_size);
        }
    }
}