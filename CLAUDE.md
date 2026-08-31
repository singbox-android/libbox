# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库性质

这不是源码仓库,而是 **sing-box Android 库(libbox)的 JitPack 分发仓库**。Git 只跟踪构建/发布配置(`build.gradle`、`jitpack.yml`、`libbox-sources.jar` 等);真正的产物 `libbox.aar`(约 112MB)来自上游 [SagerNet/sing-box](https://github.com/SagerNet/sing-box),因超过 GitHub 100MB 限制不入库,通过 GitHub Releases 分发,构建时自动下载。

没有 settings.gradle、没有源码、没有测试——仓库的全部价值在于把上游 sing-box 版本以 `com.github.singbox-android:libbox:<version>` 的坐标发布到 JitPack,供 Flutter/Android 项目(如 Clash Sing)消费。

## 常用命令

```bash
# JitPack 实际执行的构建命令,本地验证发布配置时使用
# (自动触发 downloadLibboxAar,缺失时从 GitHub Releases 拉取 libbox.aar)
./gradlew publishToMavenLocal

# 仅下载缺失的 libbox.aar
./gradlew downloadLibboxAar
```

- Gradle 8.14.3,JDK 17(jitpack.yml 指定 openjdk17)
- 无 lint、无测试任务

## 升级 sing-box SDK 的工作流

此仓库几乎唯一的重复性任务(见 git log)。关键顺序约束:**必须先把新版 libbox.aar 上传到 GitHub Releases,再推送 tag**,否则 JitPack 构建时 downloadLibboxAar 会 404。

1. 从上游 sing-box 源码构建(或获取)新版的 `libbox.aar` 与 `libbox-sources.jar`
2. 将 `libbox.aar` 上传为 GitHub Release 资产,**Release tag 名必须等于 build.gradle 中的 version**(下载 URL 由它拼接)
3. 用新版替换仓库根目录的 `libbox-sources.jar`(此文件入库)
4. 更新 `build.gradle` 第 6 行的 `version`
5. 提交(commit 消息用简体中文,惯例:`chore(build): sing-box sdk 升级到 X.Y.Z`),打同名 tag,推送 tag 触发 JitPack 构建
6. 在 jitpack.io 确认构建成功后再通知下游消费方升级

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **libbox** (21 symbols, 14 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/libbox/context` | Codebase overview, check index freshness |
| `gitnexus://repo/libbox/clusters` | All functional areas |
| `gitnexus://repo/libbox/processes` | All execution flows |
| `gitnexus://repo/libbox/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
