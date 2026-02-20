import http from '@ohos.net.http';
import { Constants } from '../../utils/Constants';
import { APIError } from './DictionaryModels';
import { formatError } from '../../pages/settings/SettingsCommon';

/**
 * API Message structure
 */
export class APIMessage {
  role: string = '';
  content: string = '';
}

/**
 * API Choice structure
 */
export class APIChoice {
  index: number = 0;
  message: APIMessage = new APIMessage();
  finish_reason: string = '';
}

/**
 * API Response structure
 */
export class APIResponse {
  id: string = '';
  object: string = '';
  created: number = 0;
  model: string = '';
  choices: APIChoice[] = [];
}

/**
 * Chat completion request payload
 */
export class ChatCompletionRequest {
  model: string = '';
  messages: APIMessage[] = [];
  temperature: number = Constants.AI_DEFAULT_TEMPERATURE;
  max_tokens: number = Constants.AI_DEFAULT_MAX_TOKENS;
}

/**
 * API request options interface
 */
interface APIRequestOptions {
  method: http.RequestMethod;
  header: Record<string, string>;
  extraData: string;
  connectTimeout: number;
  readTimeout: number;
}

export class AiClient {
  private static instance: AiClient | null = null;
  private apiBaseUrl: string = 'https://api.deepseek.com';
  private apiKey: string = '';
  private model: string = 'deepseek-chat';

  private constructor() {}

  static getInstance(): AiClient {
    if (AiClient.instance === null) {
      AiClient.instance = new AiClient();
    }
    return AiClient.instance;
  }

  configure(baseUrl: string, apiKey: string, model: string = 'deepseek-chat'): void {
    this.apiBaseUrl = baseUrl;
    this.apiKey = apiKey;
    this.model = model;
  }

  isConfigured(): boolean {
    return this.apiKey.length > 0;
  }

  private buildChatCompletionsUrl(): string {
    let base = this.apiBaseUrl.trim();

    // 移除末尾的斜杠
    while (base.endsWith('/')) {
      base = base.slice(0, -1);
    }

    // 如果已经包含完整的chat/completions路径，直接返回
    if (base.includes('/chat/completions')) {
      return base;
    }

    // 处理不同厂商的API版本路径格式
    // 火山引擎: /api/v3
    if (base.endsWith('/api/v3')) {
      return `${base}/chat/completions`;
    }

    // 阿里云百炼: /compatible-mode/v1
    if (base.endsWith('/compatible-mode/v1')) {
      return `${base}/chat/completions`;
    }

    // 百度千帆: /v2
    if (base.endsWith('/v2')) {
      return `${base}/chat/completions`;
    }

    // 智谱AI: /v4
    if (base.endsWith('/v4')) {
      return `${base}/chat/completions`;
    }

    // 标准OpenAI兼容格式: /v1
    if (base.endsWith('/v1')) {
      return `${base}/chat/completions`;
    }

    // 默认添加/v1/chat/completions
    return `${base}/v1/chat/completions`;
  }

  async callAI(prompt: string): Promise<string> {
    const maxRetries = Constants.NETWORK_MAX_RETRY_COUNT;
    const initialDelay = Constants.NETWORK_INITIAL_RETRY_DELAY_MS;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      const httpRequest = http.createHttp();
      const url = this.buildChatCompletionsUrl();

      const msg = new APIMessage();
      msg.role = 'user';
      msg.content = prompt;
      const messages: APIMessage[] = [msg];

      const requestBody = new ChatCompletionRequest();
      requestBody.model = this.model;
      requestBody.messages = messages;
      const requestBodyStr: string = JSON.stringify(requestBody);

      const headers = {} as Record<string, string>;
      headers['Content-Type'] = 'application/json';
      headers['Authorization'] = `Bearer ${this.apiKey}`;

      const requestOptions: APIRequestOptions = {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: requestBodyStr,
        connectTimeout: Constants.NETWORK_CONNECT_TIMEOUT_MS,
        readTimeout: Constants.NETWORK_READ_TIMEOUT_MS
      };

      try {
        const response: http.HttpResponse = await httpRequest.request(url, requestOptions);

        if (response.responseCode !== 200) {
          let errBody = '';
          const r = response.result as string | ArrayBuffer;
          if (typeof r === 'string') {
            errBody = r;
          } else if (r instanceof ArrayBuffer) {
            errBody = this.decodeResult(r);
          }
          const trimmed = errBody.trim();
          const detail = trimmed.length > 0 ? `: ${trimmed.slice(0, 200)}` : '';
          throw new APIError(`API returned status ${response.responseCode}${detail}`);
        }

        let responseStr: string = '';
        const result = response.result as string | ArrayBuffer;
        if (typeof result === 'string') {
          responseStr = result;
        } else if (result instanceof ArrayBuffer) {
          responseStr = this.decodeResult(result);
        } else {
          throw new APIError('Unsupported response type');
        }

        const responseData = JSON.parse(responseStr) as APIResponse;

        if (responseData.choices.length === 0) {
          throw new APIError('No response from AI');
        }

        return responseData.choices[0].message.content;
      } catch (e) {
        let errorInstance: Error;
        if (e instanceof Error) {
          errorInstance = e;
        } else {
          const errorMessage = this.formatError(e as Error | string | object);
          errorInstance = new Error(errorMessage);
          errorInstance.name = 'APIError';
        }
        lastError = errorInstance;

        // Don't retry on certain errors
        if (e instanceof APIError) {
          if (e.message.includes('400') || e.message.includes('401') || e.message.includes('403') || e.message.includes('404')) {
            throw e;
          }
        }

        if (attempt === maxRetries - 1) {
          throw lastError;
        }

        const delay = Math.min(
          initialDelay * Math.pow(2, attempt) + Math.random() * 1000,
          Constants.NETWORK_MAX_RETRY_DELAY_MS
        );
        console.info(`[AiClient] API call failed, retrying in ${delay}ms (attempt ${attempt + 1}/${maxRetries})`);
        await this.delay(delay);
      } finally {
        httpRequest.destroy();
      }
    }
    
    throw lastError || new APIError('Unknown error occurred');
  }

  formatError = formatError;

  private decodeResult(buf: ArrayBuffer): string {
    const u8 = new Uint8Array(buf);
    let out: string = '';
    for (let i = 0; i < u8.length; i++) {
      out += String.fromCharCode(u8[i]);
    }
    return out;
  }

  private delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }
}
