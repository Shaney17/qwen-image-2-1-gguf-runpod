# RunPod Serverless: ComfyUI + ComfyUI-GGUF (leejet fork) + Qwen-Image 2.1 Uncensored GGUF
# Base: official runpod/worker-comfyui image (handler nhận input.workflow)
FROM runpod/worker-comfyui:5.10.0-base

# Qwen-Image 2.1 nodes arrived in ComfyUI v0.37.0; the worker base ships v0.34.0.
ARG COMFYUI_REF=v0.37.0
RUN git -C /comfyui fetch --depth 1 origin tag ${COMFYUI_REF} \
 && git -C /comfyui checkout ${COMFYUI_REF} \
 && uv pip install -r /comfyui/requirements.txt

# ---------------------------------------------------------------------------
# 1. Custom node: bản fork leejet (bản city96 trên Registry KHÔNG hỗ trợ qwen_image21)
# ---------------------------------------------------------------------------
ARG GGUF_NODE_REF=main
RUN git clone https://github.com/leejet/ComfyUI-GGUF /comfyui/custom_nodes/ComfyUI-GGUF \
 && git -C /comfyui/custom_nodes/ComfyUI-GGUF checkout ${GGUF_NODE_REF} \
 && uv pip install -r /comfyui/custom_nodes/ComfyUI-GGUF/requirements.txt

# ---------------------------------------------------------------------------
# 2. Models (đổi QUANT để dùng bản khác: Q4_0 | Q4_K_M | Q5_K_M | Q6_K | Q8_0 | BF16)
#    Nhớ sửa "unet_name" trong request cho khớp tên file.
# ---------------------------------------------------------------------------
ARG QUANT=Q8_0
ARG HF=https://huggingface.co/abenzerps/Qwen-Image-2.1-Uncensored-GGUF/resolve/main
RUN comfy model download --url ${HF}/qwen-image-2.1-UC-${QUANT}.gguf \
      --relative-path models/diffusion_models --filename qwen-image-2.1-UC-${QUANT}.gguf
RUN comfy model download --url ${HF}/text_encoders/qwen3vl_8b_int8_convrot.safetensors \
      --relative-path models/text_encoders --filename qwen3vl_8b_int8_convrot.safetensors
RUN comfy model download --url ${HF}/vae/qwen_image_2.1_vae_bf16.safetensors \
      --relative-path models/vae --filename qwen_image_2.1_vae_bf16.safetensors

# ---------------------------------------------------------------------------
# 3. Kiểm tra ngay lúc build (build sẽ FAIL nếu có vấn đề, thay vì lỗi lúc chạy)
# ---------------------------------------------------------------------------
RUN grep -q "TextEncodeQwenImage21" /comfyui/comfy_extras/nodes_qwen.py \
      || (echo "ComfyUI trong base image quá cũ: thiếu TextEncodeQwenImage21" && exit 1)
RUN cd /comfyui && timeout 300 python main.py --quick-test-for-ci --cpu > /tmp/boot.log 2>&1; \
    cat /tmp/boot.log; \
    if grep -q "IMPORT FAILED" /tmp/boot.log; then echo "Custom node import failed" && exit 1; fi; \
    grep -q "custom_nodes/ComfyUI-GGUF" /tmp/boot.log || (echo "ComfyUI-GGUF was not loaded" && exit 1)
RUN ls -lh /comfyui/models/diffusion_models /comfyui/models/text_encoders /comfyui/models/vae
