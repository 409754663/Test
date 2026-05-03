# 我的文档库

## 目录结构

\\\
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
\\\

## 使用说明

| 文件夹 | 用途 |
|--------|------|
| 工作文档 | 存放项目相关文件 |
| 学习笔记 | 记录学习心得和技术笔记 |
| 个人 | 个人日记和私人文档 |
| 模板 | 常用文档模板 |

## Git初始化命令

\\\ash
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
\\\

## 日常同步命令

\\\ash
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
\\\
