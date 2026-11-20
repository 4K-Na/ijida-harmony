import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Session } from '../store/Session';
import { CacheStore } from '../store/CacheStore';

const TAG: string = 'IJIDA-HTTP';

/** 请求参数 */
export interface RequestOptions {
  method?: http.RequestMethod
  body?: Object
  timeout?: number
  /** 是否使用 HTTP 缓存，默认 true */
  useCache?: boolean
  needAuth?: boolean
}

/** 统一返回：实测后端返回 { code:0, message, data } */
export interface Envelope {
  code?: number
  success?: boolean
  message?: string
  msg?: string
  data?: Object
}

/**
 * 网络层。鉴权头为 X-id-token；Bearer、userToken、token 三种写法服务端不认。
 */
export class HttpClient {
  private static instance: http.HttpRequest | null = null;

  private static req(): http.HttpRequest {
    if (HttpClient.instance === null) {
      HttpClient.instance = http.createHttp();
    }
    return HttpClient.instance;
  }

  static async request<T>(urlStr: string, opt: RequestOptions): Promise<T> {
    // http 模块对 User-Agent、Referer 有限制，只带业务必需的头。
    const headers: Record<string, string> = {
      'Accept': 'application/json'
    };
    if (opt.body !== undefined) {
      headers['Content-Type'] = 'application/json';
    }
    const needAuth = opt.needAuth === undefined ? true : opt.needAuth;
    if (needAuth && Session.token.length > 0) {
      headers['X-id-token'] = Session.token;
    }

    const method = opt.method === undefined ? http.RequestMethod.GET : opt.method;
    const timeout = opt.timeout === undefined ? 15000 : opt.timeout;

    try {
      const resp = await HttpClient.req().request(urlStr, {
        method: method,
        header: headers,
        usingCache: opt.useCache === undefined ? true : opt.useCache,
        extraData: opt.body === undefined ? undefined : JSON.stringify(opt.body),
        connectTimeout: timeout,
        readTimeout: timeout,
        expectDataType: http.HttpDataType.STRING
      });

      const text: string = resp.result as string;
      if (resp.responseCode !== 200 && resp.responseCode !== 201 && resp.responseCode !== 302) {
        hilog.error(0x0000, TAG, 'HTTP %{public}d %{public}s', resp.responseCode, urlStr);
        throw new Error('HTTP_' + resp.responseCode);
      }
      const env = JSON.parse(text) as Envelope;
      const ok = env.success === true || env.code === 0 || env.code === 200;
      if (!ok) {
        throw new Error(env.message === undefined ? 'BIZ_ERROR' : env.message);
      }
      return env.data as T;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0000, TAG, 'request failed: %{public}s -> code=%{public}d msg=%{public}s', urlStr,
        err.code === undefined ? -1 : err.code,
        err.message === undefined ? 'unknown' : err.message);
      throw e as Error;
    }
  }

  /** 缓存先返回，后台刷新后经 onChange 回传 */
  static async swr<T>(cacheKey: string, urlStr: string,
    onChange: (fresh: T) => void, opt?: RequestOptions): Promise<T | null> {
    const cached = CacheStore.getJson<T>(cacheKey);
    HttpClient.request<T>(urlStr, opt === undefined ? {} : opt)
      .then((fresh: T) => {
        CacheStore.putJson(cacheKey, fresh as Object);
        onChange(fresh);
      })
      .catch(() => {
      });
    return cached;
  }

  /** 连接预热：对目标域名发 HEAD */
  static warmUp(urlStr: string): void {
    HttpClient.req().request(urlStr, {
      method: http.RequestMethod.HEAD,
      connectTimeout: 3000,
      readTimeout: 3000
    }).catch(() => {
    });
  }
}
