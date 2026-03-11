let initialized = false;
let lot_size = 100;
let base_lot = 100;
let last_trade_was_loss = false;
let last_realized_pnl = 0;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_realized_pnl = account.realized_pnl;
    }
    
    if !market.trading_enabled { return; }
    
    let tick = market.tick;
    
    if (tick - last_action_tick) % 50 != 0 { return; }
    
    last_action_tick = tick;
    
    if market.high_20 == 0 || market.low_20 == 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_pnl = account.realized_pnl;
    if current_pnl < last_realized_pnl {
        last_trade_was_loss = true;
    } else {
        last_trade_was_loss = false;
    }
    last_realized_pnl = current_pnl;
    
    if last_trade_was_loss {
        lot_size = lot_size * 2;
    } else {
        lot_size = base_lot;
    }
    
    let range_spread = market.high_20 - market.low_20;
    let spread_factor = 500000;
    if range_spread < 5000000 {
        spread_factor = 250000;
    }
    
    let buy_price = market.low_20 + spread_factor;
    let sell_price = market.high_20 - spread_factor;
    
    if buy_price < sell_price {
        orders.submit_limit_buy(buy_price, lot_size);
        orders.submit_limit_sell(sell_price, lot_size);
    }
}