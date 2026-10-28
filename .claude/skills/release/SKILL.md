---
name: release
description: 发布 aMusic 新版本：根据上个版本以来的改动生成中文 release note，推送 version tag 触发 CI，等 CI 完成后发布带 release note 的 GitHub Release。用户说“发布”“发版”“release”“打 tag”时使用。
argument-hint: "[版本号，如 2.0.0；省略则让用户选择]"
---

# 发布 aMusic

发布流程由 `.github/workflows/release.yml` 驱动：推送 `v*` tag 后，五个平台（android / macos / ios / windows / linux）并行构建，并由 `svenstaro/upload-release-action` 把产物上传到该 tag 的 GitHub Release（Release 不存在时自动创建，但没有说明文字）。
本 skill 负责：生成中文 release note → 推 tag → 等 CI → 把 release note 写进 Release 并确保它处于已发布状态。

所有 Release 文案一律使用**中文**。

## 1. 前置检查

```bash
git status --porcelain          # 必须为空；否则停下，让用户先提交或说明
git branch --show-current       # 应为 main；否则先确认
git fetch origin --tags
git rev-list --left-right --count origin/main...HEAD   # 本地不能落后于远端；领先的提交需先 push
gh auth status
```

- 工作区不干净、落后远端、`gh` 未登录：停下并告诉用户，不要自行处理。
- 本地领先远端时，说明后在 tag 之前 `git push origin main`（tag 必须指向 CI 能 checkout 到的提交）。

## 2. 确定版本号

- 上个版本：`git describe --tags --abbrev=0 --match 'v*'`（没有则视为首次发布，范围取全部历史）。
- 新版本号：取参数；没给就读 `pubspec.yaml` 的 `version:`，并结合改动性质（破坏性/新功能/修复）给出建议，让用户确认。tag 形如 `v2.0.0`；带 `-` 的（如 `v2.1.0-beta.1`）视为预发布。
- tag 已存在（本地或远端）则停下询问，**不要**删除或覆盖已有 tag。
- `pubspec.yaml` 的 `version:`（`x.y.z+build`）应与 tag 一致，应用内更新检查依赖它。若不一致，把它改为新版本并将 build 号 +1，单独提交 `chore: release vX.Y.Z` 并 push，再继续。

## 3. 生成 release note

收集上个 tag 到 HEAD 的改动：

```bash
git log <上个tag>..HEAD --no-merges --pretty='%h %s%n%b---'
git diff --stat <上个tag>..HEAD
```

提交信息只是线索，必要时读 diff 弄清楚用户可感知的变化。写成面向**用户**的中文说明，而不是提交流水账：

```markdown
## 新功能
- ……

## 优化与改进
- ……

## 问题修复
- ……

## 其他
- 内部重构、依赖升级、测试等（没有就省略这一节）

**完整变更**：https://github.com/tyuan511/aMusic/compare/<上个tag>...<新tag>
```

要求：
- 按用户视角归并同类提交，每条一句话，说明“变了什么/带来什么好处”，不要贴 commit hash 或文件名。
- 没有内容的分类整节省略；不要编造提交里没有的改动。
- 破坏性变更（如数据迁移、设置重置）放最前并加粗说明。
- 写入 scratchpad 目录下的 `release-notes-<tag>.md`，并**把全文展示给用户，等待确认或修改**后才能继续。

## 4. 推送 tag（需用户确认）

用户确认 release note 后，创建 annotated tag 并推送；推送后会触发 CI，所以这是真正的发布动作：

```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

## 5. 等待 CI

```bash
# 推送后 run 可能要几秒才出现
gh run list --workflow release.yml --branch vX.Y.Z --limit 1 --json databaseId,status,url
gh run watch <databaseId> --exit-status --interval 30
```

- 构建耗时较长，用 `run_in_background` 或 Monitor 等待，不要轮询刷屏。
- 全部 job 成功才继续。有 job 失败：用 `gh run view <id> --log-failed` 找原因并向用户汇报；修复需要新提交的话，不要移动已推送的 tag，与用户商量后再决定（重打新版本号，或经确认后删除重推）。可以只重跑失败的 job：`gh run rerun <id> --failed`。

## 6. 发布 Release 并带上 release note

CI 成功后 Release 已由 upload-release-action 创建并带有各平台产物，这一步写入说明：

```bash
gh release view vX.Y.Z --json isDraft,isPrerelease,assets --jq '{isDraft,isPrerelease,assets:[.assets[].name]}'
```

- Release 存在：`gh release edit vX.Y.Z --title "aMusic vX.Y.Z" --notes-file <notes文件> --draft=false`（预发布版本加 `--prerelease`，正式版加 `--latest`）。
- Release 不存在（异常情况）：`gh release create vX.Y.Z --title "aMusic vX.Y.Z" --notes-file <notes文件> --verify-tag`，并告知用户产物缺失。
- 核对产物齐全：`aMusic-macos.zip`、`aMusic-ios-unsigned.ipa`、`aMusic-windows-x64.zip`、`aMusic-linux-x64.tar.gz`，以及 `*.apk`（按 ABI 拆分）。缺哪个就如实告知。

## 7. 收尾

向用户汇报：版本号、Release 链接（`gh release view vX.Y.Z --json url --jq .url`）、产物列表、CI 耗时/是否有重跑。若中途有跳过或未验证的步骤，明确写出。
