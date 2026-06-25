let initialized = false;
let panic_threshold = 0;
let cluster_range = 0;
let sell_pct = 0;
let in_attack = false;
let attack_buy_price = 0;
let attack_buy_amount = 0;
let attack_sell_amount = 0;
let attack_ticks = 0;
let cooldown_ticks = 0;
let attack_max_ticks = 10;
let cooldown_max = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50_000, 200_000);
        cluster_range = rng.rand_int(10_000, 50_000);
        sell_pct = rng.rand_int(30, 80);
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        in_attack = false;
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        let price = my_orders.pending_price(i);
        let side = my_orders.pending_side(i);
        if in_attack && side == 0 && price == attack_buy_price {
            i += 1;
            continue;
        }
        orders.submit_cancel(oid);
        i += 1;
    }

    if cooldown_ticks > 0 {
        cooldown_ticks -= 1;
    }

    if in_attack {
        attack_ticks += 1;

        let fill_cnt = my_orders.fill_count();
        let j = 0;
        while j < fill_cnt {
            let fill_side = my_orders.fill_side(j);
            let fill_amount = my_orders.fill_amount(j);
            if fill_side == 0 {
                attack_buy_amount -= fill_amount;
            }
            j += 1;
        }

        if attack_buy_amount <= 0 {
            in_attack = false;
            cooldown_ticks = cooldown_max;
            return;
        }

        if attack_ticks >= attack_max_ticks {
            let pending_cnt2 = my_orders.pending_count();
            let k = 0;
            while k < pending_cnt2 {
                let price = my_orders.pending_price(k);
                let side = my_orders.pending_side(k);
                if side == 0 && price == attack_buy_price {
                    let oid = my_orders.pending_id(k);
                    orders.submit_cancel(oid);
                    break;
                }
                k += 1;
            }
            in_attack = false;
            cooldown_ticks = cooldown_max;
            return;
        }

        let has_pending_buy = false;
        let pending_cnt3 = my_orders.pending_count();
        let m = 0;
        while m < pending_cnt3 {
            let price = my_orders.pending_price(m);
            let side = my_orders.pending_side(m);
            if side == 0 && price == attack_buy_price {
                has_pending_buy = true;
                break;
            }
            m += 1;
        }
        if !has_pending_buy {
            orders.submit_limit_buy(attack_buy_price, attack_buy_amount);
        }
        return;
    }

    if cooldown_ticks > 0 || in_attack {
        return;
    }

    let low_20 = market.low_20;
    let diff = market.price - low_20;
    if diff > 0 && diff < cluster_range && account.stock > 0 {
        attack_sell_amount = (account.stock * sell_pct) / 100;
        if attack_sell_amount == 0 { return; }
        orders.submit_market_sell(attack_sell_amount);
        attack_buy_amount = attack_sell_amount;
        attack_buy_price = low_20 + 1;
        orders.submit_limit_buy(attack_buy_price, attack_buy_amount);
        attack_ticks = 0;
        in_attack = true;
    }
}