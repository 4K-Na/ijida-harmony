# i集大

HarmonyOS / ArkTS。单页、暖白底、一列卡片。
原包 113.94 MB，本应用 353.8 KB。

## 页面

首页一个，功能都在下面：

```
姓名 / 学院
一卡通 · 未读 · 待办
课表        教务 H5，?idToken 注入
成绩        教务 H5，?idToken 注入
讲座        教务 H5，?idToken 注入
教学平台    ktm.jmu.edu.cn
钥匙串      ymt.jmu.edu.cn gateway，cookie userToken 注入
扫一扫      Scan Kit
刷新 / 切换账号 / 退出登录
```

## 鉴权

```
CAS 网页登录 → 拦截 ?ticket= → JWT payload.idToken = userToken
业务接口    X-id-token 头
gateway 类  cookie userToken → 302 → 目标应用
```

token 存 preferences，附过期时间。剩余不足 10 分钟时用 CAS 会话在后台换新；接口返回 401 或 403 也触发一次。idToken 有效期由服务端决定，约 6 小时。

## 实测

| 项 | 状态 |
|---|---|
| 课表 | 通，当周课程正常渲染 |
| 成绩 | 通，学期成绩与绩点正常渲染 |
| 讲座 | 通，可报名场次正常列出 |
| 钥匙串 | 通，门禁列表正常列出 |
| 扫一扫 | 通，系统扫码可用 |
| 一卡通 | 通，余额正常读取 |
| 未读 / 待办 | 通，角标数量与实际一致 |
| 水电 | 通，电/水余量正常读取 |

## 性能

| 指标 | 数值 |
|---|---|
| 首帧（onCreate 到内容提交） | 119–137 ms |
| 课表打开 FCP | 553 ms |
| 课表首屏绘制 | 1017 ms |
| 成绩打开 FCP | 620 ms |

`onCreate` 只建缓存句柄、读登录态。数据请求在首帧之后发出。首页常驻一个 1×1 Web，提前拉起 ArkWeb 内核，H5 页面加骨架。

## 编译

```powershell
$deveco="C:\Program Files\Huawei\DevEco Studio"
$env:DEVECO_SDK_HOME="$deveco\sdk"
$env:PATH="$deveco\tools\node;$deveco\tools\ohpm\bin;$deveco\tools\hvigor\bin;$env:PATH"
cd "<项目目录>"
& "$deveco\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default assembleHap --no-daemon
```

装到模拟器：

```powershell
$hdc="$deveco\sdk\default\openharmony\toolchains\hdc.exe"
& "$deveco\tools\emulator\Emulator.exe" -start vlphone
& $hdc -t 127.0.0.1:5555 install entry\build\default\outputs\default\entry-default-unsigned.hap
& $hdc -t 127.0.0.1:5555 shell "aa start -a EntryAbility -b com.yg.ijida"
```

真机需要签名，模拟器不需要。

## 目录

```
entry/src/main/ets/
├─ entryability/EntryAbility.ets
├─ pages/Index.ets              单页容器与路由
├─ pages/HomePage.ets           首页
├─ pages/login/LoginPage.ets
├─ pages/login/CasLoginPage.ets
├─ pages/web/TokenWebPage.ets   H5 容器
├─ pages/web/WebContainerPage.ets
├─ pages/scan/ScanPage.ets
├─ common/net/Api.ets           接口地址
├─ common/net/HttpClient.ets    请求、缓存、预热
├─ common/auth/JwtUtil.ets
├─ common/store/Session.ets     登录态
├─ common/store/CacheStore.ets
└─ common/model/Models.ets
tools/
├─ cas-login.ps1                命令行登录
└─ make_icon.py                 图标生成
```

## 未接

智慧淋浴：第三方平台 17wanxiao，tokenAccept 为 null，需要它自己的登录态。
真机安装：DevEco 自动签名。
其余 90 多个服务：`ijida-re/reports/全量服务清单.md`。
