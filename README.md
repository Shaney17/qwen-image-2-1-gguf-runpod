# Qwen-Image 2.1 Uncensored (GGUF) trên RunPod Serverless

Image serverless dựa trên [`runpod/worker-comfyui`](https://github.com/runpod-workers/worker-comfyui), cài sẵn:

- **ComfyUI-GGUF** – bản fork [`leejet/ComfyUI-GGUF`](https://github.com/leejet/ComfyUI-GGUF) (bản gốc city96 trên Registry chưa hỗ trợ kiến trúc `qwen_image21`)
- Model từ [`abenzerps/Qwen-Image-2.1-Uncensored-GGUF`](https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-GGUF):
  - `diffusion_models/qwen-image-2.1-UC-Q8_0.gguf` (7.6 GB)
  - `text_encoders/qwen3vl_8b_int8_convrot.safetensors` (9.35 GB)
  - `vae/qwen_image_2.1_vae_bf16.safetensors` (0.7 GB)

## Deploy

1. RunPod → **Serverless → New Endpoint → Import Git Repository** → chọn repo này.
2. Branch `main`, Dockerfile path `Dockerfile`.
3. GPU: **≥ 24 GB VRAM** (RTX 4090 / L4 / A5000 / A6000…). Container disk **≥ 40 GB**.
4. Đợi build xong. Dockerfile tự kiểm tra lúc build: nếu node GGUF không load được, build sẽ báo lỗi.

Muốn đổi bản quant: sửa `ARG QUANT=Q8_0` trong `Dockerfile` (Q4_0, Q4_K_M, Q5_K_M, Q6_K, Q8_0, BF16) và sửa `unet_name` trong request cho khớp.

## Gọi API

Request phải chứa **toàn bộ workflow (định dạng API)** trong `input.workflow` — xem [`examples/request_body.json`](examples/request_body.json).

```
POST https://api.runpod.ai/v2/<ENDPOINT_ID>/run      (hoặc /runsync)
Authorization: Bearer <RUNPOD_API_KEY>
```

Các trường thường sửa:

| Muốn đổi | Node | Trường |
|---|---|---|
| Prompt | `"4"` | `prompt` |
| Kích thước | `"5"` | `width`, `height` (bội số của 32) |
| Ảnh khác | `"6"` | `seed` |
| Số bước | `"6"` | `steps` (mặc định 25) |

`cfg = 1` theo mẫu chính thức của Qwen-Image 2.1, nên `negative_prompt` không có tác dụng (tăng `cfg` nếu muốn dùng negative).

Kết quả: `output.images[]` gồm `filename`, `type` (`base64` hoặc `s3_url`), `data`.

### Script gọi nhanh

```bash
cd examples
export RUNPOD_API_KEY=...
export RUNPOD_ENDPOINT_ID=...
python call_serverless.py "a cozy street cafe at golden hour, realistic photo" --width 832 --height 1216
```

Ảnh được lưu vào `examples/outputs/`.

## Workflow cho ComfyUI (giao diện)

- [`workflows/Qwen-Image-2.1-GGUF.json`](workflows/Qwen-Image-2.1-GGUF.json) – kéo vào ComfyUI để dùng trên máy local / pod.
- [`workflows/Qwen-Image-2.1-GGUF_api.json`](workflows/Qwen-Image-2.1-GGUF_api.json) – định dạng API (giống `input.workflow`).
