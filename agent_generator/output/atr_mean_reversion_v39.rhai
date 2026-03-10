let initialized = false;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(100_000, 250_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < 0 && abs_val(account.unrealized_pnl) > stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let price = market.price;
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    
    if atr == 0 { return; }
    
    let deviation = price - ma20;
    let atr_1_5 = atr * 150 / 100;
    
    if deviation > atr_1_5 {
        let sell_amount = account.stock * 5000 / 10000;
        if sell_amount > 0 {
            let target_price = ma20 + atr_1_5;
            orders.submit_limit_sell(target_price, sell_amount);
        }
    } else if deviation < -atr_1_5 {
        let buy_value = account.cash * 5000 / 10000;
        if buy_value > 0 {
            let target_price = ma20 - atr_1_5;
            let buy_amount = buy_value / target_price;
            if buy_amount > 0 {
                orders.submit_limit_buy(target_price, buy_amount);
            }
        }
    }
}