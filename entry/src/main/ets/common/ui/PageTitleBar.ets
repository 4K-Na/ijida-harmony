/** 页面标题栏（自绘，标题用宋体） */
@Component
export struct PageTitleBar {
  @Prop title: string;
  @Consume('navStack') navStack: NavPathStack;

  build() {
    Row({ space: 12 }) {
      Row() {
        Text('‹')
          .fontSize(27)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 3 })
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor('#F0EAE0')
      .justifyContent(FlexAlign.Center)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
      .onClick(() => {
        this.navStack.pop();
      })

      Text(this.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontFamily('SerifSC')
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }
}
