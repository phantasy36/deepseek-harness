# ---------- 构建阶段 ----------
FROM node:22-slim AS builder

# 安装 pnpm 及构建所需的基础工具
RUN corepack enable && corepack prepare pnpm@latest --activate \
    && apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 先复制依赖清单，利用 Docker 层缓存加速后续安装
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches
RUN pnpm install --frozen-lockfile

# 复制全部源码并执行构建
COPY . .
RUN pnpm run build

# 裁剪掉 devDependencies，只保留生产环境依赖
RUN pnpm prune --prod

# ---------- 运行阶段 ----------
FROM node:22-slim AS runner

# 安装 pnpm 供运行时使用（dsh 通过 pnpm 脚本启动）
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 从构建阶段复制已构建好的产物与生产依赖
COPY --from=builder /app ./

# Web UI 默认监听 3080 端口，需与 dsh 的默认值保持一致
EXPOSE 3080

# --no-open 阻止容器内尝试拉起浏览器，--host 0.0.0.0 允许外部访问
CMD ["pnpm", "dsh", "web", "--no-open", "--host", "0.0.0.0"]
