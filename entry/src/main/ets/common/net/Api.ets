/**
 * 接口地址。
 *
 * 前缀：
 *  - 个人中心类：authx-service.paas.jmu.edu.cn + /personal + /api/v1/personal/...
 *  - 消息类：    message-service.paas.jmu.edu.cn + /center + /api/v1/...
 *  - 事务待办：  transaction.paas.jmu.edu.cn + /ttc + /api/ttc/...
 *  - 门户数据：  portal-service1.paas.jmu.edu.cn + /v1/... 或 /v2/...
 *  - 教务课表：  H5（jwxt.jmu.edu.cn/lesson-student-app）+ token 注入
 *  - 鉴权头：    X-id-token: <idToken>
 */

export const CAS_HOST: string = 'https://cas.paas.jmu.edu.cn'
export const CAS_SERVICE: string = 'https://superapp.paas.jmu.edu.cn/'
export const AUTH_HOST: string = 'https://authx-service.paas.jmu.edu.cn'
export const PORTAL_HOST: string = 'https://portal-service1.paas.jmu.edu.cn'
export const MESSAGE_HOST: string = 'https://message-service.paas.jmu.edu.cn'
export const TASK_HOST: string = 'https://transaction.paas.jmu.edu.cn'
export const FORMFLOW_HOST: string = 'https://formflow.paas.jmu.edu.cn'
export const JWXT_HOST: string = 'https://jwxt.jmu.edu.cn'

/** CAS 内部接口 */
export class CasApi {
  static readonly LOGIN: string = CAS_HOST + '/cas/login?service='
  static readonly PUBLIC_KEY: string = CAS_HOST + '/cas/jwt/publicKey'
  static readonly MFA_DETECT: string = CAS_HOST + '/cas/mfa/detect'
}

/** 业务接口 */
export class Endpoints {
  /** 完美校园水电（无需登录） */
  static readonly WATER_ELEC: string = 'https://xqh5.17wanxiao.com/smartWaterAndElectricityService/SWAEServlet'
  static readonly WATER_CUSTOMER: string = '790'

  // 个人中心（authx + /personal）
  static readonly ME: string = AUTH_HOST + '/personal/api/v1/personal/me/user'
  static readonly PORTRAIT: string = AUTH_HOST + '/personal/api/v1/personal/me/portrait'
  static readonly SECURITY: string = AUTH_HOST + '/personal/api/v1/personal/user/security'

  // 消息（message-service + /center）
  static readonly MSG_UNREAD: string = MESSAGE_HOST + '/center/api/v1/messageCenter/getUnReadedCount'
  static readonly MSG_LIST: string = MESSAGE_HOST + '/center/api/v1/instantMessage/getAppMessageList/new'
  static readonly MSG_READ_ALL: string = MESSAGE_HOST + '/center/api/v1/messageCenter/messageRecordReadedByAccountName'
  static readonly IM_UNREAD: string = MESSAGE_HOST + '/center/api/v1/instantMessage/getAppAllUnReadCount'

  // 事务中心（transaction + /ttc）
  static readonly TODO_COUNT: string = TASK_HOST + '/ttc/api/ttc/center-list/getToDoListCount'
  static readonly TODO_LIST: string = TASK_HOST + '/ttc/api/ttc/center-list/getToDoList'
  static readonly HANDLE_LIST: string = TASK_HOST + '/ttc/api/ttc/center-list/getHandleList'
  static readonly NEWS_COUNT: string = TASK_HOST + '/ttc/api/ttc/center-list/getNewsCount'

  // 门户数据（portal-service1）
  static readonly ECARD: string = PORTAL_HOST + '/v2/personalData/getMyECard'
  static readonly MY_BOOKS: string = PORTAL_HOST + '/v2/personalData/getMyBooks'
  static readonly RECOMMEND_SERVICES: string = PORTAL_HOST + '/v1/service/recommend/month/list'
  static readonly THEME_LIST: string = PORTAL_HOST + '/v1/app/Theme/getAppThemeList'
  static readonly SERVICE_LIST: string = PORTAL_HOST + '/v1/service/list'

  // 教务（H5）
  /** 我的课表（H5 + token 注入） */
  static readonly JWXT_COURSE_TABLE: string = JWXT_HOST + '/lesson-student-app/index.html'
  /** 我的成绩（H5 + token 注入） */
  static readonly JWXT_GRADE: string = JWXT_HOST + '/grade-app'
}

/**
 * token 注入规则，对应服务数据的 tokenAccept 字段。
 * 例：[{"tokenType":"header","tokenKey":"idToken"},{"tokenType":"url","tokenKey":"idToken"},
 *      {"tokenType":"cookie","tokenKey":"idToken"}]
 */
export interface TokenRule {
  tokenType: string
  tokenKey: string
}

/** 按规则把 token 拼到 URL 上（url / header 两种由调用方处理，这里只处理 url 型） */
export function applyUrlToken(baseUrl: string, rules: TokenRule[], idToken: string): string {
  let out = baseUrl;
  for (let i = 0; i < rules.length; i++) {
    const r = rules[i];
    if (r.tokenType === 'url') {
      out = out + (out.indexOf('?') >= 0 ? '&' : '?') + r.tokenKey + '=' + encodeURIComponent(idToken);
    }
  }
  return out;
}


export function personalApi(path: string): string {
  return AUTH_HOST + '/personal' + path;
}

export function url(host: string, path: string): string {
  return host + path;
}
