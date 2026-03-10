let initialized = false;
let ma5_buffer = [];
let ma20_buffer = [];
let in_trade = false;
let last_trade_was_loss = false;
let base_lot = 1000;
let current_lot = base_lot;
let buy_avg_cost = 0;
let buy_shares = 0;
let active_period_end = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(800, 1200);
        current_lot = base_lot;
        active_period_end = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    ma5_buffer.push(market.ma_5);
    ma20_buffer.push(market.ma_20);
    if ma5_buffer.len() > 6 {
        ma5_buffer.remove(0);
        ma20_buffer.remove(0);
    }
    
    if market.tick >= active_period_end {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
            in_trade = false;
        }
        return;
    }
    
    if ma5_buffer.len() < 6 { return; }
    
    let ma5_5ago = ma5_buffer[0];
    let ma20_5ago = ma20_buffer[0];
    let ma5_6ago = ma5_buffer[1];
    let ma20_6ago = ma20_buffer[1];
    
    let ma5_cross_above = ma5_5ago > ma20_5ago && ma5_6ago <= ma20_6ago;
    let ma5_cross_below = ma5_5ago < ma20_5ago && ma5_6ago >= ma20_6ago;
    
    if ma5_cross_above && !in_trade {
        orders.submit_market_buy(current_lot);
        in_trade = true;
        buy_avg_cost = market.price;
        buy_shares = current_lot;
    } else if ma5_cross_below && in_trade && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        
        let current_val = account.stock * market.price;
        let cost_val = account.stock * buy_avg_cost;
        if current_val < cost_val {
            last_trade_was_loss = true;
            current_lot = current_lot * 2;
            if current_lot > 10000 { current_lot = 10000; }
        } else {
            last_trade_was_loss = false;
            current_lot = base_lot;
        }
        
        in_trade = false;
        buy_avg_cost = 0;
        buy_shares = 0;
    }
}