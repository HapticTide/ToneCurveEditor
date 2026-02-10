# AGENTS.md

## 语言与沟通
- 默认使用简体中文回复，除非用户明确要求其他语言。
- 面向有经验开发者，避免基础语法教学。

## 代码与实现约束
- 项目为 iOS only，最低 iOS 15.0。
- 不引入 `#if canImport(UIKit)` 与 `@available(iOS 15.0, *)` 这类冗余条件编译。
- 优先补齐 Core 可测试性与稳定性，再扩展 UI/渲染能力。

## 工具链约束
- 构建与测试优先使用 XcodeBuildMCP 工具。
- 不直接使用 `xcodebuild`、`swift build`、`swift test`。
- 代码格式化使用仓库根目录 `.swiftformat`。

## 变更安全边界
- 下列操作必须先征得用户确认：
  - 删除文件
  - 修改公共 API
  - 新增第三方依赖
- 仅在用户明确同意后执行 `git commit`。
- 禁止执行：`git push`、`git push --force`。
- 未经明确要求，不执行破坏性 Git 操作（如 `git reset --hard`、`git clean -f`、`git rebase`、`git commit --amend`）。

## 测试组织
- Core 测试保持在 SwiftPM：`Tests/ToneCurveEditorTests/Core`。
- Demo 测试仅覆盖集成烟测，不混入 Core 细粒度单测。
