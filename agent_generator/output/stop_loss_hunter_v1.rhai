let initialized = false;
let hunting = false;
let short_price = 0;
let target_price = 0;
let stop_loss_price = 0;
let attack_size = 0;
let ticks_in_hunt = 0;

let cluster_distance = 5000;
let min_cluster_vol = 25000;
let profit_target = 2500;
let max_hunt_ticks = 10;
let stop_buffer = 3000;

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_distance = rng.rand_int(3000, 8000);
        min_cluster_vol = rng.rand_int(20000, 50000);
        profit_target = rng.rand_int(1500, 4000);
        max_hunt_ticks = rng.rand_int(8, 15);
        stop_buffer = rng.rand_int(2000, 5000);
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if hunting {
        ticks_in_hunt += 1;

        if market.price <= target_price && account.stock < 0 {
            let cover_amount = -account.stock;
            if cover_amount > 0 {
                orders.submit_limit_buy(market.price + 1, cover_amount);
            }
            hunting = false;
            ticks_in_hunt = 0;
        } else if market.price >= stop_loss_price && account.stock < 0 {
            let cover_amount = -account.stock;
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
            }
            hunting = false;
            ticks_in_hunt = 0;
        } else if ticks_in_hunt > max_hunt_ticks {
            if account.stock < 0 {
                let cover_amount = -account.stock;
                if cover_amount > 0 {
                    orders.submit_market_buy(cover_amount);
                }
            }
            hunting = false;
            ticks_in_hunt = 0;
        }
        return;
    }

    if account.stock != 0 { return; }

    let cluster_vol = 0;
    let cluster_level = 0;
    let current = market.price;

    if market.bid_price_0 > 0 && (current - market.bid_price_0) < cluster_distance && market.bid_vol_0 > min_cluster_vol {
        cluster_vol += market.bid_vol_0;
        cluster_level = market.bid_price_0;
    }

    if cluster_vol == 0 { return; }

    let cash_for_attack = account.cash * 60 / 100;
    let shares_to_short = cash_for_attack / current;
    if shares_to_short < 100 { return; }

    attack_size = shares_to_short;
    let sell_price = cluster_level - 1;
    short_price = current;
    target_price = cluster_level - profit_target;
    stop_loss_price = current + stop_buffer;
    ticks_in_hunt = 0;

    orders.submit_limit_sell(sell_price, attack_size);
    hunting = true;
}