import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { JwtUtil } from '../common/auth/JwtUtil';
import { Session } from '../common/store/Session';
import { CacheStore } from '../common/store/CacheStore';
import { Endpoints } from '../common/net/Api';
import { WaterRoomBody, WaterDetail, WaterMeterBody, WaterMeter, WaterDayUse, WaterEnvelope } from '../common/model/Models';
import { PageTitleBar } from '../common/ui/PageTitleBar';

interface MeterView {
  name: string
  odd: string
  unit: string
  price: string
  days: WaterDayUse[]
}

interface WaterCache {
  room: string
  meters: MeterView[]
}

/** 水电。完美校园 SWAEServlet，只用学号与学校编号，不需要登录。 */
@Component
export struct WaterElecPage {
  @Consume('navStack') navStack: NavPathStack;
  @State room: string = '';
  @State meters: MeterView[] = [];
  @State loading: boolean = true;
  @State failed: boolean = false;

  aboutToAppear(): void {
    const c = CacheStore.getJson<WaterCache>('water.cache');
    if (c !== null) {
      this.room = c.room;
      this.meters = c.meters;
      this.loading = false;
    }
    this.load();
  }

  private account(): string {
    const u = Session.user;
    const a = (u === null || u.accountName === undefined) ? '' : u.accountName;
    if (a.length > 0 && a.replace(/[0-9]/g, '').length === 0) {
      return a;
    }
    const info = JwtUtil.userIdInfo(Session.token);
    if (info === null) {
      return a;
    }
    const num = info.accountName === undefined ? '' : info.accountName;
    return num.length > 0 ? num : a;
  }

  private async post(param: string, method: string): Promise<string> {
    const url = Endpoints.WATER_ELEC + '?param=' + encodeURIComponent(param) +
      '&customercode=' + Endpoints.WATER_CUSTOMER + '&method=' + method;
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Accept': '*/*',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        connectTimeout: 15000,
        readTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });
      return resp.result as string;
    } finally {
      req.destroy();
    }
  }

  private async load(): Promise<void> {
    const acc = this.account();
    if (acc.length === 0) {
      this.loading = false;
      this.failed = true;
      return;
    }
    try {
      // ① 房间与余量
      const raw1 = await this.post('{"cmd":"getbindroom","account":"' + acc + '"}', 'getbindroom');
      hilog.info(0x0000, 'IJIDA-WATER', 'room resp: %{public}s', raw1.length > 180 ? raw1.substring(0, 180) : raw1);
      const env1 = JSON.parse(raw1) as WaterEnvelope;
      if (env1.body === undefined) {
        throw new Error('EMPTY');
      }
      const room = JSON.parse(env1.body) as WaterRoomBody;
      this.room = (room.roomfullname === undefined ? '' : room.roomfullname).replace('轮机校区_', '');
      const verify = room.roomverify === undefined ? '' : room.roomverify;

      // ② 明细：单价与日用量
      const ts = this.stamp();
      const param2 = '{"cmd":"h5_getstuindexpage","roomverify":"' + verify +
        '","account":"' + acc + '","timestamp":"' + ts + '"}';
      const env2 = JSON.parse(await this.post(param2, 'h5_getstuindexpage')) as WaterEnvelope;
      const detail = JSON.parse(env2.body === undefined ? '{}' : env2.body) as WaterMeterBody;

      const views: MeterView[] = [];
      const list: WaterMeter[] = detail.modlist === undefined ? [] : detail.modlist;
      for (let i = 0; i < list.length; i++) {
        const m = list[i];
        const isWater = i > 0;
        const days: WaterDayUse[] = m.weekuselist === undefined ? [] : m.weekuselist;
        const v: MeterView = {
          name: isWater ? '水' : '电',
          odd: m.odd === undefined ? '--' : m.odd.toString(),
          unit: isWater ? '吨' : '度',
          price: m.price === undefined ? '--' : m.price,
          days: days.slice(Math.max(0, days.length - 7))
        };
        views.push(v);
      }

      // 没有明细时退回 ① 的余量
      if (views.length === 0 && room.detaillist !== undefined) {
        const dl: WaterDetail[] = room.detaillist;
        for (let i = 0; i < dl.length; i++) {
          const d = dl[i];
          const isWater = d.businesstype === '1';
          const oddVal = d.odd;
          const v: MeterView = {
            name: isWater ? '水' : '电',
            odd: oddVal === undefined ? '--' : oddVal,
            unit: isWater ? '吨' : '度',
            price: '--',
            days: []
          };
          views.push(v);
        }
      }

      this.meters = views;
      this.loading = false;
      this.failed = false;
      const cache: WaterCache = { room: this.room, meters: views };
      CacheStore.putJson('water.cache', cache as Object);
      CacheStore.markFresh('water.cache');
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : 'unknown';
      hilog.error(0x0000, 'IJIDA-WATER', 'fail: %{public}s', msg);
      this.loading = false;
      this.failed = this.meters.length === 0;
    }
  }

  private stamp(): string {
    const d = new Date();
    const p = (n: number): string => n < 10 ? '0' + n : n.toString();
    return '' + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) +
      p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + '000';
  }

  build() {
    NavDestination() {
      Column() {
        PageTitleBar({ title: '水电' })
        Scroll() {
        Column({ space: 18 }) {
          if (this.loading && this.meters.length === 0) {
            Column({ space: 12 }) {
              ForEach([0, 1, 2], (i: number) => {
                Column().width('100%').height(96).borderRadius(18).backgroundColor('#EFEFEA')
              }, (i: number) => i.toString())
            }
            .width('100%')
          } else {
            if (this.room.length > 0) {
              Text(this.room)
                .fontSize(15)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }

            ForEach(this.meters, (m: MeterView) => {
              Column({ space: 14 }) {
                Row() {
                  Text(m.name)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand'))
                    .layoutWeight(1)
                  Text('单价 ' + m.price)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                }
                .width('100%')

                Row({ space: 4 }) {
                  Text(m.odd)
                    .fontSize(34)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.brand'))
                  Text(m.unit)
                    .fontSize(15)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ bottom: 6 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Bottom)

                if (m.days.length > 0) {
                  Row({ space: 6 }) {
                    ForEach(m.days, (d: WaterDayUse) => {
                      Column({ space: 4 }) {
                        Text(d.dayuse === undefined ? '' : d.dayuse.toString())
                          .fontSize(11)
                          .fontColor($r('app.color.text_secondary'))
                        Column()
                          .width(18)
                          .height(Math.min(72, 8 + (d.dayuse === undefined ? 0 : d.dayuse) * 3))
                          .borderRadius(4)
                          .backgroundColor('#E0B695')
                        Text((d.daydate === undefined ? '' : d.daydate).substring(3))
                          .fontSize(10)
                          .fontColor('#B9A896')
                      }
                      .layoutWeight(1)
                    }, (d: WaterDayUse, idx: number) => m.name + idx.toString())
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Bottom)
                }
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 18, bottom: 18 })
              .borderRadius(20)
              .linearGradient({
                angle: 90,
                colors: [['#F3DECA', 0.0], ['#FAF2EA', 0.5], ['#FFFFFF', 1.0]]
              })
            }, (m: MeterView) => m.name)

            if (this.failed) {
              Text('未查到房间，请先在完美校园绑定宿舍')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
            }

            Text('刷新')
              .fontSize(15)
              .fontColor($r('app.color.brand'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 10, bottom: 10 })
              .stateStyles({
                pressed: {
                  .opacity(0.5)
                }
              })
              .onClick(() => {
                this.loading = true;
                this.load();
              })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 40 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
    }
    .hideTitleBar(true)
  }
}
