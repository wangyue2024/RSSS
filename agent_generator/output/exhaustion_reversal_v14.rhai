let initialized = false;
let volume_threshold = 1000;
let order_size = 100;
let profit_target_bps = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock < 0 {
        let short_avg = account.avg_cost;
        let exit_price = short_avg - (short_avg * profit_target_bps) / 10000;
        if market.price <= exit_price {
            let cover_amount = -account.stock;
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
            }
        }
        return;
    }

    let exhaustion = market.price > market.ma_60 && market.volume < volume_threshold;
    let allowed_to_sell = market.price > account.avg_cost;

    if exhaustion && allowed_to_sell {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        } else if account.stock == 0 {
            orders.submit_market_sell(order_size);
        }
    }
}