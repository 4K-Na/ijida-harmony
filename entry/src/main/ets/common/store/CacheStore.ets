import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'IJIDA-Cache';
const STORE_NAME: string = 'ijida_cache';

/**
 * 本地缓存。同步读写，首帧可直接取旧值。
 */
export class CacheStore {
  private static store: preferences.Preferences | null = null;

  /** EntryAbility.onCreate 调用一次 */
  static init(ctx: Context): void {
    try {
      CacheStore.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, TAG, 'init failed: %{public}s', err.message);
    }
  }

  static put(key: string, value: string): void {
    const s = CacheStore.store;
    if (s === null) {
      return;
    }
    try {
      s.putSync(key, value);
      s.flush();
    } catch (e) {
      hilog.warn(0x0000, TAG, 'put %{public}s failed', key);
    }
  }

  static get(key: string, def: string): string {
    const s = CacheStore.store;
    if (s === null) {
      return def;
    }
    const v = s.getSync(key, def);
    return typeof v === 'string' ? v as string : def;
  }

  /** 存对象：JSON 序列化后落盘 */
  static putJson(key: string, obj: Object): void {
    try {
      CacheStore.put(key, JSON.stringify(obj));
    } catch (e) {
      hilog.warn(0x0000, TAG, 'putJson %{public}s failed', key);
    }
  }

  /** 读对象，解析失败返回 null */
  static getJson<T>(key: string): T | null {
    const raw = CacheStore.get(key, '');
    if (raw.length === 0) {
      return null;
    }
    try {
      return JSON.parse(raw) as T;
    } catch (e) {
      return null;
    }
  }

  /** 记录某个缓存键的写入时间 */
  static markFresh(key: string): void {
    CacheStore.put(key + '.ts', new Date().getTime().toString());
  }

  /** 缓存年龄（毫秒），无记录返回 -1 */
  static ageOf(key: string): number {
    const raw = CacheStore.get(key + '.ts', '0');
    const t = Number(raw);
    if (isNaN(t) || t === 0) {
      return -1;
    }
    return new Date().getTime() - t;
  }

  /** 是否已过期（默认 10 分钟） */
  static isStale(key: string, maxAgeMs: number): boolean {
    const age = CacheStore.ageOf(key);
    return age < 0 || age > maxAgeMs;
  }

  static remove(key: string): void {
    const s = CacheStore.store;
    if (s === null) {
      return;
    }
    try {
      s.deleteSync(key);
      s.flush();
    } catch (e) {
      hilog.warn(0x0000, TAG, 'remove %{public}s failed', key);
    }
  }
}
