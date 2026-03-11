let initialized = false;
let risk_lot_size = 0;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_lot_size = rng.rand_int(50, 200);
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let cash_50pct = account.cash * 50 / 100;
    let current_price = market.price;
    let max_shares_by_cash = if current_price > 0 { cash_50pct / current_price } else { 0 };
    let buy_amount = if risk_lot_size < max_shares_by_cash { risk_lot_size } else { max_shares_by_cash };
    let sell_amount = if risk_lot_size < account.stock { risk_lot_size } else { account.stock };
    
    let rsi = market.rsi_14;
    
    if rsi < 3000 && buy_amount > 0 {
        let discount_price = current_price * 995 / 1000;
        orders.submit_limit_buy(discount_price, buy_amount);
        last_action_tick = market.tick;
    } else if rsi > 7000 && sell_amount > 0 {
        let premium_price = current_price * 1005 / 1000;
        orders.submit_limit_sell(premium_price, sell_amount);
        last_action_tick = market.tick;
    }
}