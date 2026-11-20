import { CacheStore } from './CacheStore';
import { JwtUtil } from '../auth/JwtUtil';
import { UserInfo } from '../model/Models';

const KEY_TOKEN: string = 'session.token';
const KEY_USER: string = 'session.user';
const KEY_CAS_TICKET: string = 'session.cas_ticket';
const KEY_EXP: string = 'session.exp';

/**
 * 登录态。token、用户、过期时间存 preferences，冷启动同步读回。
 */
export class Session {
  private static tokenValue: string = '';
  private static userValue: UserInfo | null = null;
  private static loaded: boolean = false;

  /** 冷启动第一步，同步恢复登录态 */
  static restore(): void {
    if (Session.loaded) {
      return;
    }
    Session.tokenValue = CacheStore.get(KEY_TOKEN, '');
    Session.userValue = CacheStore.getJson<UserInfo>(KEY_USER);
    // 老数据没有 exp，从 token 补算
    if (Session.tokenValue.length > 0 && CacheStore.get(KEY_EXP, '0') === '0') {
      const exp = JwtUtil.expOf(Session.tokenValue);
      if (exp > 0) {
        CacheStore.put(KEY_EXP, exp.toString());
      }
    }
    Session.loaded = true;
  }

  static get token(): string {
    return Session.tokenValue;
  }

  static get user(): UserInfo | null {
    return Session.userValue;
  }

  static get isLoggedIn(): boolean {
    return Session.tokenValue.length > 0;
  }

  /** token 过期时间（毫秒） */
  static get expireAt(): number {
    const v = CacheStore.get(KEY_EXP, '0');
    const n = Number(v);
    return isNaN(n) ? 0 : n;
  }

  /** 剩余不足 10 分钟时返回 true */
  static needRefresh(): boolean {
    if (!Session.isLoggedIn) {
      return false;
    }
    const exp = Session.expireAt;
    if (exp === 0) {
      return false;
    }
    return new Date().getTime() > exp - 10 * 60 * 1000;
  }

  /** 只替换 token 与过期时间 */
  static updateToken(token: string): void {
    Session.tokenValue = token;
    CacheStore.put(KEY_TOKEN, token);
    CacheStore.put(KEY_EXP, JwtUtil.expOf(token).toString());
  }

  static login(token: string, user: UserInfo): void {
    Session.tokenValue = token;
    Session.userValue = user;
    Session.loaded = true;
    CacheStore.put(KEY_TOKEN, token);
    CacheStore.put(KEY_EXP, JwtUtil.expOf(token).toString());
    CacheStore.putJson(KEY_USER, user);
    // 通知已存在的页面刷新
    AppStorage.setOrCreate<number>('session.tick', new Date().getTime());
  }

  static updateUser(user: UserInfo): void {
    Session.userValue = user;
    CacheStore.putJson(KEY_USER, user);
    AppStorage.setOrCreate<number>('session.tick', new Date().getTime());
  }

  /** 暂存 CAS 回调的 ticket */
  static setCasTicket(ticket: string): void {
    CacheStore.put(KEY_CAS_TICKET, ticket);
  }

  static takeCasTicket(): string {
    const t = CacheStore.get(KEY_CAS_TICKET, '');
    if (t.length > 0) {
      CacheStore.remove(KEY_CAS_TICKET);
    }
    return t;
  }

  static logout(): void {
    Session.tokenValue = '';
    Session.userValue = null;
    CacheStore.remove(KEY_TOKEN);
    CacheStore.remove(KEY_USER);
    CacheStore.remove(KEY_EXP);
  }
}
