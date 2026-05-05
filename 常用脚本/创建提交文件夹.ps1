# 设置编码
chcp 65001 > $null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    正在创建文档目录结构..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 切换到D盘根目录
Set-Location "D:\"

# 创建主文件夹
$mainPath = "D:\sharedoc"
if (-not (Test-Path $mainPath)) {
    New-Item -ItemType Directory -Path $mainPath -Force | Out-Null
    Write-Host "[创建] sharedoc 主文件夹" -ForegroundColor Green
} else {
    Write-Host "[存在] sharedoc 主文件夹已存在" -ForegroundColor Yellow
}

# 定义目录结构
$directories = @(
    "工作文档",
    "工作文档\项目文档",
    "学习笔记",
    "学习笔记\C++",
    "学习笔记\Qt",
    "学习笔记\SqlServer",
    "学习笔记\Git",
    "常用脚本",
    "个人",
    "个人\日记",
    "个人\自考",
    "模板"
)

D:\sharedoc\
├── 工作文档\
│   ├── 项目文档\
├── 学习笔记\
│   ├── C++\
│   ├── Qt\
│   ├── SqlServer\
│   └── Git\
├── 常用脚本\
├── 个人\
│   └── 日记\
│   └── 自考\
├── 模板\
├── .gitignore
└── README.md


# 批量创建目录
Write-Host ""
Write-Host "--- 创建文件夹 ---" -ForegroundColor Cyan
foreach ($dir in $directories) {
    $fullPath = Join-Path $mainPath $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "[创建] $dir\" -ForegroundColor Green
    } else {
        Write-Host "[存在] $dir\" -ForegroundColor Yellow
    }
}

# 创建.gitignore
Write-Host ""
Write-Host "--- 创建配置文件 ---" -ForegroundColor Cyan
$gitignorePath = Join-Path $mainPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    $gitignoreContent = @"
# 系统文件
Thumbs.db
.DS_Store
desktop.ini

# 临时文件
*.tmp
*.temp
*~

# Office临时文件
~$*.docx
~$*.xlsx
~$*.pptx

# 日志文件
*.log

# 大型二进制文件
*.pdf
*.zip
*.rar
*.7z
*.exe

# 敏感信息
*密码*.txt
*账号*.xlsx
*密钥*.txt

# IDE配置
.vscode/
.idea/

# Python缓存
__pycache__/
*.pyc
"@
    Set-Content -Path $gitignorePath -Value $gitignoreContent -Encoding UTF8
    Write-Host "[创建] .gitignore" -ForegroundColor Green
} else {
    Write-Host "[存在] .gitignore 已存在" -ForegroundColor Yellow
}

# 创建README.md
$readmePath = Join-Path $mainPath "README.md"
if (-not (Test-Path $readmePath)) {
    $readmeContent = @"
# 我的文档库

## 目录结构

\`\`\`
D:\sharedoc\
├── 工作文档\
│   ├── 项目文档\
├── 学习笔记\
│   ├── C++\
│   ├── Qt\
│   ├── SqlServer\
│   └── Git\
├── 常用脚本\
├── 个人\
│   └── 日记\
│   └── 自考\
├── 模板\
├── .gitignore
└── README.md
\`\`\`

## 使用说明

| 文件夹 | 用途 |
|--------|------|
| 工作文档 | 存放项目相关文件 |
| 学习笔记 | 记录学习心得和技术笔记 |
| 个人 | 个人日记和私人文档 |
| 模板 | 常用文档模板 |

## Git初始化命令

\`\`\`bash
# 进入目录
cd D:\sharedoc

# 初始化Git仓库
git init

# 添加所有文件
git add .

# 首次提交
git commit -m "初始化文档库"

# 添加远程仓库（替换为你的仓库地址）
git remote add origin https://github.com/你的用户名/sharedoc.git

# 推送到远程
git push -u origin main
\`\`\`

## 日常同步命令

\`\`\`bash
# 拉取最新更改
git pull

# 查看状态
git status

# 添加更改
git add .

# 提交更改
git commit -m "更新说明"

# 推送到远程
git push
\`\`\`
"@
    Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
    Write-Host "[创建] README.md" -ForegroundColor Green
} else {
    Write-Host "[存在] README.md 已存在" -ForegroundColor Yellow
}

# 创建示例文件
Write-Host ""
Write-Host "--- 创建示例文件 ---" -ForegroundColor Cyan

# Git学习笔记示例
$gitExamplePath = Join-Path $mainPath "学习笔记\Git\常用命令.md"
if (-not (Test-Path $gitExamplePath)) {
    $gitContent = @'
# Git常用命令速查表

## 基础命令
| 命令 | 说明 |
|------|------|
| `git init` | 初始化仓库 |
| `git clone [url]` | 克隆仓库 |
| `git add [file]` | 添加文件 |
| `git commit -m "msg"` | 提交更改 |

## 分支操作
- `git branch`：查看分支
- `git checkout -b [branch]`：创建并切换分支
- `git merge [branch]`：合并分支

## 同步命令
- `git pull`：拉取更新
- `git push`：推送更改
- `git fetch`：获取更新

## 查看信息
- `git status`：查看状态
- `git log`：查看历史
- `git diff`：查看差异
'@
    Set-Content -Path $gitExamplePath -Value $gitContent -Encoding UTF8
    Write-Host "[创建] 学习笔记\Git\常用命令.md" -ForegroundColor Green
}

# 日记模板
$diaryTemplatePath = Join-Path $mainPath "模板\日记模板.txt"
if (-not (Test-Path $diaryTemplatePath)) {
    $diaryContent = @'
【日期】：____年__月__日
【星期】：__
【天气】：☀️ 🌤 ☁️ 🌧 ⛈
【心情】：😊 😐 😢 😤

【今日完成】：
1. 
2. 
3. 

【心得体会】：


【遇到的问题及解决方案】：


【明日计划】：
1. 
2. 
3. 

【碎碎念】：

'@
    Set-Content -Path $diaryTemplatePath -Value $diaryContent -Encoding UTF8
    Write-Host "[创建] 模板\日记模板.txt" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     目录结构创建完成！" -ForegroundColor Green
Write-Host "     位置：D:\sharedoc\" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步操作：" -ForegroundColor Yellow
Write-Host "1. 进入目录：cd D:\sharedoc" -ForegroundColor White
Write-Host "2. 初始化Git：git init" -ForegroundColor White
Write-Host "3. 首次提交：git add . && git commit -m '初始化'" -ForegroundColor White
Write-Host "4. 连接远程仓库：git remote add origin [你的仓库地址]" -ForegroundColor White
Write-Host ""
pause