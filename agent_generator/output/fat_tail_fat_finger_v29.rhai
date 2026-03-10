let initialized = false;
let last_prices = [];
let base_lot_size = 10000;
let current_lot_size = base_lot_size;
let last_trade_avg_cost = 0;
let last_trade_profit_loss = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = 10000;
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { 
        return; 
    }

    last_prices.push(market.price);
    if last_prices.len() > 6 {
        last_prices.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if my_orders.fill_count() > 0 {
        let last_fill_idx = my_orders.fill_count() - 1;
        let fill_price = my_orders.fill_price(last_fill_idx);
        let fill_side = my_orders.fill_side(last_fill_idx);
        
        last_trade_avg_cost = fill_price;
        
        if account.stock > 0 {
            if fill_side == 0 {
                last_trade_profit_loss = market.price - fill_price;
            } else {
                last_trade_profit_loss = fill_price - market.price;
            }
        }
        
        if last_trade_profit_loss < 0 {
            current_lot_size = current_lot_size * 2;
        } else {
            current_lot_size = base_lot_size;
        }
    }

    if last_prices.len() >= 6 {
        let delayed_price = last_prices[last_prices.len() - 6];
        
        if rng.rand_int(0, 9999) == 0 {
            let fat_finger_amount = current_lot_size * 100;
            if rng.rand_bool(50) {
                orders.submit_market_buy(fat_finger_amount);
            } else {
                orders.submit_market_sell(fat_finger_amount);
            }
            return;
        }
        
        if rng.rand_bool(1) {
            if rng.rand_bool(50) {
                orders.submit_limit_buy(delayed_price, current_lot_size);
            } else {
                orders.submit_limit_sell(delayed_price, current_lot_size);
            }
        }
    }
}