let initialized = false;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;
let open_side = 0;
let open_avg_cost = 0;

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

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    if open_side == -1 && account.stock < 0 {
        if market.price > open_avg_cost * 101 / 100 {
            let amount_to_buy = -account.stock;
            orders.submit_market_buy(amount_to_buy);
            last_trade_was_loss = market.price > open_avg_cost;
            open_side = 0;
            open_avg_cost = 0;
        }
    }

    if open_side == 0 {
        let price_above_ma = market.price > market.ma_60;
        let vol_drop = false;

        let lookback = 20;
        if market.history_len() >= lookback {
            let volumes = [];
            let j = 0;
            while j < lookback {
                volumes.push(market.history_volume(market.history_len() - 1 - j));
                j += 1;
            }
            let avg_vol = arr_mean(volumes);
            vol_drop = market.volume < avg_vol * 10 / 100;
        }

        if price_above_ma && vol_drop {
            current_lot_size = base_lot_size;
            if last_trade_was_loss {
                current_lot_size = current_lot_size * 2;
            }
            last_trade_was_loss = false;

            orders.submit_market_sell(current_lot_size);

            open_side = -1;
            open_avg_cost = market.price;
        }
    }
}