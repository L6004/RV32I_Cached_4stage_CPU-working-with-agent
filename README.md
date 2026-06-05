# RV32I_Cached_4stage_CPU-working-with-agent
> 该项目目前只在 Ubuntu 24.04 中进行过验证，使用的 Vivado 版本为 2025.2。
>
> 若要在 Windows 平台中手动进行仿真和设计探索，请尽可能使用项目根目录下的 Dockerfile 创建一个  Ubuntu 22.04 Docker 环境，然后在该 Docker 实例中调用各脚本。

## 快速上手

* 克隆项目到本地，并进入项目根目录；

* 在宿主机中准备好 Ollama 和 Spike 的 Release 包，放到项目根目录下；

* 修改 Dockerfile 中 `XILINX_VIVADO` 环境变量为您的 Vivado 安装目录，检查 Docker_run.bash 中 Ollama 和 Streamlit 服务端口的占用情况，若已被占用，请按实际情况进行重分配；

* 执行以下命令，构建 Docker 环境
	```shell
	docker build -t rv32i_agent:latest .
	```

* 借助 Docker_run.bash 脚本创建一个实例
	```shell
	./Docker_run.bash
	```

* 检查实例创建情况并获取 Streamlit App 推送地址
	```shell
	docker logs -f rv_agent_inst
	```

* 访问 App 推送地址，与 LLM 对话，让它完成你指定的任务，比如

	* “帮我跑一下703分块矩阵测试，矩阵规模32，分块规模8”
	* “帮我执行一下全架构参数探索”
	* “帮我设计一个一级缓存容量为16KB，相联度为4的CPU，然后用它跑801大数组顺序遍历测试”

* 等待一会，然后查看仿真结果图表；

* 需要关闭 Docker 时，只需执行以下指令
	```shell
	docker rm -f rv_agent_inst
	```

* 需要进行手动的仿真与设计探索时

	* 如果您使用的是 Linux/WSL 平台，请将 /env/setup.bash 中的 `PRJ_PATH` 修改为项目根目录，手动 `source` 让它生效，然后就可以根据仿真脚本和综合实现脚本的使用方法来执行任务了
	* 如果您使用的是 Windows 平台，进入 Docker 以让各脚本正常运行

	```shell
	docker exec -it rv_agent_inst bash
	```

	然后将 /workspace/env/setup.bash 中的 `PRJ_PATH` 修改为 /workspace，手动 `source` 让它生效
	```shell
	source /workspace/env/setup.bash
	```

	接下来就可以根据仿真脚本和综合实现脚本的使用方法执行任务了

## 仓库内容介绍

* 根目录下的 Docker 相关文件用于配置并创建 Docker 实例，`app.py` 以及 `skills.py` 用于实现 Agent Skill 及其前端；
* env 目录下存放了手动执行仿真和设计探索时可以用到的环境变量与别名配置；
* sim 目录下有几个子目录，分别为
	* arch_exp：存放了架构参数探索得到的参考结果
	* bench：存放了 UVM 验证平台组件及其编译目录
	* cases_asm：存放了汇编测试例，有一部分来自 C 测试例的编译结果
	* cases_c：存放了 C 测试例
	* scripts：存放了仿真脚本和架构参数探索脚本等
* src 目录下存放了 CPU 的 RTL 实现和对应的编译目录，其 scripts 子目录下存放了综合实现脚本

## Agent Skills 介绍

### 获取参数化缓存 RTL 并执行指定的仿真测试

支持对 L1 Cache 的容量、块大小、关联度进行配置，支持测试例的指定，支持运行长时间、大指令数量仿真时跳过 Baseline 情形，会在仿真结束时将生成的性能分析报告和 RTL 源码返回给前端，结果图表包括 `.csv` 表格和两张结果分析图（加速比和缓存缺失率热力图）。

> [!NOTE]
>
> 示例 prompt：
>
> 请为我设计一套缓存系统，L1 I-Cache 和 L1 D-Cache 的容量都是 8192B，块大小都是 16B，相联度都是 4，其他设计如 L2 Cache 的架构参数、主存 DRAM 的延时与容量、总线位宽等都无需改动。仿真请使用 case_302 作为测试例，不要跳过 baseline。

### 矩阵乘法测试例定制化

根据用户指定的矩阵规模和分块大小，自动生成矩阵运算测试例（3 种情形都支持，包括 naive 方法、行访问方法和分块矩阵方法），并自动用默认缓存配置执行仿真，支持跳过 Baseline 情形，会在仿真结束时将生成的测试例 `.c` 、`.s` 源码和性能分析图表一起返回给前端。

> [!NOTE]
>
> 示例 prompt：
>
> 请帮我跑一下 case_703 分块矩阵乘法的测试，矩阵规模设为 32，分块规模为 8，不要跳过 baseline。

> [!IMPORTANT]
>
> 请不要将矩阵规模设得过大，否则仿真时间可能超过 `base_test` 设定的超时上限，导致仿真提前结束，得到错误结果。

### 自动运行全架构参数探索

直接调用 `run_exp` 脚本，实时捕获脚本的标准输出以显示进度，在所有探索完成后将三种探索情形的所有分析图表返回给前端，包括：

* 单一参数探索：矩阵乘法和大数组顺序遍历测试例的各参数情形性能对比表 + AMAT 折线图；
* 组相联度和块大小组合探索：按块大小绘制的各级缓存缺失率 - 组相联度 3 联图 + 32B 块大小下各组相联度对应的 CPI 和 AMAT 折线图；
* 程序局部性探索：一张缓存缺失率与程序局部性的关系折线图。

> [!NOTE]
>
> 示例 prompt：
>
> 请帮我做一下全架构参数探索，并及时汇报进度。

## 手动仿真和设计探索方法

对于单个测试例的仿真，可以使用 `run_sim.py` 脚本（如果 `source` 了 `setup.bash` ，可以直接 `run_sim` 运行），脚本的使用方法如下：

```shell
usage: run_sim.py [-h] [-seed SEED] [--l1_i_size L1_I_SIZE] [--l1_d_size L1_D_SIZE] [--l1_b_size L1_B_SIZE] [--l2_size L2_SIZE]
                  [--l2_b_size L2_B_SIZE] [--l1_assoc L1_ASSOC] [--l2_assoc L2_ASSOC] [--l1_l2_bus_bytes L1_L2_BUS_BYTES]
                  [--dram_delay_cycles DRAM_DELAY_CYCLES] [--cache_dram_bus_bytes CACHE_DRAM_BUS_BYTES] [--ram_size RAM_SIZE]
                  [--fifo_depth FIFO_DEPTH] [--skip_base] [--disable_vcd] [--opt_level OPT_LEVEL] [--work_dir WORK_DIR]
                  [--reuse_sw] [--gen_saif] [--gls] [--strategy {SPEED,AREA,POWER}]
                  case

positional arguments:
  case                  Case filename (e.g. case_001_smoke.s or case_302_hazard_c.c)

options:
  -h, --help            show this help message and exit
  -seed SEED            Seed
  --l1_i_size L1_I_SIZE
                        L1 I-Cache Size in bytes
  --l1_d_size L1_D_SIZE
                        L1 D-Cache Size in bytes
  --l1_b_size L1_B_SIZE
                        L1 Cache Block Size in bytes
  --l2_size L2_SIZE     L2 Cache Size in bytes
  --l2_b_size L2_B_SIZE
                        L2 Cache Block Size in bytes
  --l1_assoc L1_ASSOC   L1 Cache Associativity
  --l2_assoc L2_ASSOC   L2 Cache Associativity
  --l1_l2_bus_bytes L1_L2_BUS_BYTES
                        L1-L2 Cache Bus Data Width in Bytes
  --dram_delay_cycles DRAM_DELAY_CYCLES
                        DRAM Behavioral Delay
  --cache_dram_bus_bytes CACHE_DRAM_BUS_BYTES
                        L2_Cache-DRAM Bus Data Width in Bytes
  --ram_size RAM_SIZE   DRAM size
  --fifo_depth FIFO_DEPTH
                        FIFO depth
  --skip_base           Skip Baseline test(no Cache)
  --disable_vcd         Disable vcd dump in cache system for very large scale simulation
  --opt_level OPT_LEVEL
                        Optimization level for gcc
  --work_dir WORK_DIR   Custom working directory for output
  --reuse_sw            Skip SW compile and Spike simulation
  --gen_saif            Generate saif file for power synthesis
  --gls                 Run Gate-Level Simulation (Post-Impl) for power analysis
  --strategy {SPEED,AREA,POWER}
```

它支持指定测试例、缓存架构参数、主存延迟和容量、是否跳过 baseline、是否打开 vcd dump（针对有缓存情形做调试）和 C 测试例编译器优化水平等。最后的几个选项主要用于自动化参数探索脚本和综合实现时的功耗分析。

对于自动化参数探索，只需直接运行 `run_exp.py` 即可。

对于综合实现，需要在运行 `run_syn_imp.py` 时指定 PPA 的优化方向。另外，为了获取更准确的功耗分析结果，需要做一些额外工作：

* 若使用前仿的翻转率，则要先使用 `run_sim.py`（开启 `--gen_saif` 开关）获取前仿翻转率信息，然后在综合的时候开启 `-flatten_hierarchy rebuilt` 开关，保留各层级设计。在功耗分析中读入 `.saif` 文件，对各层级功耗进行分析，最后整合后获取报告。这种方法对翻转率的匹配程度比较好，但是由于和综合实现后真实的布局布线情况不同，得到的功耗数据很可能偏高；
* 若使用后仿的翻转率，则要先使用综合实现脚本，正常按策略运行，导出网表和 `.sdf` 文件，然后使用 `run_sim.py`（开启 `--gls` 和 `--strategy` 开关，`--strategy` 开关用于选择综合实现的策略）进行 GLS 后仿，得到翻转率信息；再回到综合实现脚本（使用功耗分析模式），读入 `.dcp` 和 `.saif` 文件进行功耗分析。这种方法得出的翻转率信息比较符合实际物理实现的情况，但是限于 Vivado 工具支持，它没法在功耗分析时正常解析 `.dcp`  和 `.saif`文件中网表的对应关系，导致得出的功耗报告中对应到仿真翻转率的 nets 占比低于 10%（其他 nets 按照默认的 12.5% 翻转率进行估计），置信率极低。

该脚本的使用方法如下：

```shell
usage: run_syn_imp.py [-h] [--mode {normal,export_gls,report_power}] [--strategy {SPEED,AREA,POWER,ALL}]

Vivado Synthesis & Power Analysis Script

options:
  -h, --help            show this help message and exit
  --mode {normal,export_gls,report_power}
                        normal: run syn&imp; export_gls: export netlist&SDF; report_power: run gls power report
  --strategy {SPEED,AREA,POWER,ALL}
```

## 项目完整介绍

完整的解析和结果展示参见 /doc/report.md
