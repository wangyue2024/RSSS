let initialized = false;
let price_history = [];
let last_trade_price = 0;
let last_trade_side = 0;
let lot_size = 100;
let base_lot_size = 100;
let last_trade_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        lot_size = base_lot_size;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 100 {
        price_history.remove(0);
    }
    
    let delayed_price = 0;
    if price_history.len() >= 5 {
        delayed_price = price_history[price_history.len() - 5];
    } else {
        delayed_price = market.price;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        last_trade_price = my_orders.fill_price(last_fill_idx);
        last_trade_side = my_orders.fill_side(last_fill_idx);
        last_trade_tick = market.tick;
    }
    
    if last_trade_tick < market.tick - 1 && last_trade_price > 0 {
        let price_diff = market.price - last_trade_price;
        if (last_trade_side == 0 && price_diff < 0) || (last_trade_side == 1 && price_diff > 0) {
            lot_size = base_lot_size * 2;
        } else {
            lot_size = base_lot_size;
        }
    }
    
    let rand_val = rng.rand_int(0, 99);
    let amount = rng.rand_int(1, 5) * lot_size;
    
    if rand_val < 5 {
        let offset = rng.rand_int(-50000, 50000);
        let price = delayed_price + offset;
        if price < 1 {
            price = 1;
        }
        orders.submit_limit_buy(price, amount);
    } else if rand_val > 95 {
        let offset = rng.rand_int(-50000, 50000);
        let price = delayed_price + offset;
        if price < 1 {
            price = 1;
        }
        orders.submit_limit_sell(price, amount);
    }
}