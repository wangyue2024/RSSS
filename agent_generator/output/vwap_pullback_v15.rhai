let initialized = false;
let trade_size = 0;
let entry_threshold = 0;
let round_mod = 1_000_000;

fn round_price(p) {
    let remainder = p % round_mod;
    if remainder >= 500_000 {
        p - remainder + round_mod
    } else {
        p - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_size = rng.rand_int(50, 200);
        entry_threshold = rng.rand_int(100, 300);
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock == 0 && market.vwap > 0 {
        let threshold_price = market.vwap * (10000 - entry_threshold) / 10000;
        if market.price < threshold_price {
            let buy_price = round_price(market.price);
            if buy_price > 0 && account.cash >= buy_price * trade_size {
                orders.submit_limit_buy(buy_price, trade_size);
            }
        }
    } else if account.stock > 0 {
        if market.price >= market.vwap {
            let sell_price = round_price(market.price);
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, account.stock);
            }
        } else {
            let stop_price = round_price(account.avg_cost * 9900 / 10000);
            if market.price <= stop_price && stop_price > 0 {
                orders.submit_limit_sell(stop_price, account.stock);
            }
        }
    }
}