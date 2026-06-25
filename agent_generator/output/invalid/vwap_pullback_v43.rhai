let initialized = false;
let threshold_bp = 200;
let trade_size = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_bp = rng.rand_int(150, 300);
        trade_size = rng.rand_int(800, 1200);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let vwap = market.vwap;
    let price = market.price;
    let can_buy = account.cash > price * trade_size;
    let can_sell = account.stock > 0 && price > account.avg_cost;

    if price > 0 && vwap > 0 {
        let price_below_vwap_pct = (vwap - price) * 10000 / vwap;

        if price_below_vwap_pct > threshold_bp && can_buy {
            let buy_price = price;
            orders.submit_limit_buy(buy_price, trade_size);
        }

        if price >= vwap && can_sell {
            let sell_amount = if account.stock > trade_size { trade_size } else { account.stock };
            let sell_price = price;
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}