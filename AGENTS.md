# AGENTS

## 项目定位

这个仓库用于资料存储，主要服务于学习巩固、知识沉淀和面试准备。

- `md-viewer` 用于在本地和生产环境浏览仓库内的 Markdown、代码与配置资料。
- 其余 Markdown、JavaScript 等文件主要是知识资料，前端、后端、数据库、运维和部署内容继续补充到对应专题目录。
- 当前已有较多前端知识积累，并已扩展到 Java、MySQL、Redis、Linux、Nginx、Docker、Docker Compose 和生产发布实践。

## 用户背景

- 用户当前主方向是前端开发，正在向全栈开发工程师转型。
- 已学习 Java 基础，正在持续学习后端、数据库、Linux、部署和运维。
- 后续计划包括微服务、Redis、Spring、Spring Boot、Docker 和 Docker Compose 等。
- 在后端、部署、数据库、Linux、Docker、Spring Boot、Maven 等方向仍处于持续上手阶段。
- 用户正在第一次完整设计和实现 RAG Agent；后续检索、索引、Embedding、Reranker、评测和可观测性升级同时属于项目建设与全栈学习内容。
- 相关说明默认按“给转全栈的前端同学看的版本”来写：补充命令作用、执行目录、适用场景、验证方法、回滚方式和常见误区，不只给结论。

## 当前学习与实践重点

- 持续巩固前端知识、原理、面试题和工程实践经验。
- 补充后端与数据库知识，形成从浏览器到服务端、数据层和基础设施的完整链路。
- 重点学习 Linux 环境下的部署与运维，因为这更贴近真实企业开发环境。
- 当前正从“能把服务跑起来”过渡到“能按接近生产的标准发布、验收、回滚、排障和演进服务”。
- Docker / Docker Compose 已从学习演练进入真实生产实践；后续重点是版本化发布、最小变更、数据安全、可观测性、自动化和可恢复性。
- 演练过程写入对应专题文档；`AGENTS.md` 只保留当前结论、长期边界和文档索引。

## 当前生产基线

### 服务器与入口

- 腾讯云服务器系统为 `Ubuntu 24.04 LTS`，使用 `ubuntu` 账号并通过 `sudo` 管理。
- 仓库不记录真实公网 IP；示例统一使用 RFC 5737 文档地址 `203.0.113.10`，该地址不能用于真实连接。
- 正式域名为 `siyes.cn`，ICP 备案与公安联网备案均已完成；ICP备案号为 `闽ICP备17032186号-3`。
- 正式 HTTPS 入口：
  - `siyes.cn` / `www.siyes.cn`：主站与服务导航。
  - `music.siyes.cn`：siyeWorld 音乐空间。
  - `music-api.siyes.cn`：音乐 API。
  - `linux-api.siyes.cn`：Java 日志与聊天历史 API。
  - `socket.siyes.cn`：Socket.IO。
  - `sub2api.siyes.cn`：Sub2API。
  - `draw.siyes.cn`：SVG 绘图工具。
  - `knowledge.siyes.cn`：在线知识库。
- 阿里云 Windows 的 `siyefun.top` 继续作为已有前端入口和迁移参考，不是腾讯云生产配置来源。

### Docker 生产架构

- 当前正式业务统一由 Docker Compose 管理；旧 systemd 服务、宿主机 MySQL、旧 Sub2API 和学习容器不再是正式链路。
- Docker edge 直接占用公网 `80/443`，宿主机 Nginx 已卸载。除 SSH `22` 外，不应向公网发布业务容器端口。
- 正式容器通过外部网络 `siye-prod-edge-net` 互通；只有 `siye-prod-edge-nginx` 发布宿主机端口。
- 正式部署根目录为 `/opt/siye-production`。核心业务、Sub2API、svg-draw、edge、knowledge 和 Agent 分开管理，不得用无差别命令停止或重建整套生产环境。
- 主站目录为 `/var/www/siyes.cn`，由 edge 只读挂载。首页先备份再原子替换，无需重建 edge；备案信息必须保留。
- 正式日志目录为 `/var/log/siye-production`，不要与历史 systemd 日志目录 `/var/log/siye` 混用。
- 数据库容器不发布公网端口；MySQL、PostgreSQL、Redis 的数据和备份按各自 Compose 项目管理。
- 当前镜像版本与部署细节以服务器实际 Compose 和 [正式 Docker 部署基线](./Docker专题/正式部署/siye-stack/README.md) 为准，不按 Docker Hub 最高标签自动升级。

### HTTPS 与证书

- `/etc/letsencrypt/live/siyes-production/` 为 `siyes.cn + *.siyes.cn` 通配符证书。
- DNSPod Token 只保存在服务器 `/etc/letsencrypt/dnspod.env`，权限为 `600 root:root`，不得进入 Git、镜像或普通 `.env`。
- Certbot DNS-01 自动续期、TXT 创建与清理、staging `renew --dry-run` 和 edge 部署 Hook 已验证。
- 修改 edge 配置必须先备份，再执行容器内 `nginx -t`，通过后才允许 `nginx -s reload`。

### 知识库

- 服务器仓库为 `/opt/frontend-knowledge`；生产 Compose 位于 `/opt/frontend-knowledge/md-viewer/deploy`。
- `siye-prod-knowledge` 将仓库只读挂载到 `/knowledge`，不发布宿主机端口，由 edge 提供 `knowledge.siyes.cn`。
- 只更新资料时执行 `git pull --ff-only`；修改 md-viewer 程序、依赖或镜像内容时才重建容器。
- 服务器访问 GitHub HTTPS `443` 曾持续超时、重置和异常终止 TLS；该工作副本的 `origin` 已切换为 `git@github.com:siyesummer/frontend-knowledge.git`。服务器 `pull/push` 优先使用 SSH，排障先检查 `git remote -v` 与 SSH 连通性。
- GitHub Pages 使用手动触发 Workflow，地址为 `https://siyesummer.github.io/frontend-knowledge/#/`；提交不会自动发布 Pages。

### SIYES Agent

- 独立仓库为 `siyesummer/siyes-agent`；服务器源码目录 `/opt/siye-production/siyes-agent`，生产 Compose 目录 `/opt/siye-production/agent-deploy`。
- 当前生产版本为 `v0.11.0`，镜像 `siye-prod-agent:0.11.0`；容器只加入 edge 网络，不发布宿主机 `3002`。生产 Hybrid 索引为 2005 分片，代码围栏内的 `#` 注释不再被误当 Markdown 标题。
- 生产检索使用 FTS5/BM25 与 Embedding 向量召回的 Hybrid 模式，通过 RRF 合并排序，并在原有证据门禁前执行通用编程语言元数据一致性判断；向量缓存与模型状态持久化在命名卷 `agent-embedding-cache`。当前活动档案为百炼 `text-embedding-v4`，语义授权阈值为 `0.65`、最多授权 `Top-3`；百炼 v3 因额度耗尽被持久标记为 `quota_exhausted`，火山 vision 为 `retired`。明确额度耗尽、到期、下线或未开通模型服务时自动切换，全部不可用时降级到 FTS5。
- Reranker 已完成百炼 `qwen3-rerank` 的可选本地适配、失败回退和固定评测，但当前没有证明独立质量收益且增加明显延迟，生产开关必须保持 `KNOWLEDGE_RERANKER_ENABLED=false`，现阶段不继续针对固定失败案例调参。
- `v0.9.0` 已上线知识库 `git pull --ff-only` 后的主动索引刷新：受控脚本以知识库所有者身份更新 Git，只在公开资料变化时触发；后台构建包含公开分片、FTS5、向量索引和元数据的版本化快照，每次查询固定使用同一快照，全部校验通过后再原子切换。普通刷新失败保留旧快照；`knowledge-public.json` 变化从刷新开始阻断 readiness 与问答，成功后恢复，失败则保持 fail-closed。刷新状态、来源 Git revision、快照 ID、公开策略哈希、向量复用/补算量、耗时和失败原因可观测，管理接口仅接受容器 loopback 请求，`SIGHUP` 只作为备用触发。生产已验证无变化与内部资料更新跳过、无内容变化后台刷新全量复用 1967 个向量、刷新后 Hybrid 持续 ready、内部接口公网 `404`，以及 Docker 正例和 Python 跨语言负例。首次真实公开内容增量也已完成验收：3 个公开文件变化后在 5278ms 内原子切换到 2005 分片的新快照，复用 1965 个向量并补算 40 个；新增 `watchEffect` 问题准确引用新文档，原有 Docker 正例和 Python 跨语言负例继续通过。公开策略失败注入仍留待隔离环境演练，不在单实例生产主动制造。
- `v0.10.0` 已上线真实问题反馈候选闭环：追踪接口支持 `topicMismatch` 服务端过滤和低带宽 `view=feedback`，导出器默认小批次串行筛选拒答与主题错配，排除代码输入，执行基础脱敏和去重，并只生成 `pending` 人工审核文件，不直接修改固定评测集。生产 loopback `limit=1` 验证读取 1 条并生成 1 条候选，人工审核与禁止直接导入门禁均生效，没有通过公网批量下载完整 trace。候选记录稳定 `snapshotId`；`sourceRevision` 当前只在显式刷新传入后存在，容器重启后的启动预热尚不恢复该映射。
- `v0.11.0` 已上线用户显式“有帮助/没帮助”反馈，主站 Widget 为 `v0.3.0`：回答完成后才显示反馈控件；浏览器只持有与 `requestId` 绑定的 HMAC 凭证，不持有追踪查询 Token；负反馈只选择结构化原因，不收集自由文本。服务端按回答幂等更新并把追加式事件写入独立命名卷 `agent-feedback-data`，受控查询仍使用 `X-RAG-Trace-Token`。生产已验证正常问答、六类负反馈原因、提交状态、改选、JSONL 落盘、容器重启后恢复最新状态、移动端无横向溢出和控制台无错误；首次只读备份已建立，人工烟测事件随后从活动数据中清理，备份保留。该信号只能进入人工审核，不能自动成为评测真值或训练数据；反馈卷不得与 Embedding 缓存一起清理，也不得执行 `docker compose down -v`。
- 外部知识库必须同时配置 `/opt/frontend-knowledge:/knowledge-source:ro` 挂载和 `KNOWLEDGE_EXTRA_PATHS=/knowledge-source`；只有挂载而环境变量为空时，Agent 只会索引内置资料。
- 主站引用 `/assets/siye-agent-chat.v0.3.0.js`，顶部能力描述为“混合检索 RAG Agent”。Widget 会明确告知用户问题将用于质量分析和评测，并提醒不要提交敏感信息；发布时继续使用新版本文件名，并保留旧资源与首页备份以便回滚。
- Agent 只依据允许公开的知识资料回答，不使用模型自身知识补全未命中内容。API Key 和模型参数只存在服务器运行时 `.env`。
- Agent 为每个聊天请求输出一条 `rag_trace` 结构化记录，包含完整原始问题、问题分类、检索过程、Embedding 调用、引用、最终决策和各阶段耗时；分片级诊断记录稳定分片 ID、标题链、FTS/向量/RRF/规则总分排名、授权结果和最终上下文顺序，但不记录知识正文或向量。Docker `json-file` 日志按 `10m x 5` 轮转。完整输入属于需要受控的生产数据，不得记录请求头、API Key、知识正文或模型完整回答。
- 正式追踪查询接口为 `GET /api/agent/traces`，使用独立的 `X-RAG-Trace-Token` 请求头鉴权；未配置、缺失或错误 Token 均返回相同 `404`。接口返回当前进程最近 500 条有界内存副本，容器重启后清空，Docker 轮转日志仍是原始记录来源；查询 Token 只保存在服务器 `.env` 和受控的本地分析环境中，不能进入 URL、Widget、其他前端代码或 Git。
- 当前只保留最近 2 条有效用户问题用于明确的省略式追问，不把 assistant 回答传给模型；快速输入已有提交锁和输入法组合态保护。
- 限流为每个来源 IP 每分钟 20 次；达到上限返回 `429 + Retry-After + RATE_LIMIT_EXCEEDED`，Widget 显示剩余等待秒数。
- Agent 与公网之间只有一层 edge Nginx，生产必须配置 `TRUST_PROXY=1`；`true` 会被配置校验拒绝，避免客户端通过伪造 `X-Forwarded-For` 绕过按 IP 限流。
- Agent SSE 的 edge 特殊边界：
  - `siyes_agent_upstream` 不得配置 Nginx upstream keepalive。
  - `/api/agent/` 必须清空 `Upgrade`、设置 `Connection close`，并保留 HTTP/1.1、`proxy_buffering off` 和长读取超时。
  - 其他服务，尤其 Socket.IO 的 WebSocket Upgrade 和 keepalive 不受此规则影响。
  - 修改后连续请求 21 次验证：前 20 次 `200`，第 21 次 `429 + Retry-After`；无 `X-Request-Id` 的 `400` 优先排查 edge。

## 源码仓库与本地目录

- `E:\本地项目\siyeWorld` → [siyesummer/siyeWorld](https://github.com/siyesummer/siyeWorld)：前端主项目和 easy-chat。
- `E:\本地项目\NeteaseCloudMusicApi-private` → [siyesummer/NeteaseCloudMusicApi-private](https://github.com/siyesummer/NeteaseCloudMusicApi-private)：music-api。
- `E:\本地项目\java-project\linux-server` → [siyesummer/linux-server](https://github.com/siyesummer/linux-server)：Java 日志和聊天存储服务。
- `E:\本地项目\svg-draw` → [siyesummer/svg-draw](https://github.com/siyesummer/svg-draw)：SVG 工具。
- `E:\本地项目\frontend-knowledge` → 当前知识库仓库。
- `E:\本地项目\siyes-agent` → SIYES Agent 与 Widget。
- 历史服务器目录 `/opt/music-api`、`/opt/easy-chat`、`/opt/linux-server` 仅用于旧部署和回滚参考，不是当前生产来源。

## 应用能力现状

- siyeWorld 的开发、Docker production 和 GitHub Pages 分别使用 `.env.development`、`.env.production`、`.env.pages`，不能混用。
- 浏览器端 music-api、Socket、聊天历史和日志地址必须由 `VUE_APP_*` 提供，源码不得回退到 localhost、IP 或旧域名。
- easy-chat 只负责 Socket 广播；聊天持久化由前端直接调用 linux-server。
- 聊天消息保存在 MySQL `siye_chat.chat_message`，依赖 `(room_code, message_id)` 唯一键保证幂等。
- IP 只做聊天身份辅助识别，不能替代登录账号；同一 NAT 下可能误判为同一用户。
- 聊天前端已支持首屏加载、上拉分页、无更多提示，保存失败不阻断广播。
- 日志查询支持 `music-api`、`socket`、`chat-history` 和 `all`，由后端统一分页。

## 发布与安全边界

- 正式业务镜像优先由 GitHub Actions 手动 Workflow 构建并推送 Docker Hub；服务器通常只拉取明确版本，不现场构建业务源码。
- siyeWorld、music-api、linux-server、easy-chat、svg-draw 使用独立版本序列；Tag、Release、镜像标签和 commit SHA 应可追溯。
- 密钥、密码、Token、真实 IP、服务器 `.env` 和数据库连接信息不得进入 Git、镜像或前端 bundle。
- 回滚按单个 Compose 项目和明确镜像版本进行；不得用 `docker compose down -v`、`docker system prune`、`docker volume prune` 处理生产故障。
- 一次只修改一个服务或一个 Compose 项目。已有健康服务不因无关任务重建，数据库和数据卷尤其如此。
- 不猜测端口、容器名、Compose 项目名、挂载路径或镜像版本；以 `docker compose config`、`docker inspect`、`docker network inspect`、`ss` 和实际文件为准。
- 不覆盖服务器 `.env`、证书、数据库数据和生产配置；示例 `.env` 不能作为正式凭据。
- Git 更新前检查工作区，使用 `git pull --ff-only`；不得用 `reset --hard` 覆盖来源不明的本地修改。
- 生产验收同时检查 HTTP 状态、响应体、请求 ID、容器健康、日志和真实浏览器行为；HTTP `200` 不等于业务内容正确。

## 公开知识边界

- 根目录 [knowledge-public.json](./knowledge-public.json) 是在线知识库、GitHub Pages 和 SIYES Agent 共用的公开边界，不能分别维护规则。
- 当前公开通用前端、Promise、Docker 等学习资料；隐藏 `AGENTS.md`、清单本身、Docker 演练与正式部署、Linux 部署和 md-viewer 内部资料。
- md-viewer 的目录树、文件接口、WebSocket 监听和 Pages 静态生成都执行同一策略；隐藏文件直接请求返回 `404`。
- 新增内部目录时同步更新清单；需要公开实战内容时整理脱敏版本，不直接开放生产配置、演练目录或服务器记录。

## 已完成实践结论

- 已完成从 systemd/目录部署、临时 IP 联调、Docker 单服务演练、多服务 Compose、准生产演练到正式 Docker 全量部署与 HTTPS 切流的完整路径。
- 已验证 Docker 内部 DNS、网络隔离、数据库持久化、日志挂载、CORS、Socket.IO、HTTPS/SNI、证书自动续期、版本升级与回滚思路。
- 正式业务、知识库、主站和 SIYES Agent 均已上线；后续以当前 Docker 生产基线演进，不再把旧 systemd 或临时公网端口当作正式入口。
- 历史演练的命令、端口、镜像 digest、验收证据和阶段记录保留在对应文档，需要时按索引查阅。

## 文档索引

- 仓库总览：[README.md](./README.md)
- Docker 学习入口：[Docker专题/README.md](./Docker专题/README.md)
- Docker 基础命令：[Docker专题/Docker命令说明.md](./Docker专题/Docker命令说明.md)
- 正式 Docker 部署基线：[Docker专题/正式部署/siye-stack/README.md](./Docker专题/正式部署/siye-stack/README.md)
- Docker edge 配置：[Docker专题/正式部署/siye-stack/edge](./Docker专题/正式部署/siye-stack/edge)
- Certbot 自动续期：[Docker专题/正式部署/siye-stack/certbot/README.md](./Docker专题/正式部署/siye-stack/certbot/README.md)
- Docker 入口切流与回滚：[Docker专题/正式部署/siye-stack/Docker入口直连切流-v2/README.md](./Docker专题/正式部署/siye-stack/Docker入口直连切流-v2/README.md)
- 历史宿主机 Nginx 切流：[Docker专题/正式部署/siye-stack/宿主机Nginx切流/README.md](./Docker专题/正式部署/siye-stack/宿主机Nginx切流/README.md)
- 准生产发布演练：[Docker专题/Docker演练/siye-release-drill](./Docker专题/Docker演练/siye-release-drill)
- 多服务 Compose 演练：[Docker专题/Docker演练/siye-stack/Docker演练步骤.md](./Docker专题/Docker演练/siye-stack/Docker演练步骤.md)
- Linux 历史部署资料：[Linux部署/README.md](./Linux部署/README.md)
- knowledge.siyes.cn 部署：[md-viewer/deploy/README.md](./md-viewer/deploy/README.md)
- SIYES Agent 架构：`E:\本地项目\siyes-agent\docs\RAG-ARCHITECTURE.md`
- SIYES Agent 索引生命周期与预热：`E:\本地项目\siyes-agent\docs\RAG-INDEX-LIFECYCLE-AND-WARMUP.md`
- SIYES Agent 检索升级计划：`E:\本地项目\siyes-agent\docs\RAG-RETRIEVAL-UPGRADE-PLAN.md`
- SIYES Agent 可观测性：`E:\本地项目\siyes-agent\docs\RAG-OBSERVABILITY.md`

> 历史文档可能保留当时状态。当前生产操作以本文件“当前生产基线”、服务器实际 Compose 和实时检查为准；历史文档用于学习复盘，不可未经核对直接照搬。

## 协作约定

- 默认使用中文，说明保持清晰、可执行，并适合正在转全栈的前端开发者理解。
- SIYES Agent 做技术升级时，不能只给实现步骤或技术名词。实施前后应结合当前 RAG 完整链路，详细说明该技术产生的背景、要解决的现有问题、所在处理阶段、核心原理、数据如何流动、为什么可能提高质量、局限与取舍、依赖和成本，以及如何用固定评测集证明它确实有效。
- RAG 升级形成的架构、实现、配置、评测方法和结果统一沉淀到 `E:\本地项目\siyes-agent\docs`；优先维护 `RAG-ARCHITECTURE.md` 和 `RAG-EVALUATION-CASES.md`，必要时新增专题文档。`AGENTS.md` 只保留这类长期协作原则，不记录逐次实验流水。
- 新增知识优先放入专题文档，不继续膨胀 `AGENTS.md`。
- `AGENTS.md` 只维护长期有效的项目定位、用户背景、当前生产状态、关键边界和索引；单次输出、逐日流水和可在其他文档查到的细节不再写入。
- 状态变化时更新对应结论并删除被替代的信息，不在文件末尾继续叠加“最近更新”。
