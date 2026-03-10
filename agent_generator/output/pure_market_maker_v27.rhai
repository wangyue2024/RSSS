let initialized = false;
let price_history = [];
let spread_micros = 5000;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(3000, 8000);
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_price = delayed_price - spread_micros;
    let sell_price = delayed_price + spread_micros;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, current_lot_size);
    }
    
    if account.stock >= current_lot_size && delayed_price > account.avg_cost {
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == 0 {
            last_trade_was_loss = fill_price < account.avg_cost;
        } else {
            last_trade_was_loss = fill_price > account.avg_cost;
        }
        
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
            current_lot_size = clamp_val(current_lot_size, base_lot_size, 10000);
        } else {
            current_lot_size = base_lot_size;
        }
    }
}