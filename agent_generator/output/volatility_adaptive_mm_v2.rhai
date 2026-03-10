let initialized = false;
let base_spread = 0;
let vol_multiplier = 0;
let order_amount = 0;
let max_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 5000);
        vol_multiplier = rng.rand_int(150, 250);
        order_amount = rng.rand_int(80, 120);
        max_position = rng.rand_int(800, 1200);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = market.price;
    let volatility = market.std_dev;
    
    let dynamic_spread = base_spread + (volatility * vol_multiplier) / 1000;
    let half_spread = dynamic_spread / 2;
    
    let raw_bid = mid_price - half_spread;
    let bid_price = raw_bid + 1;
    let ask_price = mid_price + half_spread;
    
    let current_position = account.stock;
    
    if current_position < max_position {
        let buy_qty = clamp_val(order_amount, 1, max_position - current_position);
        if bid_price > 0 && account.cash >= bid_price * buy_qty {
            orders.submit_limit_buy(bid_price, buy_qty);
        }
    }
    
    if current_position > -max_position {
        let sell_qty = clamp_val(order_amount, 1, current_position + max_position);
        if ask_price > 0 && account.stock >= sell_qty {
            orders.submit_limit_sell(ask_price, sell_qty);
        }
    }
}