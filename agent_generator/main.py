import asyncio
import os
import random
import subprocess
import sys
import yaml
from openai import AsyncOpenAI
from validator import sanitize_and_validate

# ================= Configuration =================
API_KEYS = [
    "sk-f821eb49980442acb3e32e3e62965341",
    "sk-8406640cfe8949528f3b6c93a218d0aa",
    "sk-bd4e8057f3734acebf50c9d679728a52",
    "sk-020b425f31b24de7aab713b3b164f6a1",
    "sk-1417d558ac684c6484e824716fc16680",
]
BASE_URL = "https://api.deepseek.com"
MODEL_NAME = "deepseek-reasoner"

# 多 Client 轮询，分散 rate limit 压力
CLIENTS = [AsyncOpenAI(api_key=k, base_url=BASE_URL) for k in API_KEYS]
_client_counter = 0

def next_client() -> AsyncOpenAI:
    global _client_counter
    c = CLIENTS[_client_counter % len(CLIENTS)]
    _client_counter += 1
    return c

# Directories
PROMPTS_DIR = "prompts"
OUTPUT_DIR = "output"

# Rust 校验二进制路径 (自动探测 release/debug)
RSSS_BIN = None
for candidate in [
    os.path.join("..", "target", "release", "rsss.exe"),
    os.path.join("..", "target", "debug", "rsss.exe"),
    os.path.join("..", "target", "release", "rsss"),
    os.path.join("..", "target", "debug", "rsss"),
]:
    if os.path.isfile(candidate):
        RSSS_BIN = os.path.abspath(candidate)
        break

os.makedirs(OUTPUT_DIR, exist_ok=True)

# 并发控制
MAX_CONCURRENT = 50
SEM = asyncio.Semaphore(MAX_CONCURRENT)

# 重试次数 (Python预筛 + Rust校验 共用)
MAX_RETRIES = 5

# 变体数
VARIANTS_PER_STRATEGY = 50  # 20 strategies * 50 = 1000 agents

# ================= Rust Validation =================
def rust_validate(filepath: str) -> tuple[bool, str]:
    """
    调用 rsss --validate <file> 进行 Rhai 编译 + 沙盒试跑校验。
    Returns: (is_valid, error_message)
    """
    if RSSS_BIN is None:
        return True, ""  # 未找到二进制，跳过 Rust 校验

    try:
        result = subprocess.run(
            [RSSS_BIN, "--validate", filepath],
            capture_output=True, text=True, timeout=30
        )
        stdout = result.stdout.strip()
        if result.returncode == 0 and "OK:" in stdout:
            return True, ""
        # 提取错误信息
        error_lines = [l for l in stdout.split("\n") if l.startswith("ERROR:")]
        error_msg = error_lines[0] if error_lines else f"Rust validation failed (exit={result.returncode})"
        return False, error_msg
    except subprocess.TimeoutExpired:
        return False, "Rust validation timed out (>30s)"
    except Exception as e:
        return False, f"Rust validation subprocess error: {e}"

# ================= Core Generator Task =================
async def generate_agent_script(
    strategy_name: str,
    strategy_desc: str,
    traits: list[str],
    system_prompt: str,
    variant_idx: int,
) -> tuple[str, int, str, bool]:
    """
    生成单个 Rhai agent 脚本，包含:
    1. LLM 生成
    2. Python 正则预筛
    3. Rust 编译+试跑校验
    4. 错误反馈重试
    """
    async with SEM:
        filename = f"{strategy_name}_v{variant_idx}.rhai"
        filepath = os.path.join(OUTPUT_DIR, filename)

        base_user_prompt = f"Strategy Name: {strategy_name}\n\nDescription: {strategy_desc}\n\n"
        base_user_prompt += "Personality & Quirk Constraints:\n"
        for t in traits:
            base_user_prompt += f"- {t}\n"
        base_user_prompt += "\nRead the SYSTEM PROMPT closely. Please output the raw Rhai script now."

        current_prompt = base_user_prompt
        last_error = "unknown"
        last_code = ""

        for attempt in range(MAX_RETRIES):
            if attempt > 0:
                print(f"  [RETRY {attempt}/{MAX_RETRIES}] {filename}")

            try:
                client = next_client()
                response = await client.chat.completions.create(
                    model=MODEL_NAME,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": current_prompt},
                    ],
                    temperature=0.8,
                )
                raw_code = response.choices[0].message.content
            except Exception as e:
                print(f"  [!] API Error on {filename} attempt {attempt}: {e}")
                last_error = f"API error: {e}"
                await asyncio.sleep(3)
                continue

            # Layer 1: Python 正则预筛
            is_valid, cleaned_code, reason = sanitize_and_validate(raw_code)
            last_code = cleaned_code
            if not is_valid:
                print(f"  [X] Python validation failed for {filename}: {reason}")
                last_error = reason
                current_prompt = (
                    base_user_prompt
                    + f"\n\nYOUR PREVIOUS ATTEMPT FAILED. ERROR: {reason}\n"
                    + "Fix the error and generate the corrected Rhai script."
                )
                continue

            # Layer 2: Rust 编译+沙盒试跑校验
            # 先保存到临时文件
            tmp_path = filepath + ".tmp"
            with open(tmp_path, "w", encoding="utf-8") as f:
                f.write(cleaned_code)

            rust_ok, rust_error = rust_validate(tmp_path)

            if rust_ok:
                # 两层都通过，重命名为正式文件
                os.replace(tmp_path, filepath)
                print(f"  [OK] {filename}")
                return strategy_name, variant_idx, cleaned_code, True
            else:
                # Rust 校验失败，将错误反馈给 LLM
                os.remove(tmp_path)
                print(f"  [X] Rust validation failed for {filename}: {rust_error}")
                last_error = rust_error
                current_prompt = (
                    base_user_prompt
                    + f"\n\nYOUR PREVIOUS ATTEMPT FAILED RUST COMPILATION/RUNTIME CHECK.\n"
                    + f"RUST ERROR: {rust_error}\n"
                    + "Fix the error and generate the corrected Rhai script."
                )
                continue

        # 耗尽重试
        print(f"  [FAIL] {filename} after {MAX_RETRIES} retries")
        fail_path = os.path.join(OUTPUT_DIR, f"INVALID_{filename}")
        with open(fail_path, "w", encoding="utf-8") as f:
            f.write(f"// Generation Failed after {MAX_RETRIES} retries.\n")
            f.write(f"// Last error: {last_error}\n")
            f.write(last_code)
        return strategy_name, variant_idx, last_code, False

# ================= Orchestrator =================
async def main():
    print("=" * 50)
    print("RSSS Agent Generator v2.0")
    print("=" * 50)

    if RSSS_BIN:
        print(f"Rust validator: {RSSS_BIN}")
    else:
        print("WARNING: Rust binary not found, skipping Rust validation.")
        print("         Run `cargo build --release` first for full validation.")

    # 加载配置
    try:
        with open(os.path.join(PROMPTS_DIR, "system_base.txt"), encoding="utf-8") as f:
            system_prompt = f.read()
        with open(os.path.join(PROMPTS_DIR, "strategies.yaml"), encoding="utf-8") as f:
            strategies = yaml.safe_load(f).get("strategies", [])
        with open(os.path.join(PROMPTS_DIR, "traits.yaml"), encoding="utf-8") as f:
            all_traits = yaml.safe_load(f).get("traits", [])
    except Exception as e:
        print(f"Failed to load prompt files: {e}")
        return

    print(f"Strategies: {len(strategies)}, Traits: {len(all_traits)}")
    print(f"Variants per strategy: {VARIANTS_PER_STRATEGY}")
    print(f"Target total: {len(strategies) * VARIANTS_PER_STRATEGY}")
    print(f"Max concurrent API calls: {MAX_CONCURRENT}")
    print()

    # 构建任务列表 (增量生成: 跳过已存在的)
    tasks = []
    skipped = 0
    for strategy in strategies:
        for i in range(VARIANTS_PER_STRATEGY):
            filename = f"{strategy['name']}_v{i}.rhai"
            filepath = os.path.join(OUTPUT_DIR, filename)
            if os.path.exists(filepath):
                skipped += 1
                continue
            num_traits = random.randint(1, 3)
            selected_traits = random.sample(all_traits, k=min(num_traits, len(all_traits)))
            tasks.append((strategy["name"], i, strategy["desc"], selected_traits))

    if skipped:
        print(f"Skipped {skipped} already generated scripts.")

    total_target = len(tasks)
    if total_target == 0:
        print("All scripts already generated. Nothing to do.")
        return

    print(f"Generating {total_target} scripts...")
    print()

    # 启动所有任务 (Semaphore 控制并发)
    coroutines = [
        generate_agent_script(s_name, s_desc, traits, system_prompt, v_idx)
        for (s_name, v_idx, s_desc, traits) in tasks
    ]
    results = await asyncio.gather(*coroutines)

    # 统计
    total_ok = sum(1 for _, _, _, ok in results if ok)
    total_fail = total_target - total_ok

    print()
    print("=" * 50)
    print(f"Generation Complete!")
    print(f"  Target:  {total_target}")
    print(f"  OK:      {total_ok} ({total_ok / max(1, total_target) * 100:.1f}%)")
    print(f"  Failed:  {total_fail}")
    print(f"  Output:  {os.path.abspath(OUTPUT_DIR)}")
    print("=" * 50)

if __name__ == "__main__":
    asyncio.run(main())
