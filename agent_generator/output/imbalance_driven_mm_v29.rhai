let initialized = false;
let lot_size = 0;
let spread_factor = 0;
let imbalance_sensitivity = 0;
let pos_limit = 0;
let base_spread = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let cash_quarter = account.cash / 4;
        let price = market.price;
        if price > 0 {
            let max_shares = cash_quarter / price;
            lot_size = rng.rand_int(max_shares / 2, max_shares);
        } else {
            lot_size = rng.rand_int(1000, 5000);
        }
        spread_factor = rng.rand_int(2000, 8000);
        imbalance_sensitivity = rng.rand_int(500, 3000);
        pos_limit = rng.rand_int(100000, 300000);
        base_spread = rng.rand_int(10000, 50000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    let price_adj = (imbalance * imbalance_sensitivity) / 10000;
    let mid_price = market.price + price_adj;
    
    let spread = base_spread + (abs_val(imbalance) * spread_factor) / 10000;
    let bid_price = mid_price - spread / 2;
    let ask_price = mid_price + spread / 2;
    
    if account.stock < pos_limit {
        let buy_amt = lot_size;
        if buy_amt * bid_price <= account.cash {
            orders.submit_limit_buy(bid_price, buy_amt);
        }
    }
    
    if account.stock > -pos_limit {
        let sell_amt = lot_size;
        if sell_amt <= account.stock {
            orders.submit_limit_sell(ask_price, sell_amt);
        }
    }
}