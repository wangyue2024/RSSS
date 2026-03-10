let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_price = 0;
let last_trade_loss = false;
let trade_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital = account.total_equity * 5 / 100;
        let max_shares = max_capital / market.price;
        base_lot_size = rng.rand_int(1, max_shares);
        current_lot_size = base_lot_size;
        last_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = fill_cnt - 1;
        let fill_side = my_orders.fill_side(i);
        let fill_price = my_orders.fill_price(i);
        
        if fill_side == "buy" {
            last_trade_loss = market.price < fill_price;
        } else {
            last_trade_loss = market.price > fill_price;
        }
        
        if last_trade_loss {
            let max_capital = account.total_equity * 5 / 100;
            let max_shares = max_capital / market.price;
            current_lot_size = current_lot_size * 2;
            if current_lot_size > max_shares {
                current_lot_size = max_shares;
            }
        } else {
            current_lot_size = base_lot_size;
        }
    }
    
    trade_counter += 1;
    if trade_counter % 50 != 0 { 
        last_price = market.price;
        return; 
    }
    
    let volatility_threshold = market.price * 5 / 100;
    if market.std_dev > volatility_threshold {
        last_price = market.price;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price < last_price {
        let buy_price = market.price * 999 / 1000;
        orders.submit_limit_buy(buy_price, current_lot_size);
    } else if market.price > last_price {
        let sell_price = market.price * 1001 / 1000;
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
    
    last_price = market.price;
}