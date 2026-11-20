# i集大 鸿蒙版 · 模拟器运行验证报告

环境：DevEco Studio DS-261 / SDK HarmonyOS 26.0.0（API 26）/ 模拟器实例 `vlphone`（HarmonyOS 6.1.1 x86）
时间：本次会话实测

---

## 1. 启动与安装

```powershell
# 启动模拟器（已存在实例 vlphone）
& "C:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe" -start vlphone
# 连接
hdc list targets            # -> 127.0.0.1:5555
# 安装（模拟器 debug 镜像允许未签名包）
hdc install entry-default-unsigned.hap
# 启动
hdc shell aa start -a EntryAbility -b com.yg.ijida
```

结论：**未签名 HAP 可直接安装运行**（`install bundle successfully`），但 `appIdentifier` 为空。
`reqPermissionStates = [-1,-1,0,0,-1]` → INTERNET / GET_NETWORK_INFO 均为 **0（已授予）**，网络可用（模拟器内 ping 8.8.8.8 通）。

---

## 2. 登录（CAS 全流程，模拟器内真机级验证）

用 `uitest` 驱动界面完成真实登录：

```
点击「我的」→「点击登录」→「统一身份认证登录」
Web 组件加载 https://cas.paas.jmu.edu.cn/cas/login?service=https://superapp.paas.jmu.edu.cn/
uitest uiInput text 填入学号、密码（掩码 13 位）
点击「登录」
```

实测日志：

```
I IJIDA-CAS: login ok, account=<学号>
```

机制：`onLoadIntercept` / `onPageBegin` 拦截回跳 URL 里的 `?ticket=` → base64url 解 JWT payload → 取 `idToken`（即 userToken）→ 写 preferences。
**与原 App 完全一致**（原程序 app-service.js 也是取 `ticket.payload.idToken`）。

> 期间还验证了 CAS 页面渲染性能：`FCP 2170ms / LCP 2170ms / firstScreenPaint 2199ms`。
> 注意：模拟器截屏抓不到 ArkWeb 合成层（截出来是黑块），但 `uitest dumpLayout` 能看到完整 Web 控件树，说明页面正常渲染。

---

## 3. 各页面实测数据（全部真实）

| 页面 | 实测内容 | 数据来源 |
|---|---|---|
| 首页 | **你好，<姓名>** / <学院> / 待办 N / 未读 N / 一卡通 <余额> | me/user、ttc/getToDoListCount、messageCenter/getUnReadedCount、v2/personalData/getMyECard |
| 推荐服务 | 教学平台（课堂派）、学生注册系统、国际学术资源专用通道、教务-我的课表、差旅平台、集大爱问… | v1/service/recommend/month/list（36 条） |
| 服务页 | 同上 + 服务描述（"教务系统学生端——查询个人课表（移动端）"） | 同上 |
| 课表 | **<学期> 第 N 周**，课程名与教室正常渲染 | `jwxt.jmu.edu.cn/lesson-student-app/index.html?idToken=…`（token 注入） |

课表 Web 加载指标：**FCP 1093ms / LCP 1314ms / firstScreenPaint 1545ms**。

关键验证：URL 里确认带上了 `idToken`（TokenWebPage 按 `tokenAccept` 的 url 规则注入），所以教务系统**免二次登录**直接进课表 —— 与原 App 行为一模一样。

---

## 4. 截图

| 文件 | 内容 |
|---|---|
| `_run/home.png` / `home2.png` | 首页：姓名、学院、待办/未读/一卡通、推荐服务图标 |
| `_run/service.png` | 服务页：真实服务列表与描述 |
| `_run/course.png` | 课表：完整周课表（12 门课颜色块） |
| `_run/cas3.png` | CAS 登录页（模拟器截屏限制，Web 层为黑块） |

---

## 5. 本次修掉的问题

| 问题 | 原因 | 处理 |
|---|---|---|
| 首次请求报 `没有访问权限01` | 未登录、无 `X-id-token`，网关报错（不是权限问题，`reqPermissionStates` 显示 INTERNET 已授予） | 登录后自动带 token |
| 首页登录后不刷新 | Tab 内组件不会重走 `aboutToAppear` | `Session.login` 广播 `AppStorage('session.tick')`，HomeTab 用 `@StorageLink + @Watch` 触发刷新 |
| 一卡通显示 `--` | 接口偶发只返回消费记录不含 balance | 兼容解析（balance → lastExpenditure[0].amount） |
| 消息列表 `data:null` 崩溃风险 | 后端空数据返回 null | 加空数组兜底 |
| `User-Agent`/`Referer` 自定义头 | 已移除，改用默认 UA（服务端不校验） | — |

---

## 6. 仍然待办

1. **签名**：目前未签名（模拟器可跑，真机不行）。需要 AGC 账号做自动签名，或用 `hap-sign-tool` + OpenHarmony 调试证书自签（材料在 `sdk\default\openharmony\toolchains\lib`）。
2. 全校服务全量（`POST /v1/service/list` 的 body 结构待定）
3. 新闻/公告前缀（`/api/proxy/cms/...` 在 portal-service1 上 404）
4. 日程接口参数
5. 消息列表查询参数（未读数已正常）
6. 扫一扫（Scan Kit）、推送（Push Kit）尚未接
