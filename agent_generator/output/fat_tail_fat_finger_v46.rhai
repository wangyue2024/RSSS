let initialized = false;
let lazy_interval = 50;
let stop_loss_threshold = 0;
let base_amount = 100;
let normal_bid_offset = -1000;
let normal_ask_offset = 1000;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(5000, 20000);
    }

    let pnl = account.unrealized_pnl;
    if pnl < 0 && abs_val(pnl) > stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if rng.rand_int(0, 9999) == 0 {
        if rng.rand_bool(50) {
            orders.submit_market_buy(base_amount * 100);
        } else {
            orders.submit_market_sell(base_amount * 100);
        }
    }

    if market.tick % lazy_interval == 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let mid_price = market.price;
        let bid_price = mid_price + normal_bid_offset + 1;
        let ask_price = mid_price + normal_ask_offset - 1;

        if bid_price > 0 {
            orders.submit_limit_buy(bid_price, base_amount);
        }
        if ask_price > 0 {
            orders.submit_limit_sell(ask_price, base_amount);
        }
    }
}