let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
        let risk_pct = rng.rand_int(25, 50);
        let cash_for_trade = account.cash * risk_pct / 100;
        let est_shares = cash_for_trade / market.price;
        lot_size = if est_shares < 1 { 1 } else { est_shares };
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    
    let cross_up = prev_ma5 <= prev_ma20 && ma5 > ma20;
    let cross_down = prev_ma5 >= prev_ma20 && ma5 < ma20;
    
    if cross_up {
        let max_by_cash = account.cash / market.ask_price_0;
        let buy_amt = if max_by_cash < lot_size { max_by_cash } else { lot_size };
        if buy_amt > 0 {
            orders.submit_market_buy(buy_amt);
        }
    }
    
    if cross_down && account.stock > 0 && market.price > account.avg_cost {
        orders.submit_market_sell(account.stock);
    }
    
    prev_ma5 = ma5;
    prev_ma20 = ma20;
}