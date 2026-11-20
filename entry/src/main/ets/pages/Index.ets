import { HomePage } from './HomePage';
import { LoginPage } from './login/LoginPage';
import { CasLoginPage } from './login/CasLoginPage';
import { TokenWebPage } from './web/TokenWebPage';
import { WebContainerPage } from './web/WebContainerPage';
import { ScanPage } from './scan/ScanPage';
import { MessagePage } from './MessagePage';
import { WaterElecPage } from './WaterElecPage';
import { SettingsPage } from './SettingsPage';

/**
 * 单页应用，二级页面走路由。
 */
@Entry
@Component
struct Index {
  @Provide('navStack') navStack: NavPathStack = new NavPathStack();

  @Builder
  pageMap(name: string) {
    if (name === 'login') {
      LoginPage()
    } else if (name === 'caslogin') {
      CasLoginPage()
    } else if (name === 'tokenweb') {
      TokenWebPage()
    } else if (name === 'web') {
      WebContainerPage()
    } else if (name === 'scan') {
      ScanPage()
    } else if (name === 'messages') {
      MessagePage()
    } else if (name === 'water') {
      WaterElecPage()
    } else if (name === 'settings') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.navStack) {
      HomePage()
    }
    .navDestination(this.pageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .backgroundColor('#FAF8F4')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .customNavContentTransition((from: NavContentInfo, to: NavContentInfo,
      operation: NavigationOperation) => {
      const trans: NavigationAnimatedTransition = {
        timeout: 240,
        transition: (proxy: NavigationTransitionProxy) => {
          animateTo({
            duration: 160,
            curve: Curve.FastOutSlowIn,
            onFinish: () => {
              proxy.finishTransition();
            }
          }, () => {
          });
        }
      };
      return trans;
    })
  }
}
