import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CasApi, CAS_SERVICE, Endpoints } from '../../common/net/Api';
import { JwtUtil, IdTokenInfo } from '../../common/auth/JwtUtil';
import { Session } from '../../common/store/Session';
import { HttpClient } from '../../common/net/HttpClient';
import { UserInfo } from '../../common/model/Models';

const TAG: string = 'IJIDA-CAS';

/**
 * CAS 登录。Web 组件跑完认证，拦截回跳里的 ticket 取出 idToken。
 */
@Component
export struct CasLoginPage {
  @Consume('navStack') navStack: NavPathStack;
  @State progress: number = 0;
  @State tip: string = '正在打开统一身份认证…';
  private controller: webview.WebviewController = new webview.WebviewController();
  private handled: boolean = false;
  private urlStr: string = CasApi.LOGIN + encodeURIComponent(CAS_SERVICE);

  /** 拦截到 ticket 后完成的收尾 */
  private onTicket(ticket: string): void {
    const token = JwtUtil.userTokenFromTicket(ticket);
    if (token.length === 0) {
      this.tip = 'ticket 解析失败';
      return;
    }
    const info: IdTokenInfo | null = JwtUtil.userIdInfo(token);
    const user: UserInfo = {
      username: info === null ? '' : info.accountName,
      accountName: info === null ? '' : info.accountName,
      userName: info === null ? '' : info.userName,
      deptName: info === null ? '' : info.organizationName
    };
    Session.login(token, user);
    hilog.info(0x0000, TAG, 'login ok, account=%{public}s', user.accountName);
    // 补用户详情
    HttpClient.request<UserInfo>(Endpoints.ME, {})
      .then((me: UserInfo) => {
        Session.updateUser(me);
      })
      .catch(() => {
      });
    // 登录完成：清空二级页面栈，直接回到首页
    this.navStack.clear();
  }

  build() {
    NavDestination() {
      Stack() {
        Web({ src: this.urlStr, controller: this.controller })
          .width('100%')
          .height('100%')
          .domStorageAccess(true)
          .databaseAccess(true)
          .mixedMode(MixedMode.All)
          .onProgressChange((ev) => {
            this.progress = ev.newProgress;
          })
          .onLoadIntercept((ev) => {
            // 拦截回跳
            const u: string = ev.data.getRequestUrl();
            if (!this.handled && u.indexOf('ticket=') >= 0) {
              const ticket = JwtUtil.ticketFromUrl(u);
              if (ticket.length > 0) {
                this.handled = true;
                this.onTicket(ticket);
                return true;
              }
            }
            return false;
          })
          .onPageBegin((ev) => {
            // onLoadIntercept 未触发时再次拦截
            const u: string = ev.url;
            if (!this.handled && u.indexOf('ticket=') >= 0) {
              const ticket = JwtUtil.ticketFromUrl(u);
              if (ticket.length > 0) {
                this.handled = true;
                this.onTicket(ticket);
              }
            }
          })

        if (this.progress < 100) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text(this.tip).fontSize(13).fontColor($r('app.color.text_secondary')).margin({ top: 8 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F5F6F8')
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('统一身份认证')
  }
}
