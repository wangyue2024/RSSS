let initialized = false;
let lot_size = 0;
let fomo_triggered = false;
let last_jump_tick = 0;
let short_window = 5;
let jump_threshold = 200;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(500_000_000, 2_000_000_000);
    }
    
    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() >= short_window {
        let past_price = market.history_price(short_window - 1);
        if past_price != 0 {
            let price_change = (market.price - past_price) * 10000 / past_price;
            if price_change > jump_threshold && !fomo_triggered {
                fomo_triggered = true;
                last_jump_tick = market.tick;
                let buy_amount = account.cash * 5000 / (market.price * 10000);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }

    if fomo_triggered && market.tick > last_jump_tick + 10 {
        fomo_triggered = false;
    }

    if fomo_triggered { return; }

    let inventory = account.stock;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    if mid_price == 0 { return; }

    let base_spread = 100;
    let inventory_skew = 0;

    if inventory > 1000 {
        inventory_skew = 50;
    } else if inventory <= 0 {
        inventory_skew = -50;
    }

    let buy_spread = base_spread - inventory_skew;
    let sell_spread = base_spread + inventory_skew;

    let buy_price = mid_price - (mid_price * buy_spread / 10000);
    let sell_price = mid_price + (mid_price * sell_spread / 10000);

    let max_buy_shares = account.cash * 5000 / (market.price * 10000);
    let buy_amount = max_buy_shares;
    if buy_amount > lot_size / market.price {
        buy_amount = lot_size / market.price;
    }
    if buy_amount > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }

    if account.stock > 0 && sell_price > account.avg_cost {
        let sell_amount = account.stock;
        if sell_amount > lot_size / market.price {
            sell_amount = lot_size / market.price;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}