let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_loss = false;
let panic_threshold = 0;
let vwap_dip_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(100, 500);
        current_lot_size = base_lot_size;
        last_trade_loss = false;
        panic_threshold = rng.rand_int(-500000, -100000);
        vwap_dip_threshold = rng.rand_int(100, 500);
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
        last_trade_loss = true;
        return;
    }

    if account.stock > 0 {
        let sell_condition = market.price >= market.vwap;
        if sell_condition {
            orders.submit_market_sell(account.stock);
            if market.price < account.avg_cost {
                last_trade_loss = true;
            } else {
                last_trade_loss = false;
            }
        }
    } else {
        if last_trade_loss {
            current_lot_size = current_lot_size * 2;
            if current_lot_size > 5000 {
                current_lot_size = 5000;
            }
        } else {
            current_lot_size = base_lot_size;
        }

        let buy_condition = market.price <= (market.vwap * (10000 - vwap_dip_threshold) / 10000);
        if buy_condition && current_lot_size > 0 {
            let amount = current_lot_size;
            if amount * market.price <= account.cash {
                orders.submit_limit_buy(market.price, amount);
            }
        }
    }
}