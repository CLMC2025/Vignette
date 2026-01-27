// =====================================================
// SecureStorage.ets - Secure Storage Utility
// Used for securely storing sensitive data like API keys
// =====================================================

import preferences from '@ohos.data.preferences';
import { BusinessError } from '@ohos.base';
import type common from '@ohos.app.ability.common';

/**
 * Secure storage utility for sensitive data
 */
export class SecureStorage {
  private static readonly PREFERENCES_NAME: string = 'secure_storage';
  private static readonly API_KEY_KEY: string = 'api_key';
  private static instance: SecureStorage | null = null;
  private preferences: preferences.Preferences | null = null;
  private isInitialized: boolean = false;
  private abilityContext: common.UIAbilityContext | null = null;

  private constructor() {}

  /**
   * Get singleton instance
   */
  static getInstance(): SecureStorage {
    if (SecureStorage.instance === null) {
      SecureStorage.instance = new SecureStorage();
    }
    return SecureStorage.instance;
  }

  /**
   * Inject ability context for secure storage
   * @param context The UI ability context to use
   */
  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
    console.log('[SecureStorage] injectContext: Context injected successfully');
  }

  /**
   * Initialize the secure storage
   */
  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      console.log('[SecureStorage] initialize: Already initialized');
      return true;
    }

    try {
      console.log('[SecureStorage] initialize: Starting initialization');
      
      // Check if abilityContext is available
      if (!this.abilityContext) {
        console.error('[SecureStorage] initialize: abilityContext is not available. Did you forget to injectContext?');
        return false;
      }
      
      this.preferences = await preferences.getPreferences(this.abilityContext, SecureStorage.PREFERENCES_NAME);
      this.isInitialized = true;
      console.log('[SecureStorage] initialize: Initialization successful');
      return true;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[SecureStorage] initialize: Failed to initialize preferences:', errMsg);
      return false;
    }
  }

  /**
   * Save API key securely
   * @param apiKey The API key to save
   */
  async saveApiKey(apiKey: string): Promise<boolean> {
    console.log('[SecureStorage] saveApiKey: Attempting to save API key');
    
    if (!await this.ensureInitialized()) {
      console.error('[SecureStorage] saveApiKey: Failed to initialize storage');
      return false;
    }

    try {
      if (!this.preferences) {
        console.error('[SecureStorage] saveApiKey: Preferences is null');
        return false;
      }
      
      await this.preferences.put(SecureStorage.API_KEY_KEY, apiKey);
      await this.preferences.flush();
      console.log('[SecureStorage] saveApiKey: API key saved successfully');
      return true;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[SecureStorage] saveApiKey: Failed to save API key:', errMsg);
      return false;
    }
  }

  /**
   * Get API key from secure storage
   */
  async getApiKey(): Promise<string> {
    console.log('[SecureStorage] getApiKey: Attempting to get API key');
    
    if (!await this.ensureInitialized()) {
      console.error('[SecureStorage] getApiKey: Failed to initialize storage');
      return '';
    }

    try {
      if (!this.preferences) {
        console.error('[SecureStorage] getApiKey: Preferences is null');
        return '';
      }
      
      const apiKey = await this.preferences.get(SecureStorage.API_KEY_KEY, '') as string;
      console.log('[SecureStorage] getApiKey: API key retrieved successfully, length:', apiKey.length);
      return apiKey;
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error);
      console.error('[SecureStorage] getApiKey: Failed to get API key:', errMsg);
      return '';
    }
  }

  /**
   * Remove API key from secure storage
   */
  async removeApiKey(): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }

    try {
      await this.preferences?.delete(SecureStorage.API_KEY_KEY);
      await this.preferences?.flush();
      return true;
    } catch (error) {
      console.error('[SecureStorage] Failed to remove API key:', error);
      return false;
    }
  }

  /**
   * Clear all secure storage data
   */
  async clearAll(): Promise<boolean> {
    if (!await this.ensureInitialized()) {
      return false;
    }

    try {
      await preferences.deletePreferences(globalThis.abilityContext, SecureStorage.PREFERENCES_NAME);
      this.isInitialized = false;
      this.preferences = null;
      return true;
    } catch (error) {
      console.error('[SecureStorage] Failed to clear all data:', error);
      return false;
    }
  }

  /**
   * Ensure the storage is initialized
   */
  private async ensureInitialized(): Promise<boolean> {
    if (!this.isInitialized) {
      return await this.initialize();
    }
    return true;
  }
}