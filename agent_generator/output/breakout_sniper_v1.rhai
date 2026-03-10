let initialized = false;
let base_lot = 100;
let current_lot = 100;
let stop_loss_ticks = 5;
let tick_size = 10000;
let in_position = false;
let avg_entry = 0;
let last_trade_profit = 0;
let waiting_for_fill = false;
let pending_buy_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(80, 120);
        current_lot = base_lot;
        stop_loss_ticks = rng.rand_int(3, 8);
    }

    if !market.trading_enabled { return; }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fills = my_orders.fill_count();
    if fills > 0 && waiting_for_fill {
        let net_buy = 0;
        let total_cost = 0;
        let j = 0;
        while j < fills {
            let side = my_orders.fill_side(j);
            let amt = my_orders.fill_amount(j);
            let px = my_orders.fill_price(j);
            if side == 0 {
                net_buy += amt;
                total_cost += px * amt;
            } else {
                net_buy -= amt;
                let exit_value = px * amt;
                let entry_value = avg_entry * amt;
                last_trade_profit = exit_value - entry_value;
                if last_trade_profit < 0 {
                    current_lot = current_lot * 2;
                } else {
                    current_lot = base_lot;
                }
            }
            j += 1;
        }
        if net_buy > 0 {
            avg_entry = total_cost / net_buy;
            in_position = true;
        }
        waiting_for_fill = false;
        pending_buy_id = -1;
    }

    if in_position {
        let stop_level = avg_entry - stop_loss_ticks * tick_size;
        if market.price <= stop_level && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            in_position = false;
            avg_entry = 0;
        }
    } else {
        if market.price > market.high_20 && !waiting_for_fill {
            let buy_price = market.ask_price_0 + tick_size;
            orders.submit_limit_buy(buy_price, current_lot);
            waiting_for_fill = true;
        }
    }
}