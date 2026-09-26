#!/usr/bin/env python3
"""Gọi RunPod Serverless (worker-comfyui) để tạo ảnh Qwen-Image 2.1 và lưu ảnh về máy.

Cách dùng:
  export RUNPOD_API_KEY=...        # lấy ở RunPod > Settings > API Keys
  export RUNPOD_ENDPOINT_ID=...    # ID của endpoint serverless
  python call_serverless.py "a cat on a windowsill, realistic photo"
  python call_serverless.py "..." --width 832 --height 1216 --steps 30 --seed 42
"""
import argparse, base64, json, os, random, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


def req(url, key, data=None):
    r = urllib.request.Request(url, headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    if data is not None:
        r.data = json.dumps(data).encode()
    with urllib.request.urlopen(r, timeout=120) as resp:
        return json.loads(resp.read())


def main():
    p = argparse.ArgumentParser()
    p.add_argument("prompt")
    p.add_argument("--negative", default="")
    p.add_argument("--width", type=int, default=1024)
    p.add_argument("--height", type=int, default=1024)
    p.add_argument("--steps", type=int, default=25)
    p.add_argument("--cfg", type=float, default=1.0)
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--model", default=None, help="tên file .gguf có trong image serverless")
    p.add_argument("--out", default=os.path.join(HERE, "outputs"))
    a = p.parse_args()

    key = os.environ["RUNPOD_API_KEY"]
    ep = os.environ["RUNPOD_ENDPOINT_ID"]
    base = f"https://api.runpod.ai/v2/{ep}"

    wf = json.load(open(os.path.join(HERE, "workflow_api.json")))
    wf["4"]["inputs"].update(prompt=a.prompt, negative_prompt=a.negative)
    wf["5"]["inputs"].update(width=a.width, height=a.height)
    seed = a.seed if a.seed is not None else random.randint(0, 2**50)
    wf["6"]["inputs"].update(seed=seed, steps=a.steps, cfg=a.cfg)
    if a.model:
        wf["1"]["inputs"]["unet_name"] = a.model

    job = req(f"{base}/run", key, {"input": {"workflow": wf}, "policy": {"ttl": 3600000}})
    jid = job["id"]
    print(f"Job {jid} (seed={seed}) đã gửi, đang chờ...", flush=True)

    while True:
        st = req(f"{base}/status/{jid}", key)
        s = st.get("status")
        if s in ("COMPLETED", "FAILED", "CANCELLED", "TIMED_OUT"):
            break
        time.sleep(3)

    if s != "COMPLETED":
        print("Thất bại:", json.dumps(st, indent=2, ensure_ascii=False))
        return

    os.makedirs(a.out, exist_ok=True)
    for img in st["output"].get("images", []):
        if img.get("type") == "base64":
            path = os.path.join(a.out, img["filename"])
            open(path, "wb").write(base64.b64decode(img["data"]))
            print("Đã lưu:", path)
        else:
            print("Ảnh (S3):", img.get("data"))
    print(f"Thời gian chạy: {st.get('executionTime', 0)/1000:.1f}s, chờ: {st.get('delayTime', 0)/1000:.1f}s")


if __name__ == "__main__":
    main()
