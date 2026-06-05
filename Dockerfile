FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    build-essential git curl wget pciutils zstd locales \
    gcc-riscv64-unknown-elf device-tree-compiler \
    libtinfo5 libncurses5 libxrender1 libxtst6 libxi6 libxext6 \
    libx11-6 libsm6 libice6 libglib2.0-0 libfreetype6 libfontconfig1 \
    xvfb x11-utils \
    && locale-gen en_US.UTF-8 \
    && apt-get clean

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

COPY riscv-isa-sim-master.tar.gz /tmp/
RUN cd /tmp && tar -xzf riscv-isa-sim-master.tar.gz && \
    cd riscv-isa-sim-master && mkdir build && cd build && \
    ../configure --prefix=/usr/local && make -j$(nproc) && make install && \
    rm -rf /tmp/riscv-isa-sim*

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
COPY ollama-linux-amd64.tar.zst /tmp/
RUN tar -I zstd -xf /tmp/ollama-linux-amd64.tar.zst -C /usr/local && \
    rm /tmp/ollama-linux-amd64.tar.zst

RUN wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && rm /tmp/miniconda.sh
ENV PATH="/opt/conda/bin:${PATH}"
RUN conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/ && \
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
RUN conda create -n rv_agent python=3.13 -y
RUN conda run -n rv_agent pip install --no-cache-dir \
    streamlit langchain langchain-community langchain-ollama langgraph \
    pandas numpy matplotlib seaborn

ENV XILINX_VIVADO=/tools/Xilinx/2025.2/Vivado
ENV PATH="${XILINX_VIVADO}/bin:/usr/local/bin:/usr/bin:/opt/conda/envs/rv_agent/bin:${PATH}"

WORKDIR /workspace

RUN echo '#!/bin/bash\n\
export WEBTALK_DISABLE=1\n\
export XILINX_VIVADO_NO_WEBTALK=1\n\
Xvfb :99 -screen 0 1024x768x24 &\n\
export DISPLAY=:99\n\
OLLAMA_NUM_GPU=999 OLLAMA_HOST=0.0.0.0 ollama serve &\n\
sleep 5\n\
ollama run modelscope.cn/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF:q8_0 --keepalive 24h &\n\
exec streamlit run app.py --server.port=8501 --server.address=0.0.0.0 --server.headless=true --browser.gatherUsageStats=false\n' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
