let initialized = false;
let total_to_sell = 0;
let iceberg_lot = 0;
let remaining_shares = 0;
let last_order_filled = false;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_factor = rng.rand_int(30, 50);
        total_to_sell = account.stock * risk_factor / 100;
        iceberg_lot = max(1, total_to_sell * 5 / 1000);
        remaining_shares = total_to_sell;
        price_history = [];
        let i = 0;
        while i < 20 {
            price_history.push(market.price);
            i += 1;
        }
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 20 {
        price_history.remove(0);
    }

    if price_history.len() >= 5 {
        let recent_jump = (market.price - price_history[price_history.len() - 5]) * 100 / price_history[price_history.len() - 5];
        if recent_jump > 2 {
            fomo_triggered = true;
        }
    }

    if fomo_triggered {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        let risk_bet = rng.rand_int(30, 50);
        let buy_amount = account.cash * risk_bet / (100 * market.price);
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }

    last_order_filled = false;
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 1 {
            last_order_filled = true;
            let fill_amt = my_orders.fill_amount(i);
            remaining_shares = remaining_shares - fill_amt;
        }
        i += 1;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if remaining_shares <= 0 { return; }

    if market.ask_price_0 > 0 && remaining_shares > 0 {
        let raw_price = market.ask_price_0;
        let remainder = raw_price % 1_000_000;
        let rounded_price = if remainder >= 500_000 {
            raw_price + (1_000_000 - remainder)
        } else {
            raw_price - remainder
        };
        
        let order_amount = if iceberg_lot > remaining_shares { remaining_shares } else { iceberg_lot };
        if order_amount > 0 {
            orders.submit_limit_sell(rounded_price, order_amount);
        }
    }
}