# app.py
import streamlit as st
import pandas as pd
from langchain_ollama import ChatOllama
from langchain.tools import tool
from langgraph.prebuilt import create_react_agent
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
import re
import json
import os
import skills

st.set_page_config(layout="wide", page_title="RV32I Arch Explorer")
st.title("RV32I 架构探索与验证 Agent")

# ----------------- Auxiliary function: source code folded presentation -----------------

def display_smart_verilog(code_str: str, module_name: str):
    """Verilog source code presentation: Only presented to localparam, fold/expand option and download button are provided."""
    lines = code_str.split('\n')
    
    # make use of code note "INTERNAL SIGNALS" to cut off before internal signal declarations.
    cutoff_idx = 0
    for i, line in enumerate(lines):
        if 'INTERNAL' in line:
            cutoff_idx = i
            
    if cutoff_idx == 0:
        cutoff_idx = min(30, len(lines))
    else:
        cutoff_idx = min(cutoff_idx + 2, len(lines))
        
    snippet_lines = lines[:cutoff_idx]
    snippet_lines.append("\n    // ... [代码已智能截断，请展开下方折叠面板或下载查看完整源码] ...")
    
    st.markdown(f"**模块接口与参数定义: `{module_name}`**")
    st.code('\n'.join(snippet_lines), language="verilog")
    
    # fold panel and download button
    with st.expander(f"📂 点击展开/收起 `{module_name}.v` 完整源码"):
        st.download_button(
            label=f"💾 下载 {module_name} 源码",
            data=code_str,
            file_name=f"{module_name}.v",
            mime="text/plain"
        )
        st.code(code_str, language="verilog")

# ----------------- Realtime UI rendering tools -----------------

@tool
def cache_sim_tool(l1_i_size: int, l1_d_size: int, l1_b_size: int, l1_assoc: int, case_name: str, skip_base: bool = False) -> str:
    """Use this to run a single cache parameter simulation. Provide L1 parameters. Set skip_base=True if user explicitly wants to skip the baseline simulation."""
    st.info(f"Agent 正在调度底层仿真: I-Cache = {l1_i_size / 1024}KB, D-Cache = {l1_d_size / 1024}KB, L1-Block_Size = {l1_b_size}B, Assoc = {l1_assoc}-Ways | Skip Base: {skip_base}")
    paths = skills.run_cache_sim_single(l1_i_size, l1_d_size, l1_b_size, l1_assoc, case_name, skip_base)
    
    st.markdown(f"### {case_name} 缓存系统 RTL 核心源码")
    rtl_sources = paths.get('rtl_code', {})
    if isinstance(rtl_sources, dict) and rtl_sources:
        for mod_name, code_str in rtl_sources.items():
            if mod_name != "not_found":
                display_smart_verilog(code_str, mod_name)
    else:
        st.warning("未找到 RTL 源码")

    st.markdown(f"### {case_name} 参数化仿真结果概览")
    st.markdown("#### 性能综合报告")
    st.dataframe(pd.read_csv(paths['csv']))
    col1, col2 = st.columns(2)
    with col1:
        st.markdown("#### Baseline 与 Cached 耗时对比")
        st.image(paths['img1'], use_container_width=True)
    with col2:
        st.markdown("#### 缓存缺失率热力图")
        st.image(paths['img2'], use_container_width=True)
        
    # return JSON string contract for interceptor to parse and feed to LLM
    return json.dumps({
        "tool_name": "Cache Parameter Simulation",
        "csv_paths": [paths['csv']],
        "summary": f"Cache simulation done. I-Cache={l1_i_size/1024}KB, D-Cache={l1_d_size/1024}KB, Assoc={l1_assoc}."
    })

@tool
def matrix_gen_sim_tool(case_id: str, n_size: int, b_size: int, skip_base: bool = False) -> str:
    """Use this to modify matrix macros (case 701, 702, 703), compile, and simulate. Provide case_id, N, and B_SIZE. Set skip_base=True if user explicitly asks to skip baseline (e.g. for large matrices)."""
    st.info(f"Agent 正在生成测试向量并启动仿真: Case {case_id}, Matrix N = {n_size}, Block = {b_size} | Skip Base: {skip_base}")
    paths = skills.generate_and_sim_matrix(case_id, n_size, b_size, skip_base)
    
    st.markdown(f"### 动态分块矩阵仿真结果 (Case: {case_id} | N: {n_size} | Block: {b_size})")
    
    with st.expander("查看动态生成的 C 源码与 RISC-V 汇编 (.s)", expanded=False):
        t1, t2 = st.tabs(["动态生成的 C Source Code", "RISC-V Assembly (截断部分)"])
        with t1:
            with open(paths['c_code']) as f: st.code(f.read(), language='c')
        with t2:
            with open(paths['s_code']) as f: 
                asm_content = f.read()
                st.code(asm_content[:3000] + "\n\n... [截断显示] ...", language='gas')

    st.markdown("#### AMAT & CPI 数据表")
    st.markdown("#### 性能综合报告")
    st.dataframe(pd.read_csv(paths['csv']))
    col1, col2 = st.columns(2)
    with col1: 
        st.markdown("#### 性能加速比")
        st.image(paths['img1'], use_container_width=True)
    with col2: 
        st.markdown("#### 数据局部性 (Miss Rate)")
        st.image(paths['img2'], use_container_width=True)
        
    return json.dumps({
        "tool_name": "Matrix Generation & Simulation",
        "csv_paths": [paths['csv']],
        "summary": f"Matrix block simulation done for Case {case_id}. N={n_size}, Block={b_size}."
    })

@tool
def arch_exploration_tool(dummy: str) -> str:
    """Use this to run the full architecture exploration workflow (Single, Assoc, Locality). Pass 'run' as the dummy argument."""
    st.info("Agent 正在启动全自动架构空间探索，请稍候...")
    paths = skills.run_arch_exploration()
    
    st.markdown("### 1. 单一参数探索")
    st.markdown("基于默认参数，每次只改变 L1 Cache 的一种参数。探索空间为：")
    st.markdown("1. 缓存容量：4KB, 8KB, 16KB；")
    st.markdown("2. 缓存块大小：16B, 32B, 64B；")
    st.markdown("3. 相联度：Direct, 2-Way, 4-Way。")
    st.markdown("使用矩阵运算和大数组顺序遍历测试例进行测试。")
    st.markdown("#### 矩阵运算 (Naive方法) 单一参数架构探索性能综合报告")
    st.dataframe(pd.read_csv(paths['single_csv1']))
    st.markdown("#### 大数组顺序遍历单一参数架构探索性能综合报告")
    st.dataframe(pd.read_csv(paths['single_csv2']))
    c1, c2 = st.columns(2)
    with c1: st.image(paths['single_img1'], caption="矩阵运算 (Naive方法) 单一参数架构探索 AMAT 趋势")
    with c2: st.image(paths['single_img2'], caption="大数组顺序遍历单一参数架构探索 AMAT 趋势")
    
    st.markdown("### 2. 组相联度与块大小耦合分析")
    st.markdown("进行相联度与块大小的组合探索分析：[16B, 32B, 64B] $\\times$ [Direct, 2-Way, 4-Way, 8-Way]。")
    st.markdown("使用矩阵运算测试例进行测试。")
    c1, c2 = st.columns(2)
    with c1: st.image(paths['assoc_img1'], caption="各级 Miss Rate 对比")
    with c2: st.image(paths['assoc_img2'], caption="AMAT & CPI 性能双轴图")
        
    st.markdown("### 3. 程序局部性分析")
    st.markdown("分别在时间局部性好、空间局部性好和不具备局部性的程序下对默认架构进行测试。")
    c1, c2, c3 = st.columns(3)
    with c2: st.image(paths['locality_img'], caption="各种局部性测试下缓存缺失率表现")
    
    return json.dumps({
        "tool_name": "Full Architecture Exploration",
        "csv_paths": [paths['single_csv1'], paths['single_csv2']],
        "summary": "Full exploration completed encompassing Capacity, Associativity, and Locality testing."
    })

# ----------------- Agent initialization -----------------
llm = ChatOllama(
    model="modelscope.cn/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF:q8_0", 
    temperature=0.1, 
    base_url="http://127.0.0.1:11434",
    num_gpu=999
)
tools = [cache_sim_tool, matrix_gen_sim_tool, arch_exploration_tool]

# ----------------- UI interaction logic -----------------

if "messages" not in st.session_state:
    st.session_state.messages = []

for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

if prompt := st.chat_input("输入你的指令（例如：'帮我跑一下703分块矩阵，规模32，分块8，跳过基准' 或 '执行全架构参数探索'）"):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        with st.spinner("Agent 正在思考分析..."):
            try:
                sys_msg = SystemMessage(content="""你是一个专业的 RV32I 架构探索与验证 AI 助手。
                当需要仿真时，你必须在回复中严格输出如下 JSON 格式来调用工具：
                {
                "name": "工具名称",
                "arguments": {"参数名": 参数值}
                }
                """)
                user_msg = HumanMessage(content=prompt)
                
                # create an agent instance for the first call
                agent = create_react_agent(model=llm, tools=tools)
                result = agent.invoke({"messages": [sys_msg, user_msg]})
                response_text = result["messages"][-1].content
                
                # catch the tool call JSON from the response using regex
                tool_match = re.search(r'\{.*"name":\s*"(.*?)".*"arguments":\s*(\{.*?\})\s*\}', response_text, re.DOTALL)
                
                if tool_match:
                    tool_name = tool_match.group(1)
                    try:
                        tool_args = json.loads(tool_match.group(2))
                    except:
                        tool_args = {}
                        
                    st.info(f"成功拦截到工具调用指令，正在拉起底层仿真: `{tool_name}` ...")
                    
                    # force route
                    observation = ""
                    if tool_name == "arch_exploration_tool":
                        observation = arch_exploration_tool.invoke(tool_args)
                    elif tool_name == "matrix_gen_sim_tool":
                        observation = matrix_gen_sim_tool.invoke(tool_args)
                    elif tool_name == "cache_sim_tool":
                        observation = cache_sim_tool.invoke(tool_args)
                        
                    st.success("✅ 底层 EDA 仿真与 UI 渲染全部执行完毕！正在交由大模型进行架构分析...")
                    
                    # analyse the observation and extract key performance metrics, then feed to LLM for analysis
                    real_data_context = ""
                    try:
                        obs_dict = json.loads(observation)
                        real_data_context += obs_dict.get("summary", "")
                        csv_paths = obs_dict.get("csv_paths", [])
                        
                        for path in csv_paths:
                            if os.path.exists(path):
                                df = pd.read_csv(path)
                                file_name = os.path.basename(path)
                                real_data_context += f"\n\n### 【{file_name}】 核心仿真数据:\n{df.to_string(index=False)}\n"
                                
                    except Exception as e:
                        st.warning(f"⚠️ 后台数据解析警告 (大模型可能无法看到完整表格): {str(e)}")
                        real_data_context = str(observation)
                        
                    if not real_data_context.strip():
                        real_data_context = "未能提取到有效的仿真数据，请根据任务成功的状态进行一般性总结。"

                    # directly call LLM from the second tool response
                    ai_msg = AIMessage(content=response_text)
                    obs_msg = HumanMessage(content=f"底层仿真脚本已执行完毕。以下是提取出的精确性能指标：\n\n{real_data_context}\n\n请你作为资深芯片架构师，仔细阅读上述 Markdown 数据表格，用自然语言撰写一份深度的性能瓶颈分析报告。")
                    
                    final_result = llm.invoke([sys_msg, user_msg, ai_msg, obs_msg])
                    final_response = final_result.content
                    
                    st.markdown(f"**架构师分析报告:**\n{final_response}")
                    st.session_state.messages.append({"role": "assistant", "content": final_response})
                    
                else:
                    # if JSON has not been captured, it means the model is just giving a normal response without tool calling
                    st.markdown(f"{response_text}")
                    st.session_state.messages.append({"role": "assistant", "content": response_text})
                    
            except Exception as e:
                st.error(f"Execution Error: {str(e)}")