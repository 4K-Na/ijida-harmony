import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session } from '../common/store/Session';
import { JwtUtil } from '../common/auth/JwtUtil';
import { CacheStore } from '../common/store/CacheStore';
import { HttpClient } from '../common/net/HttpClient';
import { Endpoints } from '../common/net/Api';
import { MessageItem, ReadAllBody } from '../common/model/Models';
import { PageTitleBar } from '../common/ui/PageTitleBar';

/** 消息列表 */
@Component
export struct MessagePage {
  @Consume('navStack') navStack: NavPathStack;
  @State items: MessageItem[] = [];
  @State loading: boolean = true;
  @State marking: boolean = false;

  aboutToAppear(): void {
    const cached = CacheStore.getJson<MessageItem[]>('msg.items');
    if (cached !== null) {
      this.items = cached;
      this.loading = false;
    }
    this.load();
  }

  private load(): void {
    HttpClient.request<MessageItem[]>(Endpoints.MSG_LIST, { useCache: false })
      .then((list: MessageItem[]) => {
        const arr: MessageItem[] = (list === null || list === undefined) ? [] : list;
        this.items = arr;
        this.loading = false;
        CacheStore.putJson('msg.items', arr as Object);
        CacheStore.markFresh('msg.items');
      })
      .catch(() => {
        this.loading = false;
      });
  }

  /** 标记全部已读：服务端只提供按账号标记的接口 */
  private markAllRead(): void {
    const u = Session.user;
    let acc = (u === null || u.accountName === undefined) ? '' : u.accountName;
    if (acc.length === 0) {
      const info = JwtUtil.userIdInfo(Session.token);
      if (info !== null && info.accountName !== undefined) {
        acc = info.accountName;
      }
    }
    if (acc.length === 0) {
      hilog.error(0x0000, 'IJIDA-MSG', 'no account, skip');
      return;
    }
    hilog.info(0x0000, 'IJIDA-MSG', 'mark all read for %{public}s', acc);
    const body: ReadAllBody = { accountName: acc };
    HttpClient.request<null>(Endpoints.MSG_READ_ALL, {
      method: http.RequestMethod.POST,
      body: body as Object
    })
      .then(() => {
        const arr: MessageItem[] = [];
        for (let i = 0; i < this.items.length; i++) {
          const it = this.items[i];
          it.readed = 1;
          arr.push(it);
        }
        this.items = arr;
        CacheStore.putJson('msg.items', arr as Object);
        CacheStore.markFresh('msg.items');
        hilog.info(0x0000, 'IJIDA-MSG', 'all read done');
        AppStorage.setOrCreate<number>('session.tick', new Date().getTime());
      })
      .catch(() => {
      });
  }

  private open(item: MessageItem): void {
    this.markAllRead();
    const target = item.mobileUrl !== undefined && item.mobileUrl.length > 0 ? item.mobileUrl :
      (item.url === undefined ? '' : item.url);
    if (target.length === 0) {
      return;
    }
    AppStorage.setOrCreate<string>('tw.url', target);
    AppStorage.setOrCreate<string>('tw.title', item.title);
    AppStorage.setOrCreate<string>('tw.mode', 'none');
    HttpClient.warmUp(target);
    this.navStack.pushPathByName('tokenweb', null);
  }

  build() {
    NavDestination() {
      Column() {
        PageTitleBar({ title: '消息' })
        Row() {
          Blank()
          Text(this.marking ? '已全部标记' : '全部已读')
            .fontSize(13)
            .fontColor(this.marking ? Color.White : $r('app.color.brand'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(11)
            .backgroundColor(this.marking ? $r('app.color.brand') : '#F6E6DC')
            .animation({ duration: 160, curve: Curve.EaseOut })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
            .onClick(() => {
              if (this.marking) {
                return;
              }
              this.marking = true;
              this.markAllRead();
              setTimeout(() => {
                this.load();
              }, 600);
              setTimeout(() => {
                this.marking = false;
              }, 1600);
            })
        }
        .width('100%')
        .padding({ right: 20, top: 8 })

        if (this.loading && this.items.length === 0) {
          Column({ space: 12 }) {
            ForEach([0, 1, 2, 3, 4], (i: number) => {
              Column().width('100%').height(72).borderRadius(16).backgroundColor('#EFEFEA')
            }, (i: number) => i.toString())
          }
          .padding({ left: 20, right: 20, top: 16 })
        } else if (this.items.length === 0) {
          Text('暂无消息')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 80 })
        } else {
          List({ space: 10 }) {
            ForEach(this.items, (item: MessageItem) => {
              ListItem() {
                Row() {
                  Column({ space: 5 }) {
                    Row({ space: 6 }) {
                      if (item.readed === 0) {
                        Circle().width(7).height(7).fill($r('app.color.brand'))
                      }
                      Text(item.title)
                        .fontSize(17)
                        .fontWeight(FontWeight.Medium)
                        .fontColor($r('app.color.text_primary'))
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                    }
                    .width('100%')

                    Text((item.appName === undefined ? '' : item.appName) +
                      '  ' + (item.editTime === undefined ? '' : item.editTime))
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 20, right: 16, top: 16, bottom: 16 })
                .borderRadius(16)
                .linearGradient({
                  angle: 90,
                  colors: [['#FFFFFF', 0.0], ['#FAF3EC', 1.0]]
                })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 })
                .onClick(() => {
                  this.open(item);
                })
              }
            }, (item: MessageItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 20, right: 20, top: 8 })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
    }
    .hideTitleBar(true)
  }
}
