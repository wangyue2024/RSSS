let initialized = false;
let SPREAD_MICROS = 1000;
let ORDER_AMOUNT = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid = market.price;
    if mid > 0 {
        let bid_price = mid - SPREAD_MICROS + 1;
        let ask_price = mid + SPREAD_MICROS;
        
        if account.cash >= bid_price {
            let max_buy = account.cash / bid_price;
            let buy_amt = if ORDER_AMOUNT < max_buy { ORDER_AMOUNT } else { max_buy };
            if buy_amt > 0 {
                orders.submit_limit_buy(bid_price, buy_amt);
            }
        }
        
        if account.stock > 0 {
            let sell_amt = if ORDER_AMOUNT < account.stock { ORDER_AMOUNT } else { account.stock };
            orders.submit_limit_sell(ask_price, sell_amt);
        }
    }
}