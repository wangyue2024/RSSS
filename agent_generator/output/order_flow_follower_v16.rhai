let initialized = false;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(5000, 30000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > 3 * sell_vol && account.cash > 100000 {
        if market.bid_price_0 != 0 {
            let bid_price = market.bid_price_0 + 1;
            let max_amount = account.cash / bid_price;
            if max_amount > 0 {
                let buy_amount = clamp_val(max_amount, 1, 1000);
                orders.submit_limit_buy(bid_price, buy_amount);
            }
        }
    }
    
    if account.stock > 0 && market.price > account.avg_cost && market.ask_price_0 != 0 {
        let ask_price = market.ask_price_0;
        orders.submit_limit_sell(ask_price, account.stock);
    }
}