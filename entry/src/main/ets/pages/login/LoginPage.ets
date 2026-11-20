import { Session } from '../../common/store/Session';

/**
 * 登录。
 */
@Component
export struct LoginPage {
  @Consume('navStack') navStack: NavPathStack;

  private goCas(): void {
    this.navStack.pushPathByName('caslogin', null);
  }

  build() {
    NavDestination() {
      Column() {
        Column({ space: 6 }) {
          Text('i集大')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('校园服务 · 个人精简版')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .margin({ top: 60, bottom: 40 })

        Column({ space: 10 }) {
          Text('登录后可用')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          this.item('课表', '打开即见本周课表')
          this.item('成绩', '学期成绩与绩点')
          this.item('讲座报名', '查看可报名讲座')
          this.item('一卡通 / 未读 / 待办', '在「我的」里查看')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor(Color.White)
        .borderRadius(16)
        .margin({ bottom: 28 })

        Button('统一身份认证登录')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor($r('app.color.brand'))
          .fontColor(Color.White)
          .borderRadius(25)
          .onClick(() => {
            this.goCas();
          })

        Text('使用学号与密码登录，支持短信/扫码二次验证')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 14 })

        Blank()

        if (Session.isLoggedIn) {
          Text('当前已登录：' + (Session.user === null ? '' :
            (Session.user.accountName === undefined ? '' : Session.user.accountName)))
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 12 })
        }
      }
      .padding({ left: 28, right: 28, bottom: 20 })
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
    }
    .title('登录')
  }

  @Builder
  item(title: string, desc: string) {
    Row({ space: 8 }) {
      Text('·').fontSize(13).fontColor($r('app.color.brand'))
      Text(title).fontSize(13).fontColor($r('app.color.text_primary'))
      Text(desc).fontSize(12).fontColor($r('app.color.text_secondary')).layoutWeight(1)
    }
    .width('100%')
  }
}
