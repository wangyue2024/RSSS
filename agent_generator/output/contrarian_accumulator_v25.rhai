let initialized = false;
let base_order_size = 0;
let panic_threshold = 0;
let buy_order_lifespan = 3;
let max_order_age = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(20, 100);
        panic_threshold = -rng.rand_int(50_000, 200_000);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let i = 0;
    let pending_cnt = my_orders.pending_count();
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let rsi = market.rsi_14;
    let current_price = market.price;
    let avg_cost = account.avg_cost;

    if rsi < 3000 {
        let buy_amount = base_order_size;
        if buy_amount <= 0 { return; }
        let max_spend = account.cash;
        if max_spend <= 0 { return; }

        let limit_price = current_price * 995 / 1000;
        let estimated_cost = limit_price * buy_amount / 1_000_000;
        if estimated_cost * 1_000_000 <= max_spend {
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    } else if rsi > 7000 && current_price > avg_cost && account.stock > 0 {
        let sell_amount = base_order_size;
        if sell_amount <= 0 { return; }
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }

        let limit_price = current_price * 1005 / 1000;
        orders.submit_limit_sell(limit_price, sell_amount);
    }
}