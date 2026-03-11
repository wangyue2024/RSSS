let initialized = false;
let fair_value = 0;
let buy_small_amount = 10;
let buy_aggro_amount = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let curr_price = market.price;
    
    if curr_price < fair_value {
        let amount = 0;
        if curr_price < fair_value * 90 / 100 {
            amount = buy_aggro_amount;
        } else if curr_price < fair_value * 95 / 100 {
            amount = buy_small_amount;
        }
        if amount > 0 && account.cash >= curr_price * amount {
            orders.submit_limit_buy(curr_price, amount);
        }
    }
    
    if account.stock > 0 && curr_price > account.avg_cost && curr_price > fair_value {
        let sell_price = max(account.avg_cost * 101 / 100, fair_value);
        if sell_price <= curr_price {
            sell_price = curr_price;
        }
        orders.submit_limit_sell(sell_price, account.stock);
    }
}