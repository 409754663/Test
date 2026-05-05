# 混凝土ERP - 多租户与跨站协作架构设计

## 文档说明

本文档定义了混凝土ERP系统中，**租户、组织层级、协作域、公告与知识库**四种核心跨租户机制的设计方案。每种机制对应不同的业务场景，互补而非重叠。

------

## 一、总体架构概览

系统采用**"租户为基座，四种机制各司其职"**的架构模式：

| 机制                            | 业务场景                 | 数据流向     | 权限类型  |
| :------------------------------ | :----------------------- | :----------- | :-------- |
| **租户（Tenant）**              | 独立站点日常经营         | 站内闭环     | 完整操作  |
| **组织层级（Parent-Child）**    | 集团报表审阅、子公司管理 | 单向向上汇总 | 只读穿透  |
| **协作域（Collaboration Hub）** | 跨站集中调度、集中采购   | 双向协同     | 操作共享  |
| **公告与知识库**                | 集团信息下发、共享资料   | 单向向下广播 | 发布-订阅 |

text

```
┌─────────────────────────────────────────────────────────────────┐
│                       混凝土ERP系统                              │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ 公告与知识库  │  │ 集团报表中心  │  │  协作域工作台         │  │
│  │ (集团→全站)   │  │ (组织层级)    │  │  (集中调度/集采)      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
│         ▼                 ▼                      ▼              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              租户基座（独立搅拌站）                        │  │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐         │  │
│  │  │ 京西A站 │  │ 京西B站 │  │ 京东A站 │  │石家庄站 │  ...    │  │
│  │  └────────┘  └────────┘  └────────┘  └────────┘         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```



------

## 二、租户设计（Tenant）

### 适用业务场景

- 所有搅拌站都必须是一个租户
- 极小型客户：一个租户就是一个独立搅拌站，所有业务在站内闭环
- 集团客户：每个搅拌站各自是一个租户，数据独立隔离

### 为什么这么设计

1. **数据隔离是底线**：合同、配比、财务数据绝不能跨站泄露
2. **计费单元明确**：每个搅拌站独立付费、独立到期管理
3. **功能按需裁剪**：通过许可证机制，小客户只看基础功能，大客户开通高级包
4. **极小型客户无感**：他们登录后只有自己的站点，不接触任何跨站概念

### 设计内容

**数据库表：Sys_Tenants**

sql

```
CREATE TABLE Sys_Tenants (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    TenantCode      VARCHAR(20)  NOT NULL UNIQUE,   -- 租户编码，如 'BJ-JX-A01'
    TenantName      NVARCHAR(100) NOT NULL,          -- 租户名称
    TenantType      TINYINT NOT NULL DEFAULT 1,      -- 1=单站 2=集团
    ParentTenantId  INT NULL,                        -- 上级集团ID
    Status          TINYINT NOT NULL DEFAULT 1,      -- 1=正常 2=停用 3=过期
    AdminUserId     INT NULL,                        -- 管理员账号
    RegionCode      VARCHAR(10) NULL,                -- 地区编码
    ContactInfo     NVARCHAR(500) NULL,              -- 联系信息JSON
    ExpireDate      DATETIME2 NULL,                  -- 到期时间
    
    TenantId        INT NOT NULL DEFAULT 0,          -- 0=系统级数据
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy       INT NOT NULL,
    UpdatedBy       INT NOT NULL,
    IsDeleted       BIT NOT NULL DEFAULT 0
);
```



**数据库表：Sys_TenantLicenses（租户许可证）**

sql

```
CREATE TABLE Sys_TenantLicenses (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    TenantId        INT NOT NULL,
    PackageCode     VARCHAR(50) NOT NULL,            -- 'central_dispatch' | 'procurement' | 'report'
    StartDate       DATE NOT NULL,
    EndDate         DATE NOT NULL,
    IsActive        BIT NOT NULL DEFAULT 1,
    GrantedBy       INT NOT NULL,
    GrantedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsDeleted       BIT NOT NULL DEFAULT 0,
    
    UNIQUE INDEX UQ_TenantLicense (TenantId, PackageCode)
);
```



**许可证功能包定义：**

| 功能包代码            | 名称       | 适用客户               |
| :-------------------- | :--------- | :--------------------- |
| `basic_operation`     | 基础运营包 | 所有客户必选           |
| `material_mgmt`       | 物资管理包 | 所有客户必选           |
| `finance`             | 结算财务包 | 所有客户必选           |
| `equipment`           | 设备车辆包 | 大客户必选，小客户可选 |
| `central_dispatch`    | 集中调度包 | 仅大客户               |
| `central_procurement` | 集采中枢包 | 仅大客户               |
| `advanced_report`     | 高级报表包 | 大客户必选，小客户可选 |
| `regulatory_report`   | 监管上报包 | 所有客户必选           |

**后端实现：**

- 所有业务表包含 `TenantId` 字段
- `EF Core` 全局查询筛选器自动注入 `WHERE TenantId = @currentTenantId`
- 在协作域和报表审阅场景下，可通过 `IgnoreQueryFilters()` 临时解除此限制

**前端实现：**

- `Pinia` 存储当前租户的许可证列表
- 路由守卫根据许可证动态过滤菜单
- 极小型客户：不显示协作域、集团报表等菜单入口
- 大客户：根据已购包展示完整功能

------

## 三、组织层级设计（Parent-Child Hierarchy）

### 适用业务场景

- 集团财务总监查看所有子公司的应收应付汇总报表
- 集团技术总工审阅各站点的配合比使用情况
- 集团总经理查看各站点的生产日报、产值月报
- 注意：这是**只读审阅**，不是操作，不涉及跨站协同

### 为什么这么设计

1. **与协作域分离**：报表审阅是上下级关系，协作域是对等协同关系，混在一起权限模型会混乱
2. **单向只读**：集团可以向下看子公司数据，子公司不能反向查看集团或其他子公司
3. **精细化权限**：可以控制某人只能看"财务报表"而不能看"生产配比"，符合职责分离原则
4. **不干扰日常运营**：子公司的日常操作不受集团查看影响，数据查询走只读副本

### 设计内容

**利用已有字段：Sys_Tenants.ParentTenantId**

text

```
北京集团 (Id=100, ParentTenantId=NULL)
├── 京西A站 (Id=1, ParentTenantId=100)
├── 京西B站 (Id=2, ParentTenantId=100)
├── 京东A站 (Id=4, ParentTenantId=100)
└── 石家庄站 (Id=10, ParentTenantId=100)
```



**数据库表：Sys_ReportReviewPermissions（报表审阅权限）**

sql

```
CREATE TABLE Sys_ReportReviewPermissions (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    UserId          INT NOT NULL,                     -- 被授权的用户
    ParentTenantId  INT NOT NULL,                     -- 集团ID
    ChildTenantId   INT NOT NULL,                     -- 可审阅的子公司ID
    ReviewScope     VARCHAR(50) NOT NULL,             -- 'All' | 'Finance' | 'Production' | 'Quality'
    IsActive        BIT NOT NULL DEFAULT 1,
    
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy       INT NOT NULL,
    
    INDEX IX_ReportReview_User (UserId),
    UNIQUE INDEX UQ_ReportReview (UserId, ParentTenantId, ChildTenantId, ReviewScope)
);
```



**用户权限示例：**

| 用户   | 角色         | 可审阅范围                 |
| :----- | :----------- | :------------------------- |
| 张总   | 集团总经理   | 所有子公司 (All)           |
| 李财务 | 集团财务总监 | 所有子公司 (Finance)       |
| 王总工 | 集团技术总监 | 京西A站、京西B站 (Quality) |

**JWT Token 负载扩展：**

json

```
{
  "sub": "user_zhang",
  "report_review": {
    "parent_tenant_id": 100,
    "reviewable_tenants": [
      {"tenant_id": 1, "scope": "All"},
      {"tenant_id": 2, "scope": "All"},
      {"tenant_id": 4, "scope": "All"},
      {"tenant_id": 10, "scope": "All"}
    ]
  }
}
```



**后端实现：**

csharp

```
// 集团报表服务
public async Task<GroupFinanceReport> GetGroupFinanceReport(int userId, int parentTenantId, DateTime month)
{
    // 获取该用户有Finance审阅权限的所有子公司ID
    var childTenantIds = await _dbContext.Sys_ReportReviewPermissions
        .Where(p => p.UserId == userId 
                 && p.ParentTenantId == parentTenantId 
                 && p.ReviewScope == "Finance"
                 && p.IsActive)
        .Select(p => p.ChildTenantId)
        .ToListAsync();
    
    // 汇总查询所有子公司的财务数据
    return await _dbContext.FinanceRecords
        .IgnoreQueryFilters()  // 临时禁用单租户过滤
        .Where(r => childTenantIds.Contains(r.TenantId))
        .GroupBy(r => r.TenantId)
        .Select(g => new TenantFinanceSummary
        {
            TenantId = g.Key,
            TotalReceivable = g.Sum(r => r.Amount)
        })
        .ToListAsync();
}
```



**前端实现：**

- 仅当用户Token中存在 `report_review` 权限时，才显示**"集团报表中心"**菜单
- 进入后按报表类型（生产/财务/质量）分Tab展示
- 支持按站点筛选、按时间范围查询
- 图表展示各子公司对比数据

------

## 四、协作域设计（Collaboration Hub）

### 适用业务场景

**场景1：集中调度域**

- 京西片区下有A、B、C三个搅拌站，成立集中调度中心
- 调度员小王可以同时查看三个站的所有任务和车辆，统一排产、发车
- 每个任务数据标明来源站点

**场景2：集采中枢域**

- 北京地区所有站点（跨京西、京东片区）统一采购水泥
- 集团集采员可以管理共享供应商，查看各站库存消耗
- 各站点从集团合同下发起自己的采购单

**场景3：灵活租站**

- 某集团新租了一个站点，加入京西调度域，立即纳入统一调度
- 租赁到期后，从域中移除，恢复为独立运营

### 为什么这么设计

1. **对等关系而非层级**：调度域里A站和B站是平等的，没有上下级，与"组织层级"的上下级不同
2. **操作型而非只读**：域内用户可以操作任务、发车、下单，不仅是查看
3. **灵活组网**：一个站可以同时属于多个域（如既在调度域、又在集采域），域成员可以随时加入/退出
4. **与租户解耦**：协作域成员变动不影响站点内部的数据和逻辑，租站/停租操作非常简单

### 设计内容

**数据库表：Col_CollaborationHubs**

sql

```
CREATE TABLE Col_CollaborationHubs (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    HubCode         VARCHAR(30)  NOT NULL UNIQUE,    -- 'BJ-JX-Dispatch', 'BJ-Cement-Proc'
    HubName         NVARCHAR(100) NOT NULL,          -- '京西片区集中调度中心'
    HubType         VARCHAR(30)  NOT NULL,           -- 'CentralDispatch' | 'CentralProcurement'
    OwnerTenantId   INT NOT NULL,                    -- 域创建方（通常为集团租户）
    RegionCode      VARCHAR(10) NULL,
    Status          TINYINT NOT NULL DEFAULT 1,      -- 1=正常 2=停用
    ConfigJson      NVARCHAR(MAX) NULL,              -- 扩展配置JSON
    
    TenantId        INT NOT NULL,                    -- 数据归属租户
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy       INT NOT NULL,
    UpdatedBy       INT NOT NULL,
    IsDeleted       BIT NOT NULL DEFAULT 0
);
```



**数据库表：Col_TenantHubMembers**

sql

```
CREATE TABLE Col_TenantHubMembers (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    TenantId        INT NOT NULL,                    -- 参与协作的租户
    HubId           INT NOT NULL,                    -- 协作域ID
    JoinType        VARCHAR(20) NOT NULL DEFAULT 'FullMember', -- 'FullMember' | 'ViewOnly'
    JoinedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    LeftAt          DATETIME2 NULL,                  -- 退出时间（支持租新站/停租）
    IsActive        BIT NOT NULL DEFAULT 1,
    
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsDeleted       BIT NOT NULL DEFAULT 0,
    
    INDEX IX_TenantHubMembers_HubId (HubId),
    UNIQUE INDEX UQ_TenantHub (TenantId, HubId)
);
```



**数据示例：**

| 租户             | 加入的协作域               | 成员类型   |
| :--------------- | :------------------------- | :--------- |
| 京西A站 (ID=1)   | 京西调度域 (HubId=101)     | FullMember |
| 京西A站 (ID=1)   | 北京粉料集采域 (HubId=201) | FullMember |
| 京西B站 (ID=2)   | 京西调度域 (HubId=101)     | FullMember |
| 京西B站 (ID=2)   | 北京粉料集采域 (HubId=201) | FullMember |
| 京东A站 (ID=4)   | 北京粉料集采域 (HubId=201) | FullMember |
| 石家庄站 (ID=10) | 无                         | 无         |

**用户-协作域角色关联：**

sql

```
-- 在 Sys_UserRoleAssignments 表中：
INSERT INTO Sys_UserRoleAssignments (UserId, RoleCode, ScopeType, ScopeId)
VALUES 
    (123, 'HubScheduler', 'Hub', 101),  -- 小王是京西调度域的调度员
    (456, 'HubProcurement', 'Hub', 201); -- 老李是北京粉料集采域的采购员
```



**JWT Token 负载扩展：**

json

```
{
  "sub": "user_wang",
  "scope_permissions": [
    {
      "type": "Tenant",
      "id": 1,
      "name": "京西A站",
      "role": "ViewOnly"
    },
    {
      "type": "Hub",
      "id": 101,
      "name": "京西集中调度中心",
      "role": "HubScheduler",
      "hubType": "CentralDispatch",
      "accessibleTenants": [1, 2, 3]
    }
  ]
}
```



**后端实现：动态租户过滤器**

csharp

```
// 单租户模式（站内操作）
// 自动注入：WHERE TenantId = 1

// 协作域模式（跨站操作）
public async Task<List<TaskDto>> GetHubTasks(int hubId)
{
    // 1. 获取当前用户在此域内的可访问租户列表
    var accessibleTenants = _userContext.GetCurrentHubAccessibleTenants();
    
    // 2. 查询所有相关租户的任务
    return await _dbContext.ProductionTasks
        .IgnoreQueryFilters()  // 禁用单租户过滤
        .Where(t => accessibleTenants.Contains(t.TenantId))
        .Where(t => t.Status == "Pending")
        .OrderBy(t => t.ScheduledTime)
        .Select(t => new TaskDto
        {
            TaskId = t.Id,
            TenantId = t.TenantId,
            TenantName = t.Tenant.TenantName,  // 标注来源站点
            // ... 其他字段
        })
        .ToListAsync();
}
```



**前端实现：**

1. **上下文切换器**：顶栏显示 `🔽 京西集中调度中心`，下拉可选择其他站点或协作域
2. **协作域工作台**：切换到协作域后，显示专属的集中调度界面
3. **数据来源标识**：列表中每条数据用不同颜色标签标明来源站点（京西A站、京西B站）
4. **操作鉴权**：前端发送请求时携带 `X-Scope-Type: Hub` 和 `X-Scope-Id: 101`

**API路径约定：**

| API路径                           | 作用域 | 说明       |
| :-------------------------------- | :----- | :--------- |
| `/api/v1/tenant/{tenantId}/tasks` | 单租户 | 站内操作   |
| `/api/v1/hub/{hubId}/tasks`       | 协作域 | 跨站协同   |
| `/api/v1/hub/{hubId}/vehicles`    | 协作域 | 统一车辆池 |

------

## 五、公告与知识库设计

### 适用业务场景

- 集团发布"水泥供应商名录更新通知"，所有子公司采购部门可见
- 集团发布"冬季施工配合比调整规范"，所有子公司技术部门可见
- 集团发布"安全培训通知"，要求各站点人员已读确认
- 集团共享"常用原材检验标准"、"政府监管文件模板"等知识资料

### 为什么这么设计

1. **一对多广播**：发布者（集团）→ 订阅者（所有子公司），与协作域的双向协同完全不同
2. **内容管理属性**：有时效性（发布/过期）、有类别（通知/政策/培训）、有已读追踪
3. **轻量松耦合**：子公司只是接收信息，不改变自身业务逻辑，无需纳入协作域
4. **独立模块**：公告系统是独立功能，可单独开发、单独部署，不侵入核心业务

### 设计内容

**数据库表：Info_Announcements**

sql

```
CREATE TABLE Info_Announcements (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    PublisherTenantId INT NOT NULL,                   -- 发布者租户ID（集团）
    Title           NVARCHAR(200) NOT NULL,
    Content         NVARCHAR(MAX) NULL,
    Category        VARCHAR(50) NOT NULL,             -- 'Notice' | 'Policy' | 'Training' | 'SupplierInfo'
    Priority        TINYINT NOT NULL DEFAULT 0,       -- 0=普通 1=重要 2=紧急
    IsPinned        BIT NOT NULL DEFAULT 0,
    PublishAt       DATETIME2 NOT NULL,
    ExpireAt        DATETIME2 NULL,
    
    TenantId        INT NOT NULL,                     -- 数据归属（发布者）
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy       INT NOT NULL,
    UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedBy       INT NOT NULL,
    IsDeleted       BIT NOT NULL DEFAULT 0
);
```



**数据库表：Info_AnnouncementTargets**

sql

```
CREATE TABLE Info_AnnouncementTargets (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    AnnouncementId  INT NOT NULL,
    TargetTenantId  INT NOT NULL,                     -- 目标子公司
    IsReadRequired  BIT NOT NULL DEFAULT 0,           -- 是否要求已读确认
    
    INDEX IX_AnnouncementTargets_AnnId (AnnouncementId),
    INDEX IX_AnnouncementTargets_TenantId (TargetTenantId)
);
```



**数据库表：Info_AnnouncementReadLogs**

sql

```
CREATE TABLE Info_AnnouncementReadLogs (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    AnnouncementId  INT NOT NULL,
    UserId          INT NOT NULL,
    TenantId        INT NOT NULL,                     -- 阅读时用户所属租户
    ReadAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    
    UNIQUE INDEX UQ_ReadLog (AnnouncementId, UserId)
);
```



**数据库表：Info_SharedKnowledge**

sql

```
CREATE TABLE Info_SharedKnowledge (
    Id              INT IDENTITY(1,1) PRIMARY KEY,
    PublisherTenantId INT NOT NULL,
    Title           NVARCHAR(200) NOT NULL,
    Content         NVARCHAR(MAX) NULL,
    Category        VARCHAR(50) NOT NULL,             -- 'SupplierList' | 'MixDesign' | 'Process' | 'Regulation'
    AttachmentsJson NVARCHAR(MAX) NULL,               -- 附件列表JSON
    Version         INT NOT NULL DEFAULT 1,
    
    TenantId        INT NOT NULL,
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy       INT NOT NULL,
    UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedBy       INT NOT NULL,
    IsDeleted       BIT NOT NULL DEFAULT 0
);
```



**API设计：**

| 方法 | API路径                                        | 说明                 | 权限       |
| :--- | :--------------------------------------------- | :------------------- | :--------- |
| POST | `/api/v1/info/announcements`                   | 发布公告             | 集团管理员 |
| GET  | `/api/v1/info/announcements`                   | 获取当前租户可见公告 | 所有用户   |
| PUT  | `/api/v1/info/announcements/{id}/read`         | 标记已读             | 所有用户   |
| GET  | `/api/v1/info/announcements/{id}/read-stats`   | 查看已读统计         | 集团管理员 |
| GET  | `/api/v1/info/knowledge?category=SupplierList` | 获取共享知识         | 子公司用户 |

**前端实现：**

1. **首页公告横幅**：登录后首页顶部展示未读重要公告
2. **公告中心页面**：独立的公告列表页，支持按类别筛选
3. **已读追踪**：集团管理员可查看各站已读/未读人员列表
4. **知识库标签页**：在物资管理模块嵌入"集团共享供应商"标签
5. **移动端推送**：紧急公告通过消息通知推送

------

## 六、四种机制完整对比

| 维度           | 租户               | 组织层级                    | 协作域                  | 公告与知识库             |
| :------------- | :----------------- | :-------------------------- | :---------------------- | :----------------------- |
| **核心目的**   | 数据隔离与计费     | 集团向下审阅                | 跨站业务协同            | 集团信息下发             |
| **数据流向**   | 站内闭环           | 单向向上汇总                | 双向操作共享            | 单向向下广播             |
| **权限性质**   | 完整操作           | 只读穿透                    | 操作共享                | 发布-订阅                |
| **成员关系**   | 独立单元           | 父子从属                    | 对等成员                | 发布者-订阅者            |
| **变动频率**   | 极少               | 极少                        | 较频繁（租站/停租）     | 频繁（按需发布）         |
| **适用客户**   | 所有               | 集团客户                    | 集团客户                | 集团客户                 |
| **小客户可见** | 是，唯一界面       | 否，菜单隐藏                | 否，菜单隐藏            | 否，菜单隐藏             |
| **核心表**     | Sys_Tenants        | Sys_Tenants.ParentTenantId  | Col_CollaborationHubs   | Info_Announcements       |
| **权限表**     | Sys_TenantLicenses | Sys_ReportReviewPermissions | Sys_UserRoleAssignments | Info_AnnouncementTargets |

------

## 七、实施优先级建议

| 阶段        | 内容                 | 说明                                 |
| :---------- | :------------------- | :----------------------------------- |
| **Phase 1** | 租户 + 许可证        | 所有功能的基础，必须最先实现         |
| **Phase 2** | 协作域（集中调度）   | 大客户核心需求，优先于报表和公告     |
| **Phase 3** | 组织层级（报表审阅） | 依赖Phase 1的租户层级关系            |
| **Phase 4** | 公告与知识库         | 独立模块，可最后实现，不影响核心业务 |
| **Phase 5** | 协作域（集采中枢）   | 依赖Phase 2的协作域框架              |

------

*文档版本：v1.0*
*对应系统版本：混凝土ERP .NET 8 + Vue 3*