
import { Theme, ThemeType } from '../model/Theme';
import { LightThemeColors, DarkThemeColors } from '../model/ThemeColors';
import { ColorsInterface } from '../model/TokenInterfaces';

export class ThemeManager {
  private static instance: ThemeManager;
  private themes: Map<string, Theme> = new Map();
  private currentThemeId: string = 'light';
  private colors: ColorsInterface;
  private _isDarkMode: boolean = false;

  private constructor() {
    this.registerDefaultThemes();
    // Default to light
    this.colors = new LightThemeColors();
    AppStorage.SetOrCreate('CurrentColors', this.colors);
    AppStorage.SetOrCreate('CurrentThemeId', this.currentThemeId);
    AppStorage.SetOrCreate('ThemeRefreshToken', Date.now());
  }

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  private registerDefaultThemes() {
    // Only keep default light and dark themes
    this.registerTheme({
      id: 'light',
      name: '浅色默认',
      type: ThemeType.LIGHT,
      colors: new LightThemeColors()
    });
    this.registerTheme({
      id: 'dark',
      name: '深色默认',
      type: ThemeType.DARK,
      colors: new DarkThemeColors()
    });
  }

  public registerTheme(theme: Theme) {
    this.themes.set(theme.id, theme);
  }

  public setTheme(themeId: string) {
    if (this.themes.has(themeId)) {
      this.currentThemeId = themeId;
      const theme = this.themes.get(themeId)!;
      this.colors = theme.colors;
      this._isDarkMode = theme.type === ThemeType.DARK;
      AppStorage.SetOrCreate('CurrentColors', this.colors);
      AppStorage.SetOrCreate('CurrentThemeId', this.currentThemeId);
      AppStorage.SetOrCreate('ThemeRefreshToken', Date.now());
    }
  }

  public getCurrentTheme(): Theme {
    return this.themes.get(this.currentThemeId) || this.themes.get('light')!;
  }

  public getColors(): ColorsInterface {
    // Return direct reference to allow access
    // But for reactivity, callers should use AppStorage('CurrentColors')
    return this.colors;
  }

  public isDarkMode(): boolean {
    return this._isDarkMode;
  }
  
  public getThemes(): Theme[] {
    return Array.from(this.themes.values());
  }
}
