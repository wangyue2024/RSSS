// ═══════════════════════════════════════════════════
// 噪声交易者 (Noise Trader)
// 随机买卖, 模拟散户和非理性交易行为
// 为市场提供噪声流动性, 使价格产生波动
// ═══════════════════════════════════════════════════

let my_prob = rand_int(rng, 5, 20);    // 每 Tick 交易概率 5%~20%
let my_size = rand_int(rng, 1, 5);     // 小额交易量

fn on_tick() {
    if !market.trading_enabled { return; }

    // 以一定概率触发交易
    let do_trade = rand_bool(rng, my_prob);
    if !do_trade { return; }

    // 随机价格偏移
    let offset = rand_int(rng, -300_000, 300_000);
    let px = market.price + offset;
    if px <= 0 { return; }

    // 随机方向: true=买, false=卖
    let buy = rand_bool(rng, 50);

    if buy {
        if account.cash > px * my_size {
            orders.submit_limit_buy(px, my_size);
        }
    } else {
        if account.stock >= my_size {
            orders.submit_limit_sell(px, my_size);
        }
    }
}
