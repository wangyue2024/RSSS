let initialized = false;
let panic_threshold = 0;
let order_placed_tick = -1;
let current_order_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10000, 50000);
    }

    if !market.trading_enabled { return; }

    let pnl = account.unrealized_pnl;
    let stock = account.stock;

    if pnl < panic_threshold && stock != 0 {
        if stock > 0 {
            orders.submit_market_sell(stock);
        } else {
            orders.submit_market_buy(-stock);
        }
        order_placed_tick = -1;
        current_order_id = -1;
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if current_order_id != -1 {
        if market.tick - order_placed_tick >= 3 {
            current_order_id = -1;
            order_placed_tick = -1;
        }
    }

    if current_order_id == -1 && market.high_20 > market.ma_60 && market.volume < 1000 {
        let sell_price = market.bid_price_0;
        let sell_amount = 100;
        if sell_price > 0 && sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
            current_order_id = 0;
            order_placed_tick = market.tick;
        }
    }
}