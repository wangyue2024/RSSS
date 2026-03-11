let initialized = false;
let base_lot_size = 0;
let panic_threshold = 0;
let last_trade_loss = false;
let current_lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(20, 100);
        current_lot_size = base_lot_size;
        panic_threshold = -rng.rand_int(5000, 50000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        current_lot_size = base_lot_size;
        last_trade_loss = false;
        return;
    }

    let rsi = market.rsi_14;
    let price = market.price;
    let avg_cost = account.avg_cost;

    if rsi < 3000 && avg_cost > price {
        last_trade_loss = true;
    }

    if last_trade_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > 100 {
            current_lot_size = 100;
        }
    } else {
        current_lot_size = base_lot_size;
    }

    if rsi < 3000 {
        let buy_price = price - 10000;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, current_lot_size);
            last_trade_loss = false;
        }
    } else if rsi > 7000 && account.stock > 0 {
        let sell_size = if current_lot_size > account.stock { account.stock } else { current_lot_size };
        if sell_size > 0 {
            let sell_price = price + 10000;
            orders.submit_limit_sell(sell_price, sell_size);
            last_trade_loss = false;
        }
    }
}