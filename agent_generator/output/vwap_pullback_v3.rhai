let initialized = false;
let risk_percent = 0;
let lot_size = 0;
let last_trade_loss = false;
let vwap_threshold = 0;
let last_buy_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(30, 50);
        vwap_threshold = rng.rand_int(100, 300);
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
    
    if last_trade_loss {
        lot_size = lot_size * 2;
    } else {
        let cash_for_trade = account.cash * risk_percent / 100;
        let shares_possible = cash_for_trade / market.price;
        if shares_possible > 0 {
            lot_size = shares_possible;
        } else {
            lot_size = 1;
        }
    }
    
    let current_price = market.price;
    let vwap = market.vwap;
    let price_below_vwap = vwap - current_price;
    let threshold_amount = vwap * vwap_threshold / 10000;
    
    let position = account.stock;
    let avg_cost = account.avg_cost;
    
    if position == 0 {
        if price_below_vwap > threshold_amount {
            let buy_price = current_price;
            orders.submit_limit_buy(buy_price, lot_size);
            last_buy_price = buy_price;
            last_trade_loss = false;
        }
    } else {
        if current_price >= vwap {
            orders.submit_market_sell(position);
            if current_price < avg_cost {
                last_trade_loss = true;
            } else {
                last_trade_loss = false;
            }
        } else if current_price < last_buy_price * 95 / 100 {
            orders.submit_market_sell(position);
            last_trade_loss = true;
        }
    }
}