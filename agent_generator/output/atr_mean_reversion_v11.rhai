let initialized = false;
let base_lot_size = 0;
let current_lot_multiplier = 1;
let last_trade_was_loss = false;
let skip_trading = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_capital_for_trade = account.total_equity * 5 / 100;
        let random_percent = rng.rand_int(1, 5);
        base_lot_size = max_capital_for_trade * random_percent / 100;
        
        if base_lot_size < 1_000_000 {
            base_lot_size = 1_000_000;
        }
        
        current_lot_multiplier = 1;
        last_trade_was_loss = false;
        skip_trading = false;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill_index = fill_count - 1;
        let fill_price = my_orders.fill_price(last_fill_index);
        let fill_side = my_orders.fill_side(last_fill_index);
        
        if fill_side == 0 {
            last_trade_was_loss = market.price < fill_price;
        } else {
            last_trade_was_loss = market.price > fill_price;
        }
        
        if last_trade_was_loss {
            current_lot_multiplier = current_lot_multiplier * 2;
            if current_lot_multiplier > 8 {
                current_lot_multiplier = 8;
            }
        } else {
            current_lot_multiplier = 1;
        }
    }
    
    let std_dev_threshold = market.price * 50 / 10000;
    if market.std_dev > std_dev_threshold {
        skip_trading = true;
        return;
    } else {
        skip_trading = false;
    }
    
    if market.ma_20 == 0 || market.atr_14 == 0 { return; }
    
    let deviation = market.price - market.ma_20;
    let abs_deviation = abs_val(deviation);
    let atr_threshold = market.atr_14 * 3 / 2;
    
    if abs_deviation > atr_threshold && !skip_trading {
        let trade_shares = (base_lot_size * current_lot_multiplier) / market.price;
        if trade_shares < 100 {
            trade_shares = 100;
        }
        
        if deviation > 0 {
            orders.submit_limit_sell(market.bid_price_0, trade_shares);
        } else {
            orders.submit_limit_buy(market.ask_price_0, trade_shares);
        }
    }
}