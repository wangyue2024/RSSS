let initialized = false;
let fomo_triggered = false;
let price_buffer = [];
let last_delayed_price = 0;
let base_spread = 50;
let spread_factor = 20;
let order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(40, 80);
        spread_factor = rng.rand_int(15, 30);
        order_size = rng.rand_int(80, 150);
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    price_buffer.push(current_price);
    
    if price_buffer.len() > 20 {
        price_buffer.remove(0);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if fomo_triggered {
        fomo_triggered = false;
        if market.price > 0 {
            orders.submit_market_buy(order_size);
        }
        return;
    }

    if price_buffer.len() >= 5 {
        let delayed_price = price_buffer[price_buffer.len() - 5];
        last_delayed_price = delayed_price;
    }

    if last_delayed_price == 0 { return; }

    let price_buffer_len = price_buffer.len();
    if price_buffer_len >= 3 {
        let current_price = price_buffer[price_buffer_len - 1];
        let two_ticks_ago = price_buffer[price_buffer_len - 3];
        
        if two_ticks_ago > 0 {
            let price_change_pct = (current_price - two_ticks_ago) * 10000 / two_ticks_ago;
            if price_change_pct > 200 || price_change_pct < -200 {
                fomo_triggered = true;
                return;
            }
        }
    }

    let volatility = market.std_dev;
    let spread_adjustment = (volatility * spread_factor) / 1000000;
    let total_spread = base_spread + spread_adjustment;
    
    if total_spread < 10 { total_spread = 10; }
    if total_spread > 300 { total_spread = 300; }

    let half_spread = total_spread / 2;
    let bid_offset = (last_delayed_price * half_spread) / 10000;
    let ask_offset = (last_delayed_price * half_spread) / 10000;

    let bid_price = last_delayed_price - bid_offset;
    let ask_price = last_delayed_price + ask_offset;

    if bid_price < 1 { bid_price = 1; }
    if ask_price < bid_price + 1 { ask_price = bid_price + 1; }

    if account.cash > bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }

    if account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}