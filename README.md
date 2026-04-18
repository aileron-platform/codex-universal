# codex-universal

基於 [OpenAI codex-universal](https://github.com/openai/codex-universal) 的自訂版本，作為 `workspace-runtime` 的 base image。

## 與公版的差異

公版以 `root` 身份執行所有安裝，工具路徑在 `/root/` 底下。
本專案修改為以 `developer` 使用者執行，工具安裝在 `/home/developer/` 底下，
以便 workspace-runtime container 內以非 root 身份運行服務。

主要修改：
- 新增 `developer` 使用者（含 sudo 免密碼權限）
- 所有工具（pyenv、nvm、mise、pipx）安裝在 `/home/developer/` 路徑
- 移除本專案不需要的語言（Rust、Go、Swift、Ruby、PHP、Elixir、Bun、LLVM 等）
- 精簡 Java 版本（僅保留 8、17、21）

## Build

此 image 需要 **pre-build**，workspace-runtime 透過 `docker-image://` 引用它。

```bash
# 首次或修改 Dockerfile 後執行（僅需一次）
docker build -t jarvischen/codex-universal:custom ./workspace-runtime/codex-universal

# 之後就可以正常 build workspace-runtime
docker compose build workspace-runtime
```

> **注意**：首次 build 需下載並編譯 Python、Node.js、Java 等，耗時較長（約 30-60 分鐘）。
> 後續 rebuild 若未修改 Dockerfile，Docker layer cache 會大幅加速。

## 為什麼不能用 additional_contexts 直接 inline build？

Docker Compose 的 `additional_contexts` 搭配本地目錄時，BuildKit 會嘗試 inline build，
但此 Dockerfile 安裝內容龐大，inline build 容易失敗並產出損壞的 image，
導致 workspace-runtime Dockerfile 中的 `USER root` 出現 `unable to find user root` 錯誤。

改用 `docker-image://jarvischen/codex-universal:custom` 引用 pre-built image 可避免此問題。

## docker-compose.yml 設定

```yaml
workspace-runtime:
  build:
    additional_contexts:
      codex-universal: docker-image://jarvischen/codex-universal:custom
```

## 語言環境

| 語言    | 版本                                    | 管理工具 |
| ------- | --------------------------------------- | -------- |
| Python  | 3.10, 3.11.12, 3.12, 3.13, 3.14.0      | pyenv    |
| Node.js | 18, 20, 22, 24                          | nvm      |
| Java    | 8, 17, 21                               | mise     |

### 執行時版本切換

透過 `CODEX_ENV_*` 環境變數設定：

| 環境變數                   | 說明              |
| -------------------------- | ----------------- |
| `CODEX_ENV_PYTHON_VERSION` | Python 版本       |
| `CODEX_ENV_NODE_VERSION`   | Node.js 版本      |

詳見 `setup_universal.sh`。
