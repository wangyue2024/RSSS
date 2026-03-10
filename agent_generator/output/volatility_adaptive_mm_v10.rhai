let initialized = false;
let base_spread = 0;
let volatility_multiplier = 0;
let order_size = 0;
let price_buffer = [];
let std_dev_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(800, 1500);
        volatility_multiplier = rng.rand_int(500, 1500);
        order_size = rng.rand_int(80, 120);
    }

    if !market.trading_enabled { return; }

    price_buffer.push(market.price);
    std_dev_buffer.push(market.std_dev);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        std_dev_buffer.remove(0);
    }

    if price_buffer.len() < 5 { return; }

    let delayed_price = price_buffer[0];
    let delayed_std_dev = std_dev_buffer[0];

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let spread_addition = (delayed_std_dev * volatility_multiplier) / 1000;
    let half_spread = (base_spread + spread_addition) / 2;
    half_spread = clamp_val(half_spread, 500, 25000);

    let bid_price = delayed_price - half_spread;
    let ask_price = delayed_price + half_spread;

    if bid_price > 0 && account.cash >= bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if ask_price > 0 && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}