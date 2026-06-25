let initialized = false;
let fair_value_micros = 0;
let base_lot_size = 0;
let aggressive_multiplier = 0;
let small_multiplier = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_micros = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        base_lot_size = rng.rand_int(500, 2000);
        aggressive_multiplier = rng.rand_int(3, 5);
        small_multiplier = rng.rand_int(1, 2);
        price_history = [];
    }
    
    if !market.trading_enabled { return; }
    
    let count_pending = my_orders.pending_count();
    let i = 0;
    while i < count_pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 && !fomo_triggered {
        let old_price = price_history[0];
        if old_price > 0 {
            let change_pct = (market.price - old_price) * 10000 / old_price;
            if change_pct > 200 {
                fomo_triggered = true;
                let buy_amount = account.cash * 50 / (100 * market.price);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    if market.price > fair_value_micros {
        let sell_amount_small = base_lot_size * small_multiplier;
        let sell_amount_aggressive = base_lot_size * aggressive_multiplier;
        
        if account.stock > 0 {
            if market.price > fair_value_micros * 110 / 100 {
                let amount = sell_amount_aggressive;
                if amount > account.stock {
                    amount = account.stock;
                }
                if amount > 0 {
                    orders.submit_limit_sell(market.price, amount);
                }
            } else if market.price > fair_value_micros * 105 / 100 {
                let amount = sell_amount_small;
                if amount > account.stock {
                    amount = account.stock;
                }
                if amount > 0 {
                    orders.submit_limit_sell(market.price, amount);
                }
            }
        }
    }
}