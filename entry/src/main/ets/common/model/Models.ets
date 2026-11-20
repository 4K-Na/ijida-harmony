/**
 * 数据模型，字段与后端返回一致。
 */

/** 统一返回：{ code, message, data } */
export interface ApiResult<T> {
  code: number
  message?: string
  data: T
}

/** me/user */
export interface UserInfo {
  username: string
  roles?: string[]
  attributes?: UserAttributes
  /** 由 attributes 映射 */
  accountName?: string
  userName?: string
  deptName?: string
}

export interface UserAttributes {
  organizationId?: string
  organizationName?: string
  organizationCode?: string
  identityTypeCode?: string
  identityTypeName?: string
  accountId?: string
  userId?: string
  userName?: string
  uid?: string
}

/** user/security */
export interface SecurityInfo {
  securityLevel: number
  mobileBinded: boolean
  emailAddressBinded: boolean
  questionBinded: boolean
  mobile?: string
  emailAddress?: string
}

/** 消息未读（messageCenter/getUnReadedCount） */
export interface MsgUnread {
  unReadedCount: number
  todayUnReadedCount?: number
  thirdMsgCount?: number
  starCount?: number
}

/** 待办数（ttc/getToDoListCount）：data 是数字 */
export type CountValue = number

/** 一卡通（v2/personalData/getMyECard） */
export interface EcardInfo {
  lastExpenditure?: EcardRecord[]
  lastIncome?: EcardRecord[]
  balance?: string
}

export interface EcardRecord {
  time: string
  amount: string
  address: string
  payWay?: string
}

/** 服务条目 */
export interface ServiceItem {
  id: string
  serviceName: string
  iconUrl?: string
  servicePicUrl?: string
  serviceUrl?: string
  serviceDesc?: string
  serviceType?: string
  serviceNo?: string
  collect?: string
  clickNum?: number
  /** JSON 字符串：[{"tokenType":"header","tokenKey":"idToken"}, ...] */
  tokenAccept?: string
  useVpn?: string
  haveGuide?: string
  techType?: string
}

/** 消息记录 */
export interface MessageRecord {
  id?: string
  messageTitle?: string
  title?: string
  messageContent?: string
  createTime?: string
  sendTime?: string
  appName?: string
  readFlag?: string
}

/** token 注入规则 */
export interface TokenRule {
  tokenType: string
  tokenKey: string
}

/** 消息（instantMessage/getAppMessageList/new） */
export interface MessageItem {
  id: string
  title: string
  content?: string
  editTime?: string
  appName?: string
  logo?: string
  coverImageUrl?: string
  url?: string
  mobileUrl?: string
  readed?: number
  star?: number
  important?: number
  messageTypeName?: string
}

/** 全部已读请求体 */
export interface ReadAllBody {
  accountName: string
}

/** 完美校园水电：房间与余量 */
export interface WaterRoomBody {
  result?: string
  account_num?: string
  roomfullname?: string
  roomverify?: string
  detaillist?: WaterDetail[]
  message?: string
}

export interface WaterDetail {
  use?: string
  odd?: string
  businesstype?: string
  status?: string
}

/** 完美校园水电：明细 */
export interface WaterMeterBody {
  roomfullname?: string
  roomverify?: string
  modlist?: WaterMeter[]
}

export interface WaterMeter {
  mac?: number
  odd?: number
  price?: string
  blunum?: string
  weekuselist?: WaterDayUse[]
}

export interface WaterDayUse {
  daydate?: string
  weekday?: string
  dayuse?: number
}

/** SWAEServlet 外层 */
export interface WaterEnvelope {
  code_?: number
  result_?: string
  body?: string
  message_?: string
}
