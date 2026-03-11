let initialized = false;
let base_lot = 100;
let current_lot = 100;
let panic_threshold = -50000;
let last_trade_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10000, 100000);
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if account.stock > 0 && market.price < account.avg_cost {
        last_trade_loss = true;
    } else {
        last_trade_loss = false;
    }

    if last_trade_loss {
        current_lot = base_lot * 2;
    } else {
        current_lot = base_lot;
    }

    let spread = market.high_20 - market.low_20;
    let min_spread = 20000;
    if spread < min_spread {
        current_lot = current_lot * 2;
    }

    if market.high_20 > market.low_20 {
        let buy_offset = 5000;
        let sell_offset = 5000;
        let buy_price = market.low_20 + buy_offset;
        let sell_price = market.high_20 - sell_offset;

        if buy_price < sell_price {
            if account.cash >= buy_price * current_lot {
                orders.submit_limit_buy(buy_price, current_lot);
            }
            if account.stock >= current_lot {
                orders.submit_limit_sell(sell_price, current_lot);
            }
        }
    }
}