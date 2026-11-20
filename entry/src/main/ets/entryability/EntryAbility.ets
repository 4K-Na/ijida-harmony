import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { CacheStore } from '../common/store/CacheStore';
import { Session } from '../common/store/Session';

const TAG: string = 'IJIDA-Ability';

/**
 * 应用入口。onCreate 只建缓存句柄、恢复登录态。
 */
export default class EntryAbility extends UIAbility {
  private t0: number = 0;
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.t0 = new Date().getTime();
    CacheStore.init(this.context);
    Session.restore();
    hilog.info(0x0000, TAG, 'onCreate done');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 窗口与系统栏配色
    windowStage.getMainWindow().then((win: window.Window) => {
      try {
        win.setWindowBackgroundColor('#FAF8F4');
        win.setWindowSystemBarProperties({
          statusBarColor: '#FAF8F4',
          statusBarContentColor: '#000000',
          navigationBarColor: '#FAF8F4',
          navigationBarContentColor: '#000000'
        });
      } catch (e) {
        hilog.warn(0x0000, TAG, 'setWindowSystemBarProperties failed');
      }
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, TAG, 'first frame in %{public}d ms', new Date().getTime() - this.t0);
      this.postFirstFrameWarmUp();
    });
  }

  /** 首帧之后执行 */
  private postFirstFrameWarmUp(): void {
    setTimeout(() => {
      hilog.info(0x0000, TAG, 'warm-up start');

    }, 800);
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
  }

  onBackground(): void {
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'onDestroy');
  }
}
