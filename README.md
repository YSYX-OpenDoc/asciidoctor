# asciidoctor

本仓库对 asciidoctor 进行了打包，加入了一些对 cjk 支持的修复。

# 构建

```bash
nix build .
```

# 开发

进入 nix shell

```bash
nix develop
```

修改 asciidoctor 目录中的库后使用命令

```bash
gen
```

以生成 lock, 重新构建或重新进入 nix shell 即可获得修改后的 asciidoctor

# commit

使用 git subtree 来管理 fork 的 gem 依赖，建议在上游 commit 之后 pull 到该仓库或改完之后同步回上游。

# docker

```bash
nix run .#docker.copyToDocker
```
