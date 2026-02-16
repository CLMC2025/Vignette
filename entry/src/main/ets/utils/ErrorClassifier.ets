// =====================================================
// ErrorClassifier.ets - 将底层错误映射为用户可理解的提示
// Strict ArkTS - No 'any'
// =====================================================

export enum ErrorCategory {
  API_CONFIG = 'API_CONFIG',
  API_AUTH = 'API_AUTH',
  API_RATE_LIMIT = 'API_RATE_LIMIT',
  API_SERVER = 'API_SERVER',
  NETWORK = 'NETWORK',
  DATA_FORMAT = 'DATA_FORMAT',
  PERMISSION = 'PERMISSION',
  UNKNOWN = 'UNKNOWN'
}

export class ErrorInfo {
  category: ErrorCategory;
  title: string;
  userMessage: string;
  suggestion: string;
  showSettingsAction: boolean;
  showRetryAction: boolean;
  rawDetail: string;

  constructor(
    category: ErrorCategory,
    title: string,
    userMessage: string,
    suggestion: string,
    showSettingsAction: boolean,
    showRetryAction: boolean,
    rawDetail: string
  ) {
    this.category = category;
    this.title = title;
    this.userMessage = userMessage;
    this.suggestion = suggestion;
    this.showSettingsAction = showSettingsAction;
    this.showRetryAction = showRetryAction;
    this.rawDetail = rawDetail;
  }
}

function hasAny(haystack: string, needles: string[]): boolean {
  const lower = haystack.toLowerCase();
  for (const n of needles) {
    if (lower.includes(n.toLowerCase())) {
      return true;
    }
  }
  return false;
}

export function classifyError(raw: string): ErrorCategory {
  const msg = raw.trim();
  const lower = msg.toLowerCase();

  if (msg.length === 0) {
    return ErrorCategory.UNKNOWN;
  }

  // API not configured
  if (hasAny(lower, ['api not configured', '未配置', 'apikey', 'api key'])) {
    // avoid misclassifying auth errors
    if (hasAny(lower, ['401', 'unauthorized', 'invalid', 'forbidden', '403'])) {
      return ErrorCategory.API_AUTH;
    }
    return ErrorCategory.API_CONFIG;
  }

  // Auth / permission
  if (hasAny(lower, ['401', 'unauthorized', 'invalid api', 'invalid key'])) {
    return ErrorCategory.API_AUTH;
  }
  if (hasAny(lower, ['403', 'forbidden', 'permission', '权限'])) {
    return ErrorCategory.PERMISSION;
  }

  // Rate limit
  if (hasAny(lower, ['429', 'rate limit', 'too many requests'])) {
    return ErrorCategory.API_RATE_LIMIT;
  }

  // Server
  if (hasAny(lower, ['500', '502', '503', '504', 'server error', 'bad gateway', 'service unavailable'])) {
    return ErrorCategory.API_SERVER;
  }

  // Network / timeout
  if (hasAny(lower, ['timeout', 'timed out', 'network', 'connection', 'connect', 'dns', 'socket', 'unreachable'])) {
    return ErrorCategory.NETWORK;
  }

  // Format / parse
  if (hasAny(lower, ['json', 'parse', 'unsupported response type', 'malformed', 'format'])) {
    return ErrorCategory.DATA_FORMAT;
  }

  return ErrorCategory.UNKNOWN;
}

export function buildUserFacingError(raw: string): ErrorInfo {
  const cat = classifyError(raw);

  const detail = raw.trim().slice(0, 300);

  switch (cat) {
    case ErrorCategory.API_CONFIG:
      return new ErrorInfo(
        cat,
        '接口未配置',
        '当前未配置 AI 接口，无法获取在线释义/内容。',
        '请前往「设置」填写 Base URL / API Key / Model，或使用离线模板模式。',
        true,
        false,
        detail
      );
    case ErrorCategory.API_AUTH:
      return new ErrorInfo(
        cat,
        '鉴权失败',
        'AI 接口鉴权失败（API Key 或 Base URL 可能不正确）。',
        '请检查 Key 是否有效、Base URL 是否包含正确的版本路径（如 /v1），并确认模型名称可用。',
        true,
        true,
        detail
      );
    case ErrorCategory.PERMISSION:
      return new ErrorInfo(
        cat,
        '权限不足',
        '当前账号/接口没有权限执行该请求。',
        '请更换有权限的 API Key，或检查服务端是否限制了模型/地域/额度。',
        true,
        true,
        detail
      );
    case ErrorCategory.API_RATE_LIMIT:
      return new ErrorInfo(
        cat,
        '请求过于频繁',
        'AI 接口触发频率限制。',
        '请稍后重试，或在设置中更换更高配额的 Key；也可以暂时使用离线模板。',
        true,
        true,
        detail
      );
    case ErrorCategory.API_SERVER:
      return new ErrorInfo(
        cat,
        '服务端异常',
        'AI 服务端暂时不可用。',
        '请稍后重试；若持续出现，建议更换 Base URL 或使用离线模板。',
        true,
        true,
        detail
      );
    case ErrorCategory.NETWORK:
      return new ErrorInfo(
        cat,
        '网络异常',
        '网络连接异常或请求超时。',
        '请检查网络、代理/VPN、以及是否能访问 Base URL；也可以稍后重试。',
        false,
        true,
        detail
      );
    case ErrorCategory.DATA_FORMAT:
      return new ErrorInfo(
        cat,
        '数据解析失败',
        '服务返回的数据格式不符合预期。',
        '请检查模型是否返回了 JSON/纯文本（不要带代码块），或尝试更换模型/服务提供商。',
        true,
        true,
        detail
      );
    default:
      return new ErrorInfo(
        ErrorCategory.UNKNOWN,
        '加载失败',
        '任务加载过程中发生未知错误。',
        '建议先重试；若持续失败，请查看日志并反馈错误详情。',
        false,
        true,
        detail
      );
  }
}
