let initialized = false;
let threshold_bp = 100;
let buy_amount = 100;
let sell_price_offset_bp = 50;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks * 2 / 10 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap_threshold_price = market.vwap * (10000 - threshold_bp) / 10000;
    
    if market.price < vwap_threshold_price && account.cash > 0 {
        let buy_price = round_to_dollar(market.price);
        if buy_price > 0 {
            let max_buy_shares = account.cash / buy_price;
            if max_buy_shares > 0 {
                let shares_to_buy = buy_amount;
                if shares_to_buy > max_buy_shares {
                    shares_to_buy = max_buy_shares;
                }
                if shares_to_buy > 0 {
                    orders.submit_limit_buy(buy_price, shares_to_buy);
                }
            }
        }
    }
    
    if account.stock > 0 {
        let sell_price = round_to_dollar(market.vwap);
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, account.stock);
        }
    }
}