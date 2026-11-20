import { util } from '@kit.ArkTS';

/** JWT 与 ticket 解析。userToken 是 ticket 外层 payload 的 idToken 字段。 */
export class JwtUtil {
  /** base64url -> UTF8 字符串 */
  private static b64urlDecode(seg: string): string {
    let s = seg.replace(/-/g, '+').replace(/_/g, '/');
    const pad = s.length % 4;
    if (pad === 2) {
      s += '==';
    } else if (pad === 3) {
      s += '=';
    } else if (pad === 1) {
      s += '===';
    }
    const helper = new util.Base64Helper();
    const bytes = helper.decodeSync(s, util.Type.BASIC);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  /** 取 JWT 的 payload JSON 文本；非法输入返回空串 */
  static payloadOf(jwt: string): string {
    const parts = jwt.split('.');
    if (parts.length < 2) {
      return '';
    }
    try {
      return JwtUtil.b64urlDecode(parts[1]);
    } catch (e) {
      return '';
    }
  }

  /**
   * 从 CAS 回调的 ticket 中取出 App 的 userToken（即内层 idToken）
   * 实测：ticket 外层 JWT payload 形如
   *   { identityTypeCode, sub, organizationCode, idToken, exp, ... }
   */
  static userTokenFromTicket(ticket: string): string {
    const payload = JwtUtil.payloadOf(ticket);
    if (payload.length === 0) {
      return '';
    }
    try {
      const obj = JSON.parse(payload) as TicketPayload;
      return obj.idToken === undefined ? '' : obj.idToken;
    } catch (e) {
      return '';
    }
  }

  /** 读账号信息，用于首屏显示 */
  static userIdInfo(idToken: string): IdTokenInfo | null {
    const payload = JwtUtil.payloadOf(idToken);
    if (payload.length === 0) {
      return null;
    }
    try {
      const obj = JSON.parse(payload) as IdTokenRaw;
      const info: IdTokenInfo = {
        accountName: obj.sub === undefined ? '' : obj.sub,
        userName: obj.ATTR_name === undefined ? (obj.ATTR_userName === undefined ? '' : obj.ATTR_userName) : obj.ATTR_name,
        organizationName: obj.ATTR_organizationName === undefined ? '' : obj.ATTR_organizationName,
        identityTypeCode: obj.ATTR_identityTypeCode === undefined ? '' : obj.ATTR_identityTypeCode
      };
      return info;
    } catch (e) {
      return null;
    }
  }

  /** 读取 JWT 的过期时间（毫秒时间戳），失败返回 0 */
  static expOf(jwt: string): number {
    const payload = JwtUtil.payloadOf(jwt);
    if (payload.length === 0) {
      return 0;
    }
    try {
      const obj = JSON.parse(payload) as JwtExp;
      return obj.exp === undefined ? 0 : obj.exp * 1000;
    } catch (e) {
      return 0;
    }
  }

  /** 从 URL 中抽取 ticket 参数（CAS 回调用） */
  static ticketFromUrl(urlStr: string): string {
    const key: string = 'ticket=';
    const idx = urlStr.indexOf(key);
    if (idx < 0) {
      return '';
    }
    let rest = urlStr.substring(idx + key.length);
    const amp = rest.indexOf('&');
    if (amp >= 0) {
      rest = rest.substring(0, amp);
    }
    const hash = rest.indexOf('#');
    if (hash >= 0) {
      rest = rest.substring(0, hash);
    }
    try {
      return decodeURIComponent(rest);
    } catch (e) {
      return rest;
    }
  }
}

interface JwtExp {
  exp?: number
}

interface TicketPayload {
  idToken?: string
  sub?: string
  identityTypeCode?: string
  organizationCode?: string
}

interface IdTokenRaw {
  sub?: string
  ATTR_name?: string
  ATTR_userName?: string
  ATTR_organizationName?: string
  ATTR_identityTypeCode?: string
}

/** 从 userToken 解出的用户摘要 */
export interface IdTokenInfo {
  accountName: string
  userName: string
  organizationName: string
  identityTypeCode: string
}
