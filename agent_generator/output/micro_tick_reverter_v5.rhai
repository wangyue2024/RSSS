let initialized = false;
let last_price = 0;
let offset = 10_000;
let base_lot = 0;
let price_moved = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        base_lot = rng.rand_int(500_000_000, 1_000_000_000);
        return;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_moved = market.price != last_price;
    if price_moved {
        let max_share_from_cash = account.cash * 50 / 100 / market.price;
        let dynamic_lot = clamp_val(base_lot, 100, max_share_from_cash);
        
        if market.price > last_price {
            let sell_price = market.price + offset;
            let sell_amount = dynamic_lot;
            if sell_amount > 0 && account.stock >= sell_amount {
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        } else {
            let buy_price = market.price - offset;
            let buy_amount = dynamic_lot;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
    
    last_price = market.price;
}