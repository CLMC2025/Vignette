class WebDavLogFields {
  requestId: string;
  method: string;
  url: string;
  statusCode: number;
  location: string;
  elapsedMs: number;
  errorCode: string;
  errorMessage: string;

  constructor(
    requestId: string,
    method: string,
    url: string,
    statusCode: number,
    location: string,
    elapsedMs: number,
    errorCode: string,
    errorMessage: string
  ) {
    this.requestId = requestId;
    this.method = method;
    this.url = url;
    this.statusCode = statusCode;
    this.location = location;
    this.elapsedMs = elapsedMs;
    this.errorCode = errorCode;
    this.errorMessage = errorMessage;
  }
}

function sanitizeUrl(input: string): string {
  let url = input;
  const q = url.indexOf('?');
  if (q >= 0) {
    url = url.slice(0, q);
  }
  const hash = url.indexOf('#');
  if (hash >= 0) {
    url = url.slice(0, hash);
  }
  return url;
}

function safeSlice(input: string, maxLen: number): string {
  if (input.length <= maxLen) {
    return input;
  }
  return input.slice(0, maxLen);
}

export class WebDavLogger {
  private static format(fields: WebDavLogFields): string {
    const loc = fields.location.length > 0 ? ` location=${safeSlice(fields.location, 200)}` : '';
    const code = fields.errorCode.length > 0 ? ` code=${safeSlice(fields.errorCode, 60)}` : '';
    const err = fields.errorMessage.length > 0 ? ` error=${safeSlice(fields.errorMessage, 200)}` : '';
    return `[WebDAV] id=${fields.requestId} ${fields.method} ${sanitizeUrl(fields.url)} status=${fields.statusCode} ms=${fields.elapsedMs}${loc}${code}${err}`;
  }

  static infoRequest(requestId: string, method: string, url: string, statusCode: number, location: string, elapsedMs: number): void {
    const f = new WebDavLogFields(requestId, method, url, statusCode, location, elapsedMs, '', '');
    console.info(WebDavLogger.format(f));
  }

  static errorRequest(requestId: string, method: string, url: string, errorCode: string, errorMessage: string, elapsedMs: number): void {
    const f = new WebDavLogFields(requestId, method, url, 0, '', elapsedMs, errorCode, errorMessage);
    console.error(WebDavLogger.format(f));
  }
}
