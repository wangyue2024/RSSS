let initialized = false;
let last_prices = [];
let fomo_triggered = false;
let cluster_threshold = 1000;
let sell_volume = 100;

fn round_price(p) {
    let remainder = p % 1_000_000;
    if remainder >= 500_000 {
        p - remainder + 1_000_000
    } else {
        p - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        cluster_threshold = rng.rand_int(800, 1200);
        sell_volume = rng.rand_int(80, 120);
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;

    last_prices.push(current_price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }

    let count_pending = my_orders.pending_count();
    let i = 0;
    while i < count_pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if last_prices.len() == 5 {
        let old_price = last_prices[0];
        let change_percent_10k = (current_price - old_price) * 10000 / old_price;
        if change_percent_10k > 200 || change_percent_10k < -200 {
            let buy_amount = account.cash / current_price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            fomo_triggered = true;
            return;
        }
    }
    fomo_triggered = false;

    let cluster_volume = 0;
    let lowest_bid_price = 0;

    let bid_price_0 = market.bid_price_0;
    let bid_price_1 = market.bid_price_1;
    let bid_price_2 = market.bid_price_2;

    if bid_price_0 > 0 && current_price - bid_price_0 <= current_price / 100 {
        cluster_volume += market.bid_vol_0;
        lowest_bid_price = bid_price_0;
    }
    if bid_price_1 > 0 && current_price - bid_price_1 <= current_price / 100 {
        cluster_volume += market.bid_vol_1;
        if lowest_bid_price == 0 || bid_price_1 < lowest_bid_price {
            lowest_bid_price = bid_price_1;
        }
    }
    if bid_price_2 > 0 && current_price - bid_price_2 <= current_price / 100 {
        cluster_volume += market.bid_vol_2;
        if lowest_bid_price == 0 || bid_price_2 < lowest_bid_price {
            lowest_bid_price = bid_price_2;
        }
    }

    if cluster_volume >= cluster_threshold && lowest_bid_price > 0 {
        if account.stock >= sell_volume {
            orders.submit_market_sell(sell_volume);
        }
        let buy_price = lowest_bid_price - lowest_bid_price / 200;
        let rounded_buy_price = round_price(buy_price);
        let buy_amount = sell_volume;
        if account.cash >= rounded_buy_price * buy_amount {
            orders.submit_limit_buy(rounded_buy_price, buy_amount);
        }
    }
}