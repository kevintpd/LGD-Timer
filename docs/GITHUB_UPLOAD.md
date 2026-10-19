# GitHub 首次上传指南

## 当前状态

- 已有本地 Git 仓库，当前分支为 `main`，整理时未配置远程仓库。
- README、截图图集和 `.gitignore` 已准备。
- 应用代码和工程文件已有未提交改动，上传前应一起检查。
- 尚未选择许可证；公开仓库与授予开源使用许可是两件事。

## 1. 在 GitHub 新建空仓库

建议名称：`LGD-Timer`

建议 Description：`A SwiftUI discussion timer for iPhone and Apple Watch, with speaker timing and session history.`

选择 Public（公开展示）或 Private（仅授权用户可见）。因为本地已经有 README 和 Git 历史，新建远程仓库时不要勾选自动添加 README、.gitignore 或 License。

## 2. 整理并提交本地文件

在终端执行：

```bash
cd "/Users/tanpengda/Desktop/LGD Timer"

# 个人 Xcode 配置之前已被跟踪，.gitignore 不会自动取消跟踪。
# 此命令仅从 Git 索引移除，保留本地文件；不会清理过去的提交。
git rm --cached -- "LGD Timer.xcodeproj/xcuserdata/tanpengda.xcuserdatad/xcschemes/xcschememanagement.plist"

git add .
git diff --cached --stat
git diff --cached --check
```

查看待提交内容，确认应用代码、AppIcon、共享 Scheme、文档和截图均已包含。个人开发团队 ID 和 Bundle Identifier 在工程文件中，它们不是签名私钥；其他开发者运行时应替换签名配置。不要上传证书、私钥或令牌。

确认后提交：

```bash
git commit -m "Prepare LGD Timer for GitHub with documentation and screenshots"
```

已有提交历史会随推送上传，包括过去跟踪的个人配置；如果不希望公开旧历史，先处理再推送。

## 3. 关联并推送

先将下方 `YOUR_USERNAME` 换成自己的 GitHub 用户名，仓库名须与实际创建的一致：

```bash
git remote add origin https://github.com/YOUR_USERNAME/LGD-Timer.git
git push -u origin main
```

HTTPS 身份验证按 GitHub 的登录提示完成；不要把令牌写进仓库文件或远程地址。如果提示 `origin already exists`，先用 `git remote -v` 核对已有地址，避免重复添加。

## 4. 上传后检查

- README 中的两组预览图和完整图集能正常打开。
- 两个应用源码目录、工程文件、资源和共享 Scheme 均存在。
- 后续修改使用 `git add .`、`git commit`、`git push` 更新。
- 建议首次发布前在 Xcode 中分别运行 iPhone 和 Watch Scheme，检查切换发言者、结束保存和历史记录。
- 如需开源，另行确定许可证并添加 `LICENSE`；本次没有代选授权条款。

截图已使用仓库内相对路径引用，和代码一起推送即可，不必手动逐张上传到 GitHub。

参考：[GitHub 官方：上传本地代码](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)。
