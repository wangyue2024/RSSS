let initialized = false;
let oversold_rsi = 3000;
let overbought_rsi = 7000;
let trade_size = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.rsi_14 < oversold_rsi {
        let buy_price = market.price * 99 / 100 + 1;
        if buy_price > 0 && account.cash >= buy_price * trade_size {
            orders.submit_limit_buy(buy_price, trade_size);
        }
    } else if market.rsi_14 > overbought_rsi && account.stock >= trade_size {
        let sell_price = market.price * 101 / 100 + 1;
        orders.submit_limit_sell(sell_price, trade_size);
    }
}