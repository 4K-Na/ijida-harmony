import { webview } from '@kit.ArkWeb';
import { CacheStore } from '../../common/store/CacheStore';
import { HttpClient } from '../../common/net/HttpClient';

/**
 * 通用 H5 容器。
 */
@Component
export struct WebContainerPage {
  @Consume('navStack') navStack: NavPathStack;
  @State urlStr: string = 'https://portal-service.paas.jmu.edu.cn';
  @State pageTitle: string = '';
  @State progress: number = 0;
  @State failed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const u = AppStorage.get<string>('web.url');
    const t = AppStorage.get<string>('web.title');
    if (u !== undefined && u.length > 0) {
      this.urlStr = u;
      // 连接预热
      HttpClient.warmUp(u);
      CacheStore.put('web.last', u);
    }
    if (t !== undefined) {
      this.pageTitle = t;
    }
  }

  build() {
    NavDestination() {
      Column() {
        if (this.progress > 0 && this.progress < 100) {
          Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
            .width('100%')
            .height(2)
            .color($r('app.color.brand'))
        }

        if (this.failed) {
          Column({ space: 12 }) {
            Text('页面打不开').fontSize(16).fontWeight(FontWeight.Medium)
            Text('内网服务需要先连接校园 VPN（aTrust）；外网服务请检查网络')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
            Button('重新加载')
              .onClick(() => {
                this.failed = false;
                this.controller.loadUrl(this.urlStr);
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding(24)
        } else {
          Web({ src: this.urlStr, controller: this.controller })
            .layoutWeight(1)
            .width('100%')
            .domStorageAccess(true)
            .databaseAccess(true)
            .fileAccess(false)
            .mixedMode(MixedMode.All)
            .onProgressChange((ev) => {
              this.progress = ev.newProgress;
            })
            .onErrorReceive(() => {
              this.failed = true;
            })
        }
      }
      .width('100%')
      .height('100%')
    }
    .title(this.pageTitle.length > 0 ? this.pageTitle : 'i集大')
    .onBackPressed(() => {
      // 网页能回退就交给网页
      if (this.controller.accessBackward()) {
        this.controller.backward();
        return true;
      }
      return false;
    })
  }
}
