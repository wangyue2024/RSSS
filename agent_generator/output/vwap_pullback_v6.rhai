let initialized = false;
let threshold_bp = 0;
let order_size = 0;

fn on_tick() {
    if !initialized {
        threshold_bp = rng.rand_int(30, 70);
        order_size = rng.rand_int(10, 30);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vwap = market.vwap;
    let price = market.price;
    let pos = account.stock;
    let cash = account.cash;
    
    if pos == 0 && cash > 0 {
        let max_buy_price = vwap * (10000 - threshold_bp) / 10000;
        if price < max_buy_price {
            let bid = market.bid_price_0 + 1;
            let adj_bid = if bid > max_buy_price { max_buy_price } else { bid };
            let max_shares = cash / adj_bid;
            let shares = if max_shares < order_size { max_shares } else { order_size };
            if shares > 0 {
                orders.submit_limit_buy(adj_bid, shares);
            }
        }
    } else if pos > 0 {
        let ask = market.ask_price_0;
        if ask >= vwap {
            orders.submit_limit_sell(vwap, pos);
        }
    }
}