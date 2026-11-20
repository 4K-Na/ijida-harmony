import { webview } from '@kit.ArkWeb';
import { font } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session } from '../common/store/Session';
import { CacheStore } from '../common/store/CacheStore';
import { HttpClient } from '../common/net/HttpClient';
import { Endpoints, CasApi, CAS_SERVICE } from '../common/net/Api';
import { JwtUtil } from '../common/auth/JwtUtil';
import { EcardInfo, MsgUnread, CountValue, UserInfo, MessageItem } from '../common/model/Models';

interface HomeCache {
  balance: string
  unread: number
  todo: number
}

interface ActionItem {
  key: string
  title: string
  url: string
  mode: string
}

interface ActionGroup {
  name: string
  items: ActionItem[]
}

/**
 * 首页。
 */
@Component
export struct HomePage {
  @Consume('navStack') navStack: NavPathStack;
  @State name: string = '未登录';
  @State subtitle: string = '点击登录';
  @State account: string = '';
  @State balance: string = '--';
  @State unread: number = 0;
  @State todo: number = 0;
  @State silentUrl: string = '';
  @State appear: boolean = false;
  @State serifReady: boolean = false;
  private warmCtrl: webview.WebviewController = new webview.WebviewController();
  private silentCtrl: webview.WebviewController = new webview.WebviewController();
  @StorageLink('session.tick') @Watch('onSessionChanged') tick: number = 0;

  private msgAction: ActionItem = {
    key: 'messages',
    title: '消息',
    url: '',
    mode: 'messages'
  };

  private groups: ActionGroup[] = [
    {
      name: '学习',
      items: [
        {
          key: 'course',
          title: '课表',
          url: 'https://jwxt.jmu.edu.cn/lesson-student-app/index.html',
          mode: 'url'
        },
        {
          key: 'grade',
          title: '成绩',
          url: 'https://jwxt.jmu.edu.cn/grade-app/',
          mode: 'url'
        },
        {
          key: 'lecture',
          title: '讲座',
          url: 'http://jwxt.jmu.edu.cn/eams-lecture-enroll-app/index.html',
          mode: 'url'
        },
        {
          key: 'erke',
          title: '第二课堂',
          url: 'https://2ke.jmu.edu.cn/dashboard',
          mode: 'none'
        }
      ]
    },
    {
      name: '系统',
      items: [
        {
          key: 'kt',
          title: '教学平台',
          url: 'https://ktm.jmu.edu.cn/',
          mode: 'none'
        },
        {
          key: 'jwxt',
          title: '教务系统',
          url: 'https://jwxt.jmu.edu.cn/student/sso/login',
          mode: 'none'
        },
        {
          key: 'xgxt',
          title: '学工系统',
          url: 'https://xgxt.jmu.edu.cn/Sys/sso/login.aspx',
          mode: 'none'
        },
        {
          key: 'scan',
          title: '扫一扫',
          url: '',
          mode: 'scan'
        }
      ]
    },
    {
      name: '生活',
      items: [
        {
          key: 'water',
          title: '水电',
          url: '',
          mode: 'water'
        },
        {
          key: 'keyring',
          title: '钥匙串',
          url: 'https://ymt.jmu.edu.cn/lightappService/host/docking/gateway?p=3f299780aa09232b21843b27173e96d1770e97c5c3a76a673f5163b37ab3f281d754c6fa224c1df853ab6ccd7357f93c5a6de93f4ee8a7ed27340a9c28fa6676dfa81270bef722e0c9c5a497935f0929',
          mode: 'cookie'
        }
      ]
    }
  ];

  aboutToAppear(): void {
    // 先读缓存
    this.paint();
    this.silentRefresh();
    // 首帧后再动画与请求
    setTimeout(() => {
      this.appear = true;
      this.refresh();
      this.registerSerif();
      this.warmAllHosts();
      // 首屏稳定后再预取高频页面数据，点开即显示
      setTimeout(() => {
        this.prefetchMessages();
      }, 1500);
    }, 16);
  }

  onSessionChanged(): void {
    this.paint();
    this.refresh();
  }

  private paint(): void {
    if (!Session.isLoggedIn) {
      this.name = '未登录';
      this.subtitle = '点击登录';
      this.balance = '--';
      this.unread = 0;
      this.todo = 0;
      return;
    }
    const u = Session.user;
    const n = u === null || u.userName === undefined ? '' : u.userName;
    const a = u === null || u.accountName === undefined ? '' : u.accountName;
    const d = u === null || u.deptName === undefined ? '' : u.deptName;
    this.name = n.length > 0 ? n : (a.length > 0 ? a : '已登录');
    this.subtitle = d.length > 0 ? d : a;
    this.account = a;
    if (this.account.length === 0) {
      const info = JwtUtil.userIdInfo(Session.token);
      if (info !== null && info.accountName !== undefined) {
        this.account = info.accountName;
      }
    }

    const c = CacheStore.getJson<HomeCache>('home.cache');
    if (c !== null) {
      this.balance = c.balance;
      this.unread = c.unread;
      this.todo = c.todo;
    }
  }

  private initial(): string {
    const n = this.name;
    return n.length > 0 ? n.substring(0, 1) : '?';
  }

  /** 首帧之后注册思源宋体，避免影响冷启动 */
  private registerSerif(): void {
    try {
      font.registerFont({
        familyName: 'SerifSC',
        familySrc: $rawfile('NotoSerifSC-Sub.ttf')
      });
      hilog.info(0x0000, 'IJIDA-FONT', 'serif registered');
      setTimeout(() => {
        this.serifReady = true;
      }, 260);
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : 'unknown';
      hilog.error(0x0000, 'IJIDA-FONT', 'font throw %{public}s', msg);
    }
  }

  /** 首帧后把所有要用的域名一次性预连接，省掉后续 DNS + TLS */
  private warmAllHosts(): void {
    const urls: string[] = [
      Endpoints.ME,
      Endpoints.ECARD,
      Endpoints.MSG_LIST,
      Endpoints.TODO_COUNT,
      'https://jwxt.jmu.edu.cn/lesson-student-app/index.html',
      'https://jwxt.jmu.edu.cn/grade-app/',
      'https://ktm.jmu.edu.cn/',
      'https://2ke.jmu.edu.cn/dashboard',
      'https://xgxt.jmu.edu.cn/',
      'https://ymt.jmu.edu.cn/'
    ];
    for (let i = 0; i < urls.length; i++) {
      HttpClient.warmUp(urls[i]);
    }
  }

  /** 预取消息列表，让消息页打开即有内容 */
  private prefetchMessages(): void {
    if (!Session.isLoggedIn) {
      return;
    }
    if (!CacheStore.isStale('msg.items', 3 * 60 * 1000)) {
      return;
    }
    HttpClient.request<MessageItem[]>(Endpoints.MSG_LIST, { useCache: false })
      .then((list: MessageItem[]) => {
        if (list !== null && list !== undefined) {
          CacheStore.putJson('msg.items', list as Object);
          CacheStore.markFresh('msg.items');
        }
      })
      .catch(() => {
      });
  }

  private refresh(): void {
    if (!Session.isLoggedIn) {
      return;
    }

    HttpClient.request<UserInfo>(Endpoints.ME, {})
      .then((me: UserInfo) => {
        const attr = me.attributes;
        if (attr !== undefined) {
          if (attr.userName !== undefined && attr.userName.length > 0) {
            this.name = attr.userName;
          }
          if (attr.organizationName !== undefined && attr.organizationName.length > 0) {
            this.subtitle = attr.organizationName;
          }
        }
      })
      .catch((e: Error) => {
        this.onAuthFail(e.message);
      });

    HttpClient.request<EcardInfo>(Endpoints.ECARD, {})
      .then((e: EcardInfo) => {
        if (e.balance !== undefined && e.balance.length > 0) {
          this.balance = e.balance;
        }
        this.save();
      })
      .catch((e: Error) => {
        this.onAuthFail(e.message);
      });

    HttpClient.request<MsgUnread>(Endpoints.MSG_UNREAD, { useCache: false })
      .then((m: MsgUnread) => {
        this.unread = m.unReadedCount;
        this.save();
      })
      .catch((e: Error) => {
        this.onAuthFail(e.message);
      });

    HttpClient.request<CountValue>(Endpoints.TODO_COUNT, {})
      .then((n: CountValue) => {
        this.todo = n;
        this.save();
      })
      .catch((e: Error) => {
        this.onAuthFail(e.message);
      });
  }

  private onAuthFail(msg: string): void {
    hilog.error(0x0000, 'IJIDA-HOME', 'req: %{public}s', msg);
    if (msg.indexOf('403') >= 0 || msg.indexOf('401') >= 0) {
      this.silentRefresh();
    }
  }

  private save(): void {
    const c: HomeCache = { balance: this.balance, unread: this.unread, todo: this.todo };
    CacheStore.putJson('home.cache', c as Object);
    CacheStore.markFresh('home.cache');
  }

  private silentRefresh(): void {
    if (!Session.isLoggedIn || this.silentUrl.length > 0) {
      return;
    }
    if (!Session.needRefresh()) {
      return;
    }
    hilog.info(0x0000, 'IJIDA-HOME', 'silent refresh start');
    this.silentUrl = CasApi.LOGIN + encodeURIComponent(CAS_SERVICE) + '&_t=' + new Date().getTime();
  }

  private onSilentTicket(ticket: string): void {
    if (ticket.length === 0) {
      return;
    }
    const tok = JwtUtil.userTokenFromTicket(ticket);
    if (tok.length === 0) {
      return;
    }
    Session.updateToken(tok);
    hilog.info(0x0000, 'IJIDA-HOME', 'silent refresh ok');
    this.silentUrl = '';
    AppStorage.setOrCreate<number>('session.tick', new Date().getTime());
    this.refresh();
  }

  private open(item: ActionItem): void {
    if (item.mode === 'water') {
      this.navStack.pushPathByName('water', null);
      return;
    }
    if (item.mode === 'messages') {
      this.navStack.pushPathByName('messages', null);
      return;
    }
    if (item.mode === 'scan') {
      this.navStack.pushPathByName('scan', null);
      return;
    }
    if (item.mode !== 'none' && !Session.isLoggedIn) {
      this.navStack.pushPathByName('login', null);
      return;
    }
    AppStorage.setOrCreate<string>('tw.url', item.url);
    AppStorage.setOrCreate<string>('tw.title', item.title);
    AppStorage.setOrCreate<string>('tw.mode', item.mode);
    HttpClient.warmUp(item.url);
    this.navStack.pushPathByName('tokenweb', null);
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 26 }) {
          Row({ space: 14 }) {
            Text(this.initial())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .width(54)
              .height(54)
              .textAlign(TextAlign.Center)
              .borderRadius(27)
              .linearGradient({
                angle: 135,
                colors: [['#E38F63', 0.0], ['#B9542F', 1.0]]
              })

            Column({ space: 5 }) {
              Text(this.name)
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontFamily(this.serifReady ? 'SerifSC' : 'HarmonyOS Sans')
                .fontColor($r('app.color.text_primary'))
              Text(this.subtitle)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
            .onClick(() => {
              if (!Session.isLoggedIn) {
                this.navStack.pushPathByName('login', null);
              }
            })

            Text('设置')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 13, right: 13, top: 7, bottom: 7 })
              .borderRadius(13)
              .backgroundColor('#EBE3D5')
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.94 })
              .onClick(() => {
                this.navStack.pushPathByName('settings', null);
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row() {
            this.metric(this.balance, '一卡通')
            this.metric(this.unread.toString(), '未读')
            this.metric(this.todo.toString(), '待办')
          }
          .width('100%')
          .padding({ top: 22, bottom: 22 })
          .borderRadius(22)
          .linearGradient({
            angle: 90,
            colors: [['#F4DFCC', 0.0], ['#FBF2E9', 0.55], ['#FFFFFF', 1.0]]
          })
          .shadow({ radius: 18, color: '#1AB9542F', offsetX: 0, offsetY: 8 })

          // 消息（单独，带角标）
          this.row(this.msgAction.title, this.unread.toString(), () => {
            this.open(this.msgAction);
          })

          // 分组
          ForEach(this.groups, (g: ActionGroup) => {
            this.groupBox(g);
          }, (g: ActionGroup) => g.name)


        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 24, bottom: 40 })
      }
      .width('100%')
      .height('100%')
      .opacity(this.appear ? 1 : 0)
      .translate({ y: this.appear ? 0 : 12 })
      .animation({ duration: 260, curve: Curve.EaseOut })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])

      // 常驻 Web，预热 ArkWeb 内核
      Web({ src: 'about:blank', controller: this.warmCtrl })
        .width(1)
        .height(1)
        .opacity(0.01)
        .focusable(false)

      if (this.silentUrl.length > 0) {
        Web({ src: this.silentUrl, controller: this.silentCtrl })
          .width(1)
          .height(1)
          .opacity(0.01)
          .onLoadIntercept((ev) => {
            const u: string = ev.data.getRequestUrl();
            if (u.indexOf('ticket=') >= 0) {
              this.onSilentTicket(JwtUtil.ticketFromUrl(u));
              return true;
            }
            return false;
          })
          .onPageBegin((ev) => {
            if (this.silentUrl.length > 0 && ev.url.indexOf('ticket=') >= 0) {
              this.onSilentTicket(JwtUtil.ticketFromUrl(ev.url));
            }
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, ratio: number) => {
      // 从二级页返回时刷新，登录、续期后立刻更新
      if (isVisible && ratio > 0) {
        this.paint();
        this.refresh();
      }
    })
  }

  /** 分组外框 */
  @Builder
  groupBox(g: ActionGroup) {
    Column({ space: 11 }) {
      Text(g.name)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 2 })

      Grid() {
        ForEach(g.items, (item: ActionItem) => {
          GridItem() {
            Row() {
              Text(item.title)
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
            }
            .width('100%')
            .height(60)
            .justifyContent(FlexAlign.Center)
            .borderRadius(13)
            .backgroundColor('#F8F3EB')
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
            .onClick(() => {
              this.open(item);
            })
          }
        }, (item: ActionItem) => item.key)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(9)
      .rowsGap(9)
      .width('100%')
      .height(this.gridH(g.items.length))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 14 })
    .borderRadius(20)
    .backgroundColor($r('app.color.card_bg'))
    .border({ width: 1, color: '#EFE8DB' })
  }

  private gridH(n: number): number {
    const rows = Math.ceil(n / 2);
    return rows * 60 + (rows - 1) * 9;
  }

  @Builder
  metric(value: string, label: string) {
    Column({ space: 6 }) {
      Text(value)
        .fontSize(27)
        .fontWeight(FontWeight.Bold)
        .fontFamily(this.serifReady ? 'SerifSC' : 'HarmonyOS Sans')
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  row(title: string, badge: string, action: () => void) {
    Row({ space: 8 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (badge.length > 0 && badge !== '0') {
        Text(badge)
          .fontSize(13)
          .fontColor(Color.White)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor($r('app.color.brand'))
          .borderRadius(11)
      }
      Text('›')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#B9A896')
    }
    .width('100%')
    .height(72)
    .padding({ left: 22, right: 18 })
    .borderRadius(18)
    .linearGradient({
      angle: 90,
      colors: [['#F3DECA', 0.0], ['#FAF2EA', 0.45], ['#FFFFFF', 1.0]]
    })
    .shadow({ radius: 12, color: '#14B9542F', offsetX: 0, offsetY: 4 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(action)
  }
}
