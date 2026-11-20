import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';

/**
 * 扫一扫。链接直接打开，其他内容复制到剪贴板。
 */
@Component
export struct ScanPage {
  @Consume('navStack') navStack: NavPathStack;
  @State result: string = '';
  @State scanning: boolean = false;
  @State errMsg: string = '';

  aboutToAppear(): void {
    this.startScan();
  }

  private async startScan(): Promise<void> {
    if (this.scanning) {
      return;
    }
    this.scanning = true;
    this.errMsg = '';
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true
      };
      const res: scanBarcode.ScanResult = await scanBarcode.startScanForResult(ctx, options);
      this.result = res.originalValue;
      if (this.result.indexOf('http') === 0) {
        AppStorage.setOrCreate<string>('web.url', this.result);
        AppStorage.setOrCreate<string>('web.title', '扫码结果');
        this.navStack.pushPathByName('web', null);
      } else {
        const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.result);
        pasteboard.getSystemPasteboard().setDataSync(data);
        this.errMsg = '已复制到剪贴板';
      }
    } catch (e) {
      this.errMsg = '扫码取消或失败';
    } finally {
      this.scanning = false;
    }
  }

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        Text('扫一扫').fontSize(20).fontWeight(FontWeight.Bold)
        if (this.result.length > 0) {
          Text(this.result).fontSize(14).wordBreak(WordBreak.BREAK_ALL)
            .padding(16).backgroundColor(Color.White).borderRadius(10).width('100%')
        }
        if (this.errMsg.length > 0) {
          Text(this.errMsg).fontSize(13).fontColor($r('app.color.text_secondary'))
        }
        Button('再扫一次')
          .width('100%').height(46)
          .backgroundColor($r('app.color.brand'))
          .onClick(() => {
            this.startScan();
          })
      }
      .padding(20)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
      .alignItems(HorizontalAlign.Start)
    }
    .title('扫一扫')
  }
}
