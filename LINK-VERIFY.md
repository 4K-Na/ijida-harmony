# 链路验证报告（只验通不通，未做 UI）

环境：模拟器 `vlphone`（HarmonyOS 6.1.1）+ 本工程 `com.yg.ijida`（未签名，模拟器可装）
账号：本人学号，token 为 CAS 返回的 `idToken`（1226 字符）

---

## 结论一览

| # | 功能 | 链路 | 实测数据（真实） | FCP | 状态 |
|---|---|---|---|---|---|
| 1 | 课表 | `jwxt.jmu.edu.cn/lesson-student-app/index.html?idToken=` | 当周课表正常，课程名与教室均渲染 | 1093 ms | ✅ 通 |
| 2 | 成绩 | `jwxt.jmu.edu.cn/grade-app/?idToken=` | 学期成绩、学分、绩点均正常渲染 | 646 ms | ✅ 通 |
| 3 | 讲座 | `jwxt.jmu.edu.cn/eams-lecture-enroll-app/index.html?idToken=` | 讲座场次、主讲人、时间均正常列出 | 558 ms | ✅ 通 |
| 4 | 扫一扫 | `@kit.ScanKit` `scanBarcode.startScanForResult` | 系统扫码界面正常拉起（相机服务有帧输出，含“图库”入口、“安全访问相机”提示） | — | ✅ 通 |
| 5 | 钥匙串 | — | 18 个服务里没有同名项，**待确认所指** | — | ❓ 待定 |

---

## 关键机制（这四条都是同一种打法）

这 4 个功能里 3 个是 **教务系统的 H5**，不是原生接口。服务数据里的 `tokenAccept` 就是注入说明：

```json
// 教务-我的课表
[{"tokenType":"header","tokenKey":"idToken"},
 {"tokenType":"url","tokenKey":"idToken"},
 {"tokenType":"cookie","tokenKey":"idToken"}]

// 教务-我的成绩信息
[{"tokenType":"header","tokenKey":"token"},
 {"tokenType":"url","tokenKey":"idToken"},
 {"tokenType":"cookie","tokenKey":"userToken"}]

// 教务-讲座报名
[{"header":"idToken"}, {"url":"idToken"}, {"cookie":"userToken"}]
```

实测结论：**统一用 `?idToken=<userToken>` 拼 URL 就能免二次登录**，三条全部直接出数据，不需要额外 cookie/header。
这也就是原 App 的做法（`serviceType=2` 表示内嵌 webview + token 注入）。

---

## 顺带确认可用的同族页面（同一套注入，未逐个点开）

| 服务 | URL | 注入 |
|---|---|---|
| 教务-校历 | `jwxt.jmu.edu.cn/eams-school-calendar-app` | url:token |
| 教务-我的培养方案完成情况 | `jwxt.jmu.edu.cn/eams-student-complete-app` | url:token |
| 教务（学生） | `jwxt.jmu.edu.cn/student/sso/login` | CAS 跳转 |

---

## 服务清单（18 个，实测接口全 200）

拉取接口（均 200，`X-id-token` 鉴权）：

```
/v1/service/recommend/month/list   推荐
/v1/service/hot/list               热门
/v1/service/lastUse/list           最近使用
/v1/service/findForceRecommService 强制推荐
/v1/service/collectTop             收藏榜
/v1/service/collect/list           我的收藏
```

全部服务（服务名 | URL | 类型 | 是否需内网）：

| 服务 | URL | 需 VPN |
|---|---|---|
| 教务-我的课表 | jwxt.jmu.edu.cn/lesson-student-app/index.html | 否 |
| 教务-我的成绩信息 | jwxt.jmu.edu.cn/grade-app | 否 |
| 教务-讲座报名 | jwxt.jmu.edu.cn/eams-lecture-enroll-app/index.html | 否 |
| 教务-校历 | jwxt.jmu.edu.cn/eams-school-calendar-app | 否 |
| 教务-我的培养方案完成情况 | jwxt.jmu.edu.cn/eams-student-complete-app | 否 |
| 教学平台 | kt.jmu.edu.cn | 否 |
| 集大爱问 | ai.jmu.edu.cn/openapi/v1/oauth2/login | 否 |
| 学生宿舍网自助服务 | service.jmu.edu.cn/selfservice/ | 否 |
| 学生注册系统 | zcxt.jmu.edu.cn/dashboard | 否 |
| 学工-宿舍管理 | xgxt.jmu.edu.cn/AppJC/Account/ToLogin?systemType=SG | 否 |
| 学工系统 | xgxt.jmu.edu.cn/Sys/sso/login.aspx | 否 |
| 就业系统 | xsjyzd.jmu.edu.cn/default/xsjyzd | 否 |
| 差旅平台 | cwcclbx.jmu.edu.cn/szht_trip_pc_1/user/casCallback | 否 |
| 大型仪器共享 | dygx.jmu.edu.cn/JISP2/noSecurity/casLoginAction.do | 否 |
| 访客预约系统 | baobei.jmu.edu.cn/apply/ssoLogin | 否 |
| 机构知识库 | libir.jmu.edu.cn/jmdx-sso/ssoLogin.shtml | 否 |
| 国际学术资源专用通道 | kjtd.paas.jmu.edu.cn | 否 |
| 教务（学生） | jwxt.jmu.edu.cn/student/sso/login | 否 |

> 注意：`useVpn` 全部为 `0`，即这些服务都不需要校园 VPN 隧道 —— 之前担心的 aTrust 阻塞，对这几个功能**不存在**。

---

## 工程侧改动（本次）

- 新增 `pages/debug/ProbePage.ets`（临时验证入口，最终布局时删除）
- 新增 `pages/tabs/CourseTab.ets`（课表 tab，常驻教务 H5）
- 精简 `Index.ets` 为 2 个入口（课表 / 我的）
- 精简 `MineTab.ets`（一卡通 / 未读 / 待办 + 扫码 + 登录）
- 删除 `HomeTab / ServiceTab / MessageTab / ScheduleTab`
- 新增 `pages/scan/ScanPage.ets`（Scan Kit 扫码）

HAP：278.7 KB（原 Android 包 113.94 MB）

---

## 待你确认

**“钥匙串”具体指什么？** 18 个服务里没有同名项，最接近的候选是：

1. `学工-宿舍管理`（xgxt.jmu.edu.cn/AppJC/...）
2. `学生宿舍网自助服务`（service.jmu.edu.cn/selfservice/）
3. 还是指“密码/凭证管理”（鸿蒙的密码保险箱能力，与校园服务无关）

告诉我哪个，我立刻验这条链路。
