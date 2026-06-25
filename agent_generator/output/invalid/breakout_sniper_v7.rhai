let initialized = false;
let last_trade_loss = false;
let base_lot_size = 100;
let current_lot_multiplier = 1;
let delayed_prices = [];
let delayed_highs = [];
let last_evaluation_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot_multiplier = 1;
        last_trade_loss = false;
        last_evaluation_tick = market.tick - 50;
    }

    if !market.trading_enabled { return; }

    delayed_prices.push(market.price);
    delayed_highs.push(market.high_20);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
        delayed_highs.remove(0);
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 1 {
            let fill_price = my_orders.fill_price(i);
            if account.avg_cost > 0 && fill_price < account.avg_cost {
                last_trade_loss = true;
                current_lot_multiplier = current_lot_multiplier * 2;
            } else {
                last_trade_loss = false;
                current_lot_multiplier = 1;
            }
        }
        i += 1;
    }

    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    if market.tick - last_evaluation_tick >= 50 && delayed_prices.len() >= 5 {
        last_evaluation_tick = market.tick;
        
        let old_price = delayed_prices[0];
        let old_high = delayed_highs[0];
        
        if account.stock == 0 && old_price > old_high {
            let trade_size = base_lot_size * current_lot_multiplier;
            if trade_size > 0 {
                orders.submit_market_buy(trade_size);
            }
        }
        
        if account.stock > 0 && account.avg_cost > 0 {
            let stop_price = account.avg_cost - micros(0, 5);
            if market.price <= stop_price {
                orders.submit_market_sell(account.stock);
            }
        }
    }
}