import { Session } from '../common/store/Session';
import { CacheStore } from '../common/store/CacheStore';
import { HttpClient } from '../common/net/HttpClient';
import { Endpoints } from '../common/net/Api';
import { JwtUtil } from '../common/auth/JwtUtil';
import { PageTitleBar } from '../common/ui/PageTitleBar';

/** 设置 */
@Component
export struct SettingsPage {
  @Consume('navStack') navStack: NavPathStack;
  @State name: string = '';
  @State account: string = '';

  aboutToAppear(): void {
    const info = JwtUtil.userIdInfo(Session.token);
    if (info !== null) {
      this.name = info.userName === undefined ? '' : info.userName;
      this.account = info.accountName === undefined ? '' : info.accountName;
    }
    const u = Session.user;
    if (u !== null) {
      if (u.userName !== undefined && u.userName.length > 0) {
        this.name = u.userName;
      }
      if (u.accountName !== undefined && u.accountName.length > 0) {
        this.account = u.accountName;
      }
    }
  }

  @Builder
  item(title: string, danger: boolean, action: () => void) {
    Row() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(danger ? $r('app.color.danger') : $r('app.color.text_primary'))
        .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(danger ? $r('app.color.danger') : '#B9A896')
    }
    .width('100%')
    .height(64)
    .padding({ left: 22, right: 18 })
    .borderRadius(18)
    .linearGradient({
      angle: 90,
      colors: [['#F3DECA', 0.0], ['#FAF2EA', 0.45], ['#FFFFFF', 1.0]]
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(action)
  }

  build() {
    NavDestination() {
      Column() {
        PageTitleBar({ title: '设置' })
        Scroll() {
        Column({ space: 24 }) {
          Column({ space: 4 }) {
            Text(this.name.length > 0 ? this.name : '未登录')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontFamily('SerifSC')
              .fontColor($r('app.color.text_primary'))
            Text(this.account.length > 0 ? this.account : '点击登录')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('账号')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 4 })

            this.item('切换账号', false, () => {
              this.navStack.pushPathByName('login', null);
            })

            if (Session.isLoggedIn) {
              this.item('退出登录', true, () => {
                Session.logout();
                CacheStore.remove('home.cache');
                AppStorage.setOrCreate<number>('session.tick', new Date().getTime());
                this.navStack.pop();
              })
            }
          }
          .width('100%')

          Column({ space: 10 }) {
            Text('数据')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')
              .padding({ left: 4 })

            this.item('刷新', false, () => {
              AppStorage.setOrCreate<number>('session.tick', new Date().getTime());
              this.navStack.pop();
            })
          }
          .width('100%')

          Text('i集大 · HarmonyOS')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 40 })
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
