import { webview } from '@kit.ArkWeb';
import { fileUri, picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session } from '../../common/store/Session';
import { PageTitleBar } from '../../common/ui/PageTitleBar';

/**
 * H5 容器。按 tokenAccept 注入 token：header、url、cookie 三种。
 */
@Component
export struct TokenWebPage {
  @Consume('navStack') navStack: NavPathStack;
  @State title: string = '';
  @State progress: number = 0;
  @State skeleton: boolean = true;
  private controller: webview.WebviewController = new webview.WebviewController();
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  private targetUrl: string = '';
  @State downloading: string = '';

  aboutToAppear(): void {
    const u = AppStorage.get<string>('tw.url');
    const t = AppStorage.get<string>('tw.title');
    const mode = AppStorage.get<string>('tw.mode');
    this.targetUrl = u === undefined ? '' : u;
    this.title = t === undefined ? '' : t;
    this.setupDownload();
    try {
      // 静态设置，页面一进入就生效，不必等 Web 组件 attach
      webview.WebDownloadManager.setDownloadDelegate(this.downloadDelegate);
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : 'unknown';
      hilog.error(0x0000, 'IJIDA-DL', 'static delegate fail %{public}s', msg);
    }
    const token = Session.token;
    if (token.length > 0) {
      if (mode === 'url') {
        this.targetUrl = this.targetUrl + (this.targetUrl.indexOf('?') >= 0 ? '&' : '?') + 'idToken=' + encodeURIComponent(token);
      } else if (mode === 'cookie') {
        try {
          const cm = webview.WebCookieManager;
          const host = this.hostOf(this.targetUrl);
          cm.configCookieSync(host, 'idToken=' + token);
          cm.configCookieSync(host, 'userToken=' + token);
          cm.saveCookieSync();
        } catch (e) {
        }
      }
    }
  }

  /** 附件下载：不设置 delegate 时点下载会导致进程异常 */
  private setupDownload(): void {
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      let name = item.getSuggestedFileName();
      if (name.length === 0) {
        name = 'download_' + new Date().getTime();
      }
      const path = getContext(this).cacheDir + '/' + name;
      hilog.info(0x0000, 'IJIDA-DL', 'start %{public}s', name);
      this.downloading = name;
      try {
        item.start(path);
      } catch (err) {
        const msg: string = err instanceof Error ? err.message : 'unknown';
        hilog.error(0x0000, 'IJIDA-DL', 'start fail %{public}s', msg);
      }
    });

    this.downloadDelegate.onDownloadUpdated((item: webview.WebDownloadItem) => {
      hilog.info(0x0000, 'IJIDA-DL', 'progress %{public}d%%', item.getPercentComplete());
    });

    // 下载结束必须实现这个回调，否则 ArkWeb 只报 downloadDidFinish not exists
    this.downloadDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      this.downloading = '';
      hilog.info(0x0000, 'IJIDA-DL', 'finish');
      this.openDownloaded(item);
    });

    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      this.downloading = '';
      hilog.error(0x0000, 'IJIDA-DL', 'failed %{public}s', item.getSuggestedFileName());
    });
  }

  /** 下载完成：交给系统打开；无法匹配应用时让用户另存 */
  private openDownloaded(item: webview.WebDownloadItem): void {
    const name = item.getSuggestedFileName();
    const path = getContext(this).cacheDir + '/' + name;
    let mime = item.getMimeType();
    if (mime.length === 0) {
      mime = this.mimeOf(name);
    }
    hilog.info(0x0000, 'IJIDA-DL', 'complete %{public}s mime=%{public}s', name, mime);

    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      ctx.startAbility({
        action: 'ohos.want.action.viewData',
        uri: fileUri.getUriFromPath(path),
        type: mime,
        flags: 1
      });
      return;
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : 'unknown';
      hilog.error(0x0000, 'IJIDA-DL', 'open fail %{public}s', msg);
    }
    this.saveAs(name, path);
  }

  private mimeOf(name: string): string {
    const lower = name.toLowerCase();
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }

  /** 另存到用户选择的位置 */
  private async saveAs(name: string, srcPath: string): Promise<void> {
    try {
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = [name];
      const dp = new picker.DocumentViewPicker(getContext(this));
      const uris = await dp.save(opts);
      if (uris === undefined || uris.length === 0) {
        return;
      }
      const dest = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE);
      const srcFile = fileIo.openSync(srcPath, fileIo.OpenMode.READ_ONLY);
      fileIo.copyFileSync(srcFile.fd, dest.fd);
      fileIo.closeSync(srcFile);
      fileIo.closeSync(dest);
      hilog.info(0x0000, 'IJIDA-DL', 'saved to %{public}s', uris[0]);
    } catch (err) {
      const msg: string = err instanceof Error ? err.message : 'unknown';
      hilog.error(0x0000, 'IJIDA-DL', 'saveAs fail %{public}s', msg);
    }
  }

  private hostOf(u: string): string {
    const i = u.indexOf('://');
    const rest = i >= 0 ? u.substring(i + 3) : u;
    const slash = rest.indexOf('/');
    return slash > 0 ? rest.substring(0, slash) : rest;
  }

  build() {
    NavDestination() {
      Column() {
        PageTitleBar({ title: this.title.length > 0 ? this.title : 'i集大' })
        Stack() {
        Web({ src: this.targetUrl, controller: this.controller })
          .width('100%')
          .height('100%')
          .opacity(this.skeleton ? 0 : 1)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .cacheMode(CacheMode.Default)
          .domStorageAccess(true)
          .databaseAccess(true)
          .mixedMode(MixedMode.All)
          .onControllerAttached(() => {
            this.controller.setDownloadDelegate(this.downloadDelegate);
          })
          .onProgressChange((ev) => {
            this.progress = ev.newProgress;
            // 进度过半收起骨架
            if (ev.newProgress >= 55 && this.skeleton) {
              this.skeleton = false;
            }
          })
          .onPageEnd(() => {
            this.skeleton = false;
          })

        if (this.skeleton) {
          Column({ space: 14 }) {
            ForEach([0, 1, 2, 3, 4], (i: number) => {
              Column()
                .width('100%')
                .height(i === 0 ? 64 : 46)
                .borderRadius(12)
                .backgroundColor('#EFEFEA')
            }, (i: number) => i.toString())
          }
          .width('100%')
          .height('100%')
          .padding({ left: 20, right: 20, top: 20 })
          .backgroundColor($r('app.color.page_bg'))
          .opacity(this.skeleton ? 1 : 0)
        }

        if (this.progress > 0 && this.progress < 100) {
          Column() {
            Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
              .width('100%')
              .height(2)
              .color($r('app.color.brand'))
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)
          .hitTestBehavior(HitTestMode.None)
        }
      }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (this.controller.accessBackward()) {
        this.controller.backward();
        return true;
      }
      return false;
    })
  }
}
