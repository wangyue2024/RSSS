let initialized = false;
let THRESHOLD_BP = 150;
let BUY_AMOUNT = 100;
let base_sell_price = 0;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap_minus_threshold = market.vwap - (market.vwap * THRESHOLD_BP / 10000);
    
    if account.stock == 0 && market.price < vwap_minus_threshold {
        let buy_price_rounded = round_to_dollar(market.price);
        if buy_price_rounded > 0 {
            let max_affordable = account.cash / buy_price_rounded;
            let buy_qty = if max_affordable < BUY_AMOUNT { max_affordable } else { BUY_AMOUNT };
            if buy_qty > 0 {
                orders.submit_limit_buy(buy_price_rounded, buy_qty);
            }
        }
    } else if account.stock > 0 {
        if base_sell_price == 0 {
            base_sell_price = round_to_dollar(market.vwap);
        }
        
        let sell_price_rounded = base_sell_price;
        
        if market.price >= market.vwap {
            orders.submit_limit_sell(sell_price_rounded, account.stock);
            base_sell_price = 0;
        }
    } else {
        base_sell_price = 0;
    }
}