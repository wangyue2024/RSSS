let initialized = false;
let threshold = 5000;
let position_size = 100;

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

    if account.stock <= 0 {
        if market.price < market.vwap - threshold {
            let base_bid = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price };
            let bid_price = base_bid + 1;
            if account.cash >= bid_price * position_size {
                orders.submit_limit_buy(bid_price, position_size);
            }
        }
    } else {
        if market.price >= market.vwap {
            orders.submit_limit_sell(market.vwap, account.stock);
        }
    }
}