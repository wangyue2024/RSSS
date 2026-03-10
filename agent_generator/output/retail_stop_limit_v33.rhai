let initialized = false;
let in_position = false;
let sl_price = 0;
let tp_price = 0;
let lot_size = 100;
let panic_threshold = -500000;
let last_trade_loss = false;

fn on_tick() {
    if !initialized {
        panic_threshold = rng.rand_int(-1000000, -200000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if in_position {
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            in_position = false;
            if account.unrealized_pnl < 0 {
                last_trade_loss = true;
            }
            return;
        }

        if market.price <= sl_price {
            orders.submit_market_sell(account.stock);
            in_position = false;
            last_trade_loss = true;
            return;
        }

        if market.price >= tp_price {
            orders.submit_limit_sell(tp_price, account.stock);
            return;
        }
    } else {
        if account.stock == 0 {
            if rng.rand_bool(1) {
                if last_trade_loss {
                    lot_size = lot_size * 2;
                }
                let cost = market.price;
                sl_price = cost * 98 / 100;
                tp_price = cost * 105 / 100;
                orders.submit_market_buy(lot_size);
                in_position = true;
                last_trade_loss = false;
            }
        }
    }
}