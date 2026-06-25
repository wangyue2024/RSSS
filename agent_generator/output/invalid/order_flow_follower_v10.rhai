let initialized = false;
let my_position_size = 0;
let avg_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        my_position_size = 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > 0 && sell_vol > 0 && buy_vol * 3 > sell_vol {
        let buy_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
        let max_affordable = account.cash / buy_price;
        let amount_to_buy = clamp_val(my_position_size, 0, max_affordable);
        
        if amount_to_buy > 0 {
            orders.submit_limit_buy(buy_price, amount_to_buy);
        }
    }
    
    if account.stock > 0 {
        if account.avg_cost > 0 && market.price > account.avg_cost {
            let sell_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
            if sell_price > account.avg_cost {
                orders.submit_limit_sell(sell_price, account.stock);
            }
        }
    }
}