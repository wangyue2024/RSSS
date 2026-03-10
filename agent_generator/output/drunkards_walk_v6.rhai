let initialized = false;
let rng_state = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        rng_state = rng.rand_int(0, 99);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let dice = rng.rand_int(0, 99);
    
    if dice < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-10000, 10000);
        let raw_price = market.price + offset;
        let round_price = (raw_price / 1_000_000) * 1_000_000;
        let remainder = raw_price % 1_000_000;
        if remainder >= 500_000 {
            round_price = round_price + 1_000_000;
        } else if remainder <= -500_000 {
            round_price = round_price - 1_000_000;
        }
        let final_price = round_price + 1;
        orders.submit_limit_buy(final_price, qty);
    } else if dice > 95 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-10000, 10000);
        let raw_price = market.price + offset;
        let round_price = (raw_price / 1_000_000) * 1_000_000;
        let remainder = raw_price % 1_000_000;
        if remainder >= 500_000 {
            round_price = round_price + 1_000_000;
        } else if remainder <= -500_000 {
            round_price = round_price - 1_000_000;
        }
        let final_price = round_price + 1;
        orders.submit_limit_sell(final_price, qty);
    }
}