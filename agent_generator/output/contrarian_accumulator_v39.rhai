let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let panic_threshold = 0;
let last_trade_was_loss = false;
let last_evaluation_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(20, 100);
        current_lot_size = base_lot_size;
        panic_threshold = -rng.rand_int(10000, 50000);
        last_evaluation_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        last_trade_was_loss = true;
        return;
    }
    
    if market.tick - last_evaluation_tick < 50 {
        return;
    }
    last_evaluation_tick = market.tick;
    
    if market.rsi_14 < 3000 && account.cash > 0 {
        if last_trade_was_loss {
            current_lot_size = current_lot_size * 2;
        } else {
            current_lot_size = base_lot_size;
        }
        
        let buy_price = market.price * 95 / 100;
        let amount = current_lot_size;
        if amount * buy_price <= account.cash {
            orders.submit_limit_buy(buy_price, amount);
        }
        last_trade_was_loss = false;
    } else if market.rsi_14 > 7000 && account.stock > 0 {
        let sell_price = market.price;
        let avg_cost = account.avg_cost;
        if sell_price < avg_cost {
            last_trade_was_loss = true;
        } else {
            last_trade_was_loss = false;
        }
        orders.submit_limit_sell(sell_price, account.stock);
    }
}