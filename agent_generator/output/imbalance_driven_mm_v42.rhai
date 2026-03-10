let initialized = false;
let lot_size = 0;
let stop_loss_threshold = 0;
let last_action_tick = -1;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        lot_size = (account.cash / market.price) * 50 / 100;
        if lot_size < 1 { lot_size = 1; }
        stop_loss_threshold = -rng.rand_int(5000, 20000);
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    let base_price = market.price;
    let shift = base_price * imbalance * 2 / 1000;
    
    let spread = 10;
    let bid_price = base_price + shift - spread;
    let ask_price = base_price + shift + spread;
    
    let available_cash_buy = account.cash / bid_price;
    let buy_amount = available_cash_buy * 50 / 100;
    if buy_amount > lot_size { buy_amount = lot_size; }
    if buy_amount < 1 { buy_amount = 1; }
    
    let sell_amount = account.stock * 50 / 100;
    if sell_amount > lot_size { sell_amount = lot_size; }
    if sell_amount < 1 { sell_amount = 1; }
    
    if buy_amount > 0 && bid_price > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    if sell_amount > 0 && ask_price > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}