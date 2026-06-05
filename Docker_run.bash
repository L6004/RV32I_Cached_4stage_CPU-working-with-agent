#!/usr/bin/bash
docker run -it -d \
  --name rv_agent_inst \
  --gpus all \
  --shm-size=32g \
  -p 8501:8501 \
  -p 11435:11434 \
  -v /usr/share/ollama/.ollama:/root/.ollama:ro \
  -v $(pwd):/workspace \
  -v /tools/Xilinx:/tools/Xilinx:ro \
  rv32i_agent:latest
